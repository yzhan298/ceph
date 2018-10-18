// -*- mode:C++; tab-width:8; c-basic-offset:2; indent-tabs-mode:t -*-
// vim: ts=8 sw=2 smarttab
/*
 * Ceph - scalable distributed file system
 *
 * Copyright (C) 2017 Red Hat, Inc
 *
 * This is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License version 2.1, as published by the Free Software
 * Foundation.  See file COPYING.
 *
 */

#include "SocketConnection.h"

#include <algorithm>
#include <seastar/core/shared_future.hh>
#include <seastar/core/sleep.hh>
#include <seastar/net/packet.hh>

#include "include/msgr.h"
#include "include/random.h"
#include "auth/Auth.h"
#include "auth/AuthSessionHandler.h"

#include "crimson/common/log.h"
#include "Config.h"
#include "Errors.h"
#include "SocketMessenger.h"

using namespace ceph::net;

template <typename T>
seastar::net::packet make_static_packet(const T& value) {
    return { reinterpret_cast<const char*>(&value), sizeof(value) };
}

namespace {
  seastar::logger& logger() {
    return ceph::get_logger(ceph_subsys_ms);
  }
}

SocketConnection::SocketConnection(SocketMessenger& messenger,
                                   const entity_addr_t& my_addr)
  : Connection(my_addr),
    messenger(messenger),
    send_ready(h.promise.get_future())
{
}

SocketConnection::~SocketConnection()
{
  // errors were reported to callers of send()
  ceph_assert(send_ready.available());
  send_ready.ignore_ready_future();
}

ceph::net::Messenger*
SocketConnection::get_messenger() const {
  return &messenger;
}

bool SocketConnection::is_connected()
{
  return !send_ready.failed();
}

void SocketConnection::read_tags_until_next_message()
{
  seastar::repeat([this] {
      // read the next tag
      return socket->read_exactly(1)
        .then([this] (auto buf) {
          if (buf.empty()) {
            throw std::system_error(make_error_code(error::read_eof));
          }
          switch (buf[0]) {
          case CEPH_MSGR_TAG_MSG:
            // stop looping and notify read_header()
            return seastar::make_ready_future<seastar::stop_iteration>(
                seastar::stop_iteration::yes);
          case CEPH_MSGR_TAG_ACK:
            return handle_ack();
          case CEPH_MSGR_TAG_KEEPALIVE:
            break;
          case CEPH_MSGR_TAG_KEEPALIVE2:
            return handle_keepalive2()
              .then([this] { return seastar::stop_iteration::no; });
          case CEPH_MSGR_TAG_KEEPALIVE2_ACK:
            return handle_keepalive2_ack()
              .then([this] { return seastar::stop_iteration::no; });
          case CEPH_MSGR_TAG_CLOSE:
            std::cout << "close" << std::endl;
            break;
          }
          return seastar::make_ready_future<seastar::stop_iteration>(
              seastar::stop_iteration::no);
        });
    }).handle_exception_type([this] (const std::system_error& e) {
      if (e.code() == error::read_eof) {
        close();
      }
      throw e;
    }).then_wrapped([this] (auto fut) {
      // satisfy the message promise
      fut.forward_to(std::move(on_message));
    });
}

seastar::future<seastar::stop_iteration> SocketConnection::handle_ack()
{
  return socket->read_exactly(sizeof(ceph_le64))
    .then([this] (auto buf) {
      auto seq = reinterpret_cast<const ceph_le64*>(buf.get());
      discard_up_to(&sent, *seq);
      return seastar::stop_iteration::no;
    });
}

void SocketConnection::discard_up_to(std::queue<MessageRef>* queue,
                                     seq_num_t seq)
{
  while (!queue->empty() &&
         queue->front()->get_seq() < seq) {
    queue->pop();
  }
}

void SocketConnection::requeue_sent()
{
  out_seq -= sent.size();
  while (!sent.empty()) {
    auto m = sent.front();
    sent.pop();
    out_q.push(std::move(m));
  }
}

seastar::future<> SocketConnection::maybe_throttle()
{
  if (!policy.throttler_bytes) {
    return seastar::now();
  }
  const auto to_read = (m.header.front_len +
                        m.header.middle_len +
                        m.header.data_len);
  return policy.throttler_bytes->get(to_read);
}

