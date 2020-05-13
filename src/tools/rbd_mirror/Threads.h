// -*- mode:C++; tab-width:8; c-basic-offset:2; indent-tabs-mode:t -*-
// vim: ts=8 sw=2 smarttab

#ifndef CEPH_RBD_MIRROR_THREADS_H
#define CEPH_RBD_MIRROR_THREADS_H

#include "include/common_fwd.h"
#include "common/ceph_mutex.h"

class ContextWQ;
class SafeTimer;
class ThreadPool;

namespace librbd { struct ImageCtx; }

namespace rbd {
namespace mirror {

template <typename ImageCtxT = librbd::ImageCtx>
struct Threads {
  ThreadPool *thread_pool = nullptr;
  ContextWQ *work_queue = nullptr;

  SafeTimer *timer = nullptr;
  ceph::mutex timer_lock =
    ceph::make_mutex("Threads::timer_lock");

  explicit Threads(CephContext *cct);
  Threads(const Threads&) = delete;
  Threads& operator=(const Threads&) = delete;

  ~Threads();
};

} // namespace mirror
} // namespace rbd

extern template class rbd::mirror::Threads<librbd::ImageCtx>;

#endif // CEPH_RBD_MIRROR_THREADS_H
