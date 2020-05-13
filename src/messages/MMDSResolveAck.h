// -*- mode:C++; tab-width:8; c-basic-offset:2; indent-tabs-mode:t -*- 
// vim: ts=8 sw=2 smarttab
/*
 * Ceph - scalable distributed file system
 *
 * Copyright (C) 2004-2006 Sage Weil <sage@newdream.net>
 *
 * This is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License version 2.1, as published by the Free Software 
 * Foundation.  See file COPYING.
 * 
 */

#ifndef CEPH_MMDSRESOLVEACK_H
#define CEPH_MMDSRESOLVEACK_H

#include "msg/Message.h"

#include "include/types.h"


class MMDSResolveAck : public SafeMessage {
  static const int HEAD_VERSION = 1;
  static const int COMPAT_VERSION = 1;
public:
  std::map<metareqid_t, ceph::buffer::list> commit;
  std::vector<metareqid_t> abort;

protected:
  MMDSResolveAck() : SafeMessage{MSG_MDS_RESOLVEACK, HEAD_VERSION, COMPAT_VERSION} {}
  ~MMDSResolveAck() override {}

public:
  std::string_view get_type_name() const override { return "resolve_ack"; }
  /*void print(ostream& out) const {
    out << "resolve_ack.size()
	<< "+" << ambiguous_imap.size()
	<< " imports +" << slave_requests.size() << " slave requests)";
  }
  */
  
  void add_commit(metareqid_t r) {
    commit[r].clear();
  }
  void add_abort(metareqid_t r) {
    abort.push_back(r);
  }

  void encode_payload(uint64_t features) override {
    using ceph::encode;
    encode(commit, payload);
    encode(abort, payload);
  }
  void decode_payload() override {
    using ceph::decode;
    auto p = payload.cbegin();
    decode(commit, p);
    decode(abort, p);
  }
private:
  template<class T, typename... Args>
  friend boost::intrusive_ptr<T> ceph::make_message(Args&&... args);
};

#endif