seastar::future<MessageRef> SocketConnection::do_read_message()
{
  return on_message.get_future()
    .then([this] {
      on_message = seastar::promise<>{};
      // read header
      return socket->read(sizeof(m.header));
    }).then([this] (bufferlist bl) {
      // throttle the traffic, maybe
      auto p = bl.cbegin();
      ::decode(m.header, p);
      return maybe_throttle();
    }).then([this] {
      // read front
      return socket->read(m.header.front_len);
    }).then([this] (bufferlist bl) {
      m.front = std::move(bl);
      // read middle
      return socket->read(m.header.middle_len);
    }).then([this] (bufferlist bl) {
      m.middle = std::move(bl);
      // read data
      return socket->read(m.header.data_len);
    }).then([this] (bufferlist bl) {
      m.data = std::move(bl);
      // read footer
      return socket->read(sizeof(m.footer));
    }).then([this] (bufferlist bl) {
      // resume background processing of tags
      read_tags_until_next_message();

      auto p = bl.cbegin();
      ::decode(m.footer, p);
      auto msg = ::decode_message(nullptr, 0, m.header, m.footer,
                                  m.front, m.middle, m.data, nullptr);
      // TODO: set time stamps
      msg->set_byte_throttler(policy.throttler_bytes);
      constexpr bool add_ref = false; // Message starts with 1 ref
      return MessageRef{msg, add_ref};
    });
}

seastar::future<MessageRef> SocketConnection::read_message()
{
  return seastar::repeat_until_value([this] {
      return do_read_message()
        .then([this] (MessageRef msg) -> std::optional<MessageRef> {
          if (!update_rx_seq(msg->get_seq())) {
            // skip this request and read the next
            return {};
          }
          return msg;
        });
    });
}

bool SocketConnection::update_rx_seq(seq_num_t seq)
{
  if (seq <= in_seq) {
    if (HAVE_FEATURE(features, RECONNECT_SEQ) &&
        conf.ms_die_on_old_message) {
      ceph_abort_msg("old msgs despite reconnect_seq feature");
    }
    return false;
  } else if (seq > in_seq + 1) {
    if (conf.ms_die_on_skipped_message) {
      ceph_abort_msg("skipped incoming seq");
    }
    return false;
  } else {
    in_seq = seq;
    return true;
  }
}

seastar::future<> SocketConnection::write_message(MessageRef msg)
{
  msg->set_seq(++out_seq);
  msg->encode(features, messenger.get_crc_flags());
  bufferlist bl;
  bl.append(CEPH_MSGR_TAG_MSG);
  auto& header = msg->get_header();
  bl.append((const char*)&header, sizeof(header));
  bl.append(msg->get_payload());
  bl.append(msg->get_middle());
  bl.append(msg->get_data());
  auto& footer = msg->get_footer();
  if (HAVE_FEATURE(features, MSG_AUTH)) {
    bl.append((const char*)&footer, sizeof(footer));
  } else {
    ceph_msg_footer_old old_footer;
    if (messenger.get_crc_flags() & MSG_CRC_HEADER) {
      old_footer.front_crc = footer.front_crc;
      old_footer.middle_crc = footer.middle_crc;
    } else {
      old_footer.front_crc = old_footer.middle_crc = 0;
    }
    if (messenger.get_crc_flags() & MSG_CRC_DATA) {
      old_footer.data_crc = footer.data_crc;
    } else {
      old_footer.data_crc = 0;
    }
    old_footer.flags = footer.flags;
    bl.append((const char*)&old_footer, sizeof(old_footer));
  }
  // write as a seastar::net::packet
  return socket->write_flush(std::move(bl))
    .then([this, msg = std::move(msg)] {
      if (!policy.lossy) {
        sent.push(std::move(msg));
      }
    });
}

seastar::future<> SocketConnection::send(MessageRef msg)
{
  // chain the message after the last message is sent
  seastar::shared_future<> f = send_ready.then(
    [this, msg = std::move(msg)] {
      return write_message(std::move(msg));
    });

  // chain any later messages after this one completes
  send_ready = f.get_future();
  // allow the caller to wait on the same future
  return f.get_future();
}

seastar::future<> SocketConnection::keepalive()
{
  seastar::shared_future<> f = send_ready.then([this] {
      k.req.stamp = ceph::coarse_real_clock::to_ceph_timespec(
        ceph::coarse_real_clock::now());
      return socket->write_flush(make_static_packet(k.req));
    });
  send_ready = f.get_future();
  return f.get_future();
}

