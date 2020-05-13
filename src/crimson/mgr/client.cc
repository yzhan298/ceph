// -*- mode:C++; tab-width:8; c-basic-offset:2; indent-tabs-mode:t -*-
// vim: ts=8 sw=2 smarttab

#include "client.h"

#include <seastar/core/sleep.hh>

#include "crimson/common/log.h"
#include "crimson/net/Connection.h"
#include "crimson/net/Messenger.h"
#include "messages/MMgrConfigure.h"
#include "messages/MMgrMap.h"
#include "messages/MMgrOpen.h"

namespace {
  seastar::logger& logger()
  {
    return crimson::get_logger(ceph_subsys_mgrc);
  }
}

using crimson::common::local_conf;

namespace crimson::mgr
{

Client::Client(crimson::net::Messenger& msgr,
                 WithStats& with_stats)
  : msgr{msgr},
    with_stats{with_stats},
    report_timer{[this] {report();}}
{}

seastar::future<> Client::start()
{
  return seastar::now();
}

seastar::future<> Client::stop()
{
  return gate.close().then([this] {
    if (conn) {
      conn->mark_down();
    }
  });
}

seastar::future<> Client::ms_dispatch(crimson::net::Connection* conn,
                                      MessageRef m)
{
  switch(m->get_type()) {
  case MSG_MGR_MAP:
    return handle_mgr_map(conn, boost::static_pointer_cast<MMgrMap>(m));
  case MSG_MGR_CONFIGURE:
    return handle_mgr_conf(conn, boost::static_pointer_cast<MMgrConfigure>(m));
  default:
    return seastar::now();
  }
}

seastar::future<> Client::ms_handle_connect(crimson::net::ConnectionRef c)
{
  if (conn == c) {
    // ask for the mgrconfigure message
    auto m = ceph::make_message<MMgrOpen>();
    m->daemon_name = local_conf()->name.get_id();
    return conn->send(std::move(m));
  } else {
    return seastar::now();
  }
}

seastar::future<> Client::ms_handle_reset(crimson::net::ConnectionRef c, bool is_replace)
{
  if (conn == c) {
    report_timer.cancel();
    return reconnect();
  } else {
    return seastar::now();
  }
}

seastar::future<> Client::reconnect()
{
  if (conn) {
    conn->mark_down();
    conn = {};
  }
  if (!mgrmap.get_available()) {
    logger().warn("No active mgr available yet");
    return seastar::now();
  }
  auto retry_interval = std::chrono::duration<double>(
    local_conf().get_val<double>("mgr_connect_retry_interval"));
  auto a_while = std::chrono::duration_cast<seastar::steady_clock_type::duration>(
    retry_interval);
  return seastar::sleep(a_while).then([this] {
    auto peer = mgrmap.get_active_addrs().front();
    conn = msgr.connect(peer, CEPH_ENTITY_TYPE_MGR);
  });
}

seastar::future<> Client::handle_mgr_map(crimson::net::Connection*,
                                         Ref<MMgrMap> m)
{
  mgrmap = m->get_map();
  if (!conn) {
    return reconnect();
  } else if (conn->get_peer_addr() !=
             mgrmap.get_active_addrs().legacy_addr()) {
    return reconnect();
  } else {
    return seastar::now();
  }
}

seastar::future<> Client::handle_mgr_conf(crimson::net::Connection* conn,
                                          Ref<MMgrConfigure> m)
{
  logger().info("{} {}", __func__, *m);

  auto report_period = std::chrono::seconds{m->stats_period};
  if (report_period.count()) {
    if (report_timer.armed()) {
      report_timer.rearm(report_timer.get_timeout(), report_period);
    } else {
      report_timer.arm_periodic(report_period);
    }
  } else {
    report_timer.cancel();
  }
  return seastar::now();
}

void Client::report()
{
  (void) seastar::with_gate(gate, [this] {
    assert(conn);
    auto pg_stats = with_stats.get_stats();
    return conn->send(std::move(pg_stats));
  });
}

}