seastar::future<> SocketConnection::close()
{
  if (state == state_t::closing) {
    // already closing
    assert(close_ready.valid());
    return close_ready.get_future();
  }

  // unregister_conn() drops a reference, so hold another until completion
  auto cleanup = [conn = SocketConnectionRef(this)] {};

  if (state == state_t::accepting) {
    messenger.unaccept_conn(this);
  } else if (state >= state_t::connecting && state < state_t::closing) {
    messenger.unregister_conn(this);
  } else {
    // cannot happen
    ceph_assert(false);
  }
  state = state_t::closing;

  // close_ready become valid only after state is state_t::closing
  assert(!close_ready.valid());
  close_ready = socket->close().finally(std::move(cleanup));
  return close_ready.get_future();
}

// handshake

/// store the banner in a non-const string for buffer::create_static()
static char banner[] = CEPH_BANNER;
constexpr size_t banner_size = sizeof(CEPH_BANNER)-1;

constexpr size_t client_header_size = banner_size + sizeof(ceph_entity_addr);
constexpr size_t server_header_size = banner_size + 2 * sizeof(ceph_entity_addr);

WRITE_RAW_ENCODER(ceph_msg_connect);
WRITE_RAW_ENCODER(ceph_msg_connect_reply);

std::ostream& operator<<(std::ostream& out, const ceph_msg_connect& c)
{
  return out << "connect{features=" << std::hex << c.features << std::dec
      << " host_type=" << c.host_type
      << " global_seq=" << c.global_seq
      << " connect_seq=" << c.connect_seq
      << " protocol_version=" << c.protocol_version
      << " authorizer_protocol=" << c.authorizer_protocol
      << " authorizer_len=" << c.authorizer_len
      << " flags=" << std::hex << static_cast<uint16_t>(c.flags) << std::dec << '}';
}

std::ostream& operator<<(std::ostream& out, const ceph_msg_connect_reply& r)
{
  return out << "connect_reply{tag=" << static_cast<uint16_t>(r.tag)
      << " features=" << std::hex << r.features << std::dec
      << " global_seq=" << r.global_seq
      << " connect_seq=" << r.connect_seq
      << " protocol_version=" << r.protocol_version
      << " authorizer_len=" << r.authorizer_len
      << " flags=" << std::hex << static_cast<uint16_t>(r.flags) << std::dec << '}';
}

// check that the buffer starts with a valid banner without requiring it to
// be contiguous in memory
static void validate_banner(bufferlist::const_iterator& p)
{
  auto b = std::cbegin(banner);
  auto end = b + banner_size;
  while (b != end) {
    const char *buf{nullptr};
    auto remaining = std::distance(b, end);
    auto len = p.get_ptr_and_advance(remaining, &buf);
    if (!std::equal(buf, buf + len, b)) {
      throw std::system_error(make_error_code(error::bad_connect_banner));
    }
    b += len;
  }
}

// make sure that we agree with the peer about its address
static void validate_peer_addr(const entity_addr_t& addr,
                               const entity_addr_t& expected)
{
  if (addr == expected) {
    return;
  }
  // ok if server bound anonymously, as long as port/nonce match
  if (addr.is_blank_ip() &&
      addr.get_port() == expected.get_port() &&
      addr.get_nonce() == expected.get_nonce()) {
    return;
  } else {
    throw std::system_error(make_error_code(error::bad_peer_address));
  }
}

/// return a static bufferptr to the given object
template <typename T>
bufferptr create_static(T& obj)
{
  return buffer::create_static(sizeof(obj), reinterpret_cast<char*>(&obj));
}

bool SocketConnection::require_auth_feature() const
{
  if (h.connect.authorizer_protocol != CEPH_AUTH_CEPHX) {
    return false;
  }
  if (conf.cephx_require_signatures) {
    return true;
  }
  if (h.connect.host_type == CEPH_ENTITY_TYPE_OSD ||
      h.connect.host_type == CEPH_ENTITY_TYPE_MDS) {
    return conf.cephx_cluster_require_signatures;
  } else {
    return conf.cephx_service_require_signatures;
  }
}

uint32_t SocketConnection::get_proto_version(entity_type_t peer_type, bool connect) const
{
  constexpr entity_type_t my_type = CEPH_ENTITY_TYPE_OSD;
  // see also OSD.h, unlike other connection of simple/async messenger,
  // crimson msgr is only used by osd
  constexpr uint32_t CEPH_OSD_PROTOCOL = 10;
  if (peer_type == my_type) {
    // internal
    return CEPH_OSD_PROTOCOL;
  } else {
    // public
    switch (connect ? peer_type : my_type) {
      case CEPH_ENTITY_TYPE_OSD: return CEPH_OSDC_PROTOCOL;
      case CEPH_ENTITY_TYPE_MDS: return CEPH_MDSC_PROTOCOL;
      case CEPH_ENTITY_TYPE_MON: return CEPH_MONC_PROTOCOL;
      default: return 0;
    }
  }
}

seastar::future<>
SocketConnection::repeat_handle_connect()
{
  return socket->read(sizeof(h.connect))
    .then([this](bufferlist bl) {
      auto p = bl.cbegin();
      ::decode(h.connect, p);
      peer_type = h.connect.host_type;
      return socket->read(h.connect.authorizer_len);
    }).then([this] (bufferlist authorizer) {
      if (h.connect.protocol_version != get_proto_version(h.connect.host_type, false)) {
      	return seastar::make_ready_future<msgr_tag_t, bufferlist>(
            CEPH_MSGR_TAG_BADPROTOVER, bufferlist{});
      }
      if (require_auth_feature()) {
      	policy.features_required |= CEPH_FEATURE_MSG_AUTH;
      }
      if (auto feat_missing = policy.features_required & ~(uint64_t)h.connect.features;
      	  feat_missing != 0) {
        return seastar::make_ready_future<msgr_tag_t, bufferlist>(
            CEPH_MSGR_TAG_FEATURES, bufferlist{});
      }
      return messenger.verify_authorizer(peer_type,
                                         h.connect.authorizer_protocol,
                                         authorizer);
    }).then([this] (ceph::net::msgr_tag_t tag, bufferlist&& authorizer_reply) {
      memset(&h.reply, 0, sizeof(h.reply));
      if (tag) {
	return send_connect_reply(tag, std::move(authorizer_reply));
      }
      if (auto existing = messenger.lookup_conn(peer_addr); existing) {
	return handle_connect_with_existing(existing, std::move(authorizer_reply));
      } else if (h.connect.connect_seq > 0) {
	return send_connect_reply(CEPH_MSGR_TAG_RESETSESSION,
				  std::move(authorizer_reply));
      }
      h.connect_seq = h.connect.connect_seq + 1;
      h.peer_global_seq = h.connect.global_seq;
      set_features((uint64_t)policy.features_supported & (uint64_t)h.connect.features);
      // TODO: cct
      return send_connect_reply_ready(CEPH_MSGR_TAG_READY, std::move(authorizer_reply));
    });
}

seastar::future<>
SocketConnection::send_connect_reply(msgr_tag_t tag,
                                     bufferlist&& authorizer_reply)
{
  h.reply.tag = tag;
  h.reply.features = static_cast<uint64_t>((h.connect.features &
					    policy.features_supported) |
					   policy.features_required);
  h.reply.authorizer_len = authorizer_reply.length();
  return socket->write(make_static_packet(h.reply))
    .then([this, reply=std::move(authorizer_reply)]() mutable {
      return socket->write_flush(std::move(reply));
    });
}

seastar::future<>
SocketConnection::send_connect_reply_ready(msgr_tag_t tag,
                                           bufferlist&& authorizer_reply)
{
  h.global_seq = messenger.get_global_seq();
  h.reply.tag = tag;
  h.reply.features = policy.features_supported;
  h.reply.global_seq = h.global_seq;
  h.reply.connect_seq = h.connect_seq;
  h.reply.flags = 0;
  if (policy.lossy) {
    h.reply.flags = h.reply.flags | CEPH_MSG_CONNECT_LOSSY;
  }
  h.reply.authorizer_len = authorizer_reply.length();
  return socket->write(make_static_packet(h.reply))
    .then([this, reply=std::move(authorizer_reply)]() mutable {
      if (reply.length()) {
        return socket->write(std::move(reply));
      } else {
        return seastar::now();
      }
    }).then([this] {
      if (h.reply.tag == CEPH_MSGR_TAG_SEQ) {
        return socket->write_flush(make_static_packet(in_seq))
          .then([this] {
            return socket->read_exactly(sizeof(seq_num_t));
          }).then([this] (auto buf) {
            auto acked_seq = reinterpret_cast<const seq_num_t*>(buf.get());
            discard_up_to(&out_q, *acked_seq);
          });
      } else {
        return socket->flush();
      }
    }).then([this] {
      messenger.register_conn(this);
      messenger.unaccept_conn(this);
      state = state_t::open;
    });
}

seastar::future<>
SocketConnection::handle_keepalive2()
{
  return socket->read_exactly(sizeof(ceph_timespec))
    .then([this] (auto buf) {
      k.ack.stamp = *reinterpret_cast<const ceph_timespec*>(buf.get());
      std::cout << "keepalive2 " << k.ack.stamp.tv_sec << std::endl;
      return socket->write_flush(make_static_packet(k.ack));
    });
}

seastar::future<>
SocketConnection::handle_keepalive2_ack()
{
  return socket->read_exactly(sizeof(ceph_timespec))
    .then([this] (auto buf) {
      auto t = reinterpret_cast<const ceph_timespec*>(buf.get());
      k.ack_stamp = *t;
      std::cout << "keepalive2 ack " << t->tv_sec << std::endl;
    });
}

seastar::future<>
SocketConnection::handle_connect_with_existing(SocketConnectionRef existing, bufferlist&& authorizer_reply)
{
  if (h.connect.global_seq < existing->peer_global_seq()) {
    h.reply.global_seq = existing->peer_global_seq();
    return send_connect_reply(CEPH_MSGR_TAG_RETRY_GLOBAL);
  } else if (existing->is_lossy()) {
    return replace_existing(existing, std::move(authorizer_reply));
  } else if (h.connect.connect_seq == 0 && existing->connect_seq() > 0) {
    return replace_existing(existing, std::move(authorizer_reply), true);
  } else if (h.connect.connect_seq < existing->connect_seq()) {
    // old attempt, or we sent READY but they didn't get it.
    h.reply.connect_seq = existing->connect_seq() + 1;
    return send_connect_reply(CEPH_MSGR_TAG_RETRY_SESSION);
  } else if (h.connect.connect_seq == existing->connect_seq()) {
    // if the existing connection successfully opened, and/or
    // subsequently went to standby, then the peer should bump
    // their connect_seq and retry: this is not a connection race
    // we need to resolve here.
    if (existing->get_state() == state_t::open ||
	existing->get_state() == state_t::standby) {
      if (policy.resetcheck && existing->connect_seq() == 0) {
	return replace_existing(existing, std::move(authorizer_reply));
      } else {
	h.reply.connect_seq = existing->connect_seq() + 1;
	return send_connect_reply(CEPH_MSGR_TAG_RETRY_SESSION);
      }
    } else if (peer_addr < my_addr ||
	       existing->is_server_side()) {
      // incoming wins
      return replace_existing(existing, std::move(authorizer_reply));
    } else {
      return send_connect_reply(CEPH_MSGR_TAG_WAIT);
    }
  } else if (policy.resetcheck &&
	     existing->connect_seq() == 0) {
    return send_connect_reply(CEPH_MSGR_TAG_RESETSESSION);
  } else {
    return replace_existing(existing, std::move(authorizer_reply));
  }
}

seastar::future<> SocketConnection::replace_existing(SocketConnectionRef existing,
                                                     bufferlist&& authorizer_reply,
						     bool is_reset_from_peer)
{
  msgr_tag_t reply_tag;
  if (HAVE_FEATURE(h.connect.features, RECONNECT_SEQ) &&
      !is_reset_from_peer) {
    reply_tag = CEPH_MSGR_TAG_SEQ;
  } else {
    reply_tag = CEPH_MSGR_TAG_READY;
  }
  messenger.unregister_conn(existing);
  if (!existing->is_lossy()) {
    // reset the in_seq if this is a hard reset from peer,
    // otherwise we respect our original connection's value
    in_seq = is_reset_from_peer ? 0 : existing->rx_seq_num();
    // steal outgoing queue and out_seq
    existing->requeue_sent();
    std::tie(out_seq, out_q) = existing->get_out_queue();
  }
  return send_connect_reply_ready(reply_tag, std::move(authorizer_reply));
}

seastar::future<> SocketConnection::handle_connect_reply(msgr_tag_t tag)
{
  switch (tag) {
  case CEPH_MSGR_TAG_FEATURES:
    return fault();
  case CEPH_MSGR_TAG_BADPROTOVER:
    return fault();
  case CEPH_MSGR_TAG_BADAUTHORIZER:
    if (h.got_bad_auth) {
      logger().error("{} got bad authorizer", __func__);
      throw std::system_error(make_error_code(error::negotiation_failure));
    }
    h.got_bad_auth = true;
    // try harder
    return messenger.get_authorizer(peer_type, true)
      .then([this](auto&& auth) {
        h.authorizer = std::move(auth);
	return seastar::now();
      });
  case CEPH_MSGR_TAG_RESETSESSION:
    reset_session();
    return seastar::now();
  case CEPH_MSGR_TAG_RETRY_GLOBAL:
    h.global_seq = messenger.get_global_seq(h.reply.global_seq);
    return seastar::now();
  case CEPH_MSGR_TAG_RETRY_SESSION:
    ceph_assert(h.reply.connect_seq > h.connect_seq);
    h.connect_seq = h.reply.connect_seq;
    return seastar::now();
  case CEPH_MSGR_TAG_WAIT:
    return fault();
  case CEPH_MSGR_TAG_SEQ:
    break;
  case CEPH_MSGR_TAG_READY:
    break;
  }
  if (auto missing = (policy.features_required & ~(uint64_t)h.reply.features);
      missing) {
    return fault();
  }
  if (tag == CEPH_MSGR_TAG_SEQ) {
    return socket->read_exactly(sizeof(seq_num_t))
      .then([this] (auto buf) {
        auto acked_seq = reinterpret_cast<const seq_num_t*>(buf.get());
        discard_up_to(&out_q, *acked_seq);
        return socket->write_flush(make_static_packet(in_seq));
      }).then([this] {
        return handle_connect_reply(CEPH_MSGR_TAG_READY);
      });
  }
  if (tag == CEPH_MSGR_TAG_READY) {
    // hooray!
    h.peer_global_seq = h.reply.global_seq;
    policy.lossy = h.reply.flags & CEPH_MSG_CONNECT_LOSSY;
    state = state_t::open;
    h.connect_seq++;
    h.backoff = 0ms;
    set_features(h.reply.features & h.connect.features);
    if (h.authorizer) {
      session_security.reset(
          get_auth_session_handler(nullptr,
                                   h.authorizer->protocol,
                                   h.authorizer->session_key,
                                   features));
    }
    h.authorizer.reset();
    return seastar::now();
  } else {
    // unknown tag
    logger().error("{} got unknown tag", __func__, int(tag));
    throw std::system_error(make_error_code(error::negotiation_failure));
  }
}

void SocketConnection::reset_session()
{
  decltype(out_q){}.swap(out_q);
  decltype(sent){}.swap(sent);
  in_seq = 0;
  h.connect_seq = 0;
  if (HAVE_FEATURE(features, MSG_AUTH)) {
    // Set out_seq to a random value, so CRC won't be predictable.
    // Constant to limit starting sequence number to 2^31.  Nothing special
    // about it, just a big number.
    constexpr uint64_t SEQ_MASK = 0x7fffffff;
    out_seq = ceph::util::generate_random_number<uint64_t>(0, SEQ_MASK);
  } else {
    // previously, seq #'s always started at 0.
    out_seq = 0;
  }
}

seastar::future<> SocketConnection::repeat_connect()
{
  // encode ceph_msg_connect
  memset(&h.connect, 0, sizeof(h.connect));
  h.connect.features = policy.features_supported;
  h.connect.host_type = messenger.get_myname().type();
  h.connect.global_seq = h.global_seq;
  h.connect.connect_seq = h.connect_seq;
  h.connect.protocol_version = get_proto_version(peer_type, true);
  // this is fyi, actually, server decides!
  h.connect.flags = policy.lossy ? CEPH_MSG_CONNECT_LOSSY : 0;

  return messenger.get_authorizer(peer_type, false)
    .then([this](auto&& auth) {
      h.authorizer = std::move(auth);
      bufferlist bl;
      if (h.authorizer) {
        h.connect.authorizer_protocol = h.authorizer->protocol;
        h.connect.authorizer_len = h.authorizer->bl.length();
        bl.append(create_static(h.connect));
        bl.append(h.authorizer->bl);
      } else {
        h.connect.authorizer_protocol = 0;
        h.connect.authorizer_len = 0;
        bl.append(create_static(h.connect));
      };
      return socket->write_flush(std::move(bl));
    }).then([this] {
     // read the reply
      return socket->read(sizeof(h.reply));
    }).then([this] (bufferlist bl) {
      auto p = bl.cbegin();
      ::decode(h.reply, p);
      ceph_assert(p.end());
      return socket->read(h.reply.authorizer_len);
    }).then([this] (bufferlist bl) {
      if (h.authorizer) {
        auto reply = bl.cbegin();
        if (!h.authorizer->verify_reply(reply)) {
          logger().error("{} authorizer failed to verify reply", __func__);
          throw std::system_error(make_error_code(error::negotiation_failure));
        }
      }
      return handle_connect_reply(h.reply.tag);
    });
}

seastar::future<>
SocketConnection::start_connect(const entity_addr_t& _peer_addr,
                                const entity_type_t& _peer_type)
{
  ceph_assert(state == state_t::none);
  ceph_assert(!socket);
  peer_addr = _peer_addr;
  peer_type = _peer_type;
  messenger.register_conn(this);
  state = state_t::connecting;
  return seastar::connect(peer_addr.in4_addr())
    .then([this](seastar::connected_socket fd) {
      socket.emplace(std::move(fd));
      // read server's handshake header
      return socket->read(server_header_size);
    }).then([this] (bufferlist headerbl) {
      auto p = headerbl.cbegin();
      validate_banner(p);
      entity_addr_t saddr, caddr;
      ::decode(saddr, p);
      ::decode(caddr, p);
      ceph_assert(p.end());
      validate_peer_addr(saddr, peer_addr);

      if (my_addr != caddr) {
        // take peer's address for me, but preserve my nonce
        caddr.nonce = my_addr.nonce;
        my_addr = caddr;
      }
      // encode/send client's handshake header
      bufferlist bl;
      bl.append(buffer::create_static(banner_size, banner));
      ::encode(my_addr, bl, 0);
      h.global_seq = messenger.get_global_seq();
      return socket->write_flush(std::move(bl));
    }).then([=] {
      return seastar::do_until([=] { return state == state_t::open; },
                               [=] { return repeat_connect(); });
    }).then([this] {
      // start background processing of tags
      read_tags_until_next_message();
    }).then_wrapped([this] (auto fut) {
      // satisfy the handshake's promise
      fut.forward_to(std::move(h.promise));
    });
}

seastar::future<>
SocketConnection::start_accept(seastar::connected_socket&& fd,
                               const entity_addr_t& _peer_addr)
{
  ceph_assert(state == state_t::none);
  ceph_assert(!socket);
  peer_addr = _peer_addr;
  socket.emplace(std::move(fd));
  messenger.accept_conn(this);
  state = state_t::accepting;
  // encode/send server's handshake header
  bufferlist bl;
  bl.append(buffer::create_static(banner_size, banner));
  ::encode(my_addr, bl, 0);
  ::encode(peer_addr, bl, 0);
  return socket->write_flush(std::move(bl))
    .then([this] {
      // read client's handshake header and connect request
      return socket->read(client_header_size);
    }).then([this] (bufferlist bl) {
      auto p = bl.cbegin();
      validate_banner(p);
      entity_addr_t addr;
      ::decode(addr, p);
      ceph_assert(p.end());
      if (!addr.is_blank_ip()) {
        peer_addr = addr;
      }
    }).then([this] {
      return seastar::do_until([this] { return state == state_t::open; },
                               [this] { return repeat_handle_connect(); });
    }).then([this] {
      // start background processing of tags
      read_tags_until_next_message();
    }).then_wrapped([this] (auto fut) {
      // satisfy the handshake's promise
      fut.forward_to(std::move(h.promise));
    });
}

seastar::future<> SocketConnection::fault()
{
  if (policy.lossy) {
    messenger.unregister_conn(this);
  }
  if (h.backoff.count()) {
    h.backoff += h.backoff;
  } else {
    h.backoff = conf.ms_initial_backoff;
  }
  if (h.backoff > conf.ms_max_backoff) {
    h.backoff = conf.ms_max_backoff;
  }
  return seastar::sleep(h.backoff);
}
