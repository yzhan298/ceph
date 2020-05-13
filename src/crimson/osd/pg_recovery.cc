// -*- mode:C++; tab-width:8; c-basic-offset:2; indent-tabs-mode:t -*-
// vim: ts=8 sw=2 smarttab

#include <fmt/format.h>
#include <fmt/ostream.h>

#include "crimson/common/type_helpers.h"
#include "crimson/osd/osd_operations/background_recovery.h"
#include "crimson/osd/osd_operations/peering_event.h"
#include "crimson/osd/pg.h"
#include "crimson/osd/pg_backend.h"
#include "crimson/osd/pg_recovery.h"

#include "messages/MOSDPGPull.h"
#include "messages/MOSDPGPush.h"
#include "messages/MOSDPGPushReply.h"
#include "messages/MOSDPGRecoveryDelete.h"
#include "messages/MOSDPGRecoveryDeleteReply.h"

#include "osd/osd_types.h"
#include "osd/PeeringState.h"

void PGRecovery::start_background_recovery(
  crimson::osd::scheduler::scheduler_class_t klass)
{
  using BackgroundRecovery = crimson::osd::BackgroundRecovery;
  pg->get_shard_services().start_operation<BackgroundRecovery>(
    static_cast<crimson::osd::PG*>(pg),
    pg->get_shard_services(),
    pg->get_osdmap_epoch(),
    klass);
}

crimson::osd::blocking_future<bool>
PGRecovery::start_recovery_ops(size_t max_to_start)
{
  assert(pg->is_primary());
  assert(pg->is_peered());
  assert(!pg->get_peering_state().is_deleting());

  if (!pg->is_recovering() && !pg->is_backfilling()) {
    return crimson::osd::make_ready_blocking_future<bool>(false);
  }

  std::vector<crimson::osd::blocking_future<>> started;
  started.reserve(max_to_start);
  max_to_start -= start_primary_recovery_ops(max_to_start, &started);
  if (max_to_start > 0) {
    max_to_start -= start_replica_recovery_ops(max_to_start, &started);
  }
  if (max_to_start > 0) {
    max_to_start -= start_backfill_ops(max_to_start, &started);
  }
  return crimson::osd::join_blocking_futures(std::move(started)).then(
    [this] {
    bool done = !pg->get_peering_state().needs_recovery();
    if (done) {
      crimson::get_logger(ceph_subsys_osd).debug("start_recovery_ops: AllReplicasRecovered for pg: {}",
		     pg->get_pgid());
      using LocalPeeringEvent = crimson::osd::LocalPeeringEvent;
      pg->get_shard_services().start_operation<LocalPeeringEvent>(
	static_cast<crimson::osd::PG*>(pg),
	pg->get_shard_services(),
	pg->get_pg_whoami(),
	pg->get_pgid(),
	pg->get_osdmap_epoch(),
	pg->get_osdmap_epoch(),
	PeeringState::AllReplicasRecovered{});
    }
    return seastar::make_ready_future<bool>(!done);
  });
}

size_t PGRecovery::start_primary_recovery_ops(
  size_t max_to_start,
  std::vector<crimson::osd::blocking_future<>> *out)
{
  if (!pg->is_recovering()) {
    return 0;
  }

  if (!pg->get_peering_state().have_missing()) {
    pg->get_peering_state().local_recovery_complete();
    return 0;
  }

  const auto &missing = pg->get_peering_state().get_pg_log().get_missing();

  crimson::get_logger(ceph_subsys_osd).info(
    "{} recovering {} in pg {}, missing {}",
    __func__,
    pg->get_recovery_backend()->total_recovering(),
    *static_cast<crimson::osd::PG*>(pg),
    missing);

  unsigned started = 0;
  int skipped = 0;

  map<version_t, hobject_t>::const_iterator p =
    missing.get_rmissing().lower_bound(pg->get_peering_state().get_pg_log().get_log().last_requested);
  while (started < max_to_start && p != missing.get_rmissing().end()) {
    // TODO: chain futures here to enable yielding to scheduler?
    hobject_t soid;
    version_t v = p->first;

    auto it_objects = pg->get_peering_state().get_pg_log().get_log().objects.find(p->second);
    if (it_objects != pg->get_peering_state().get_pg_log().get_log().objects.end()) {
      // look at log!
      pg_log_entry_t *latest = it_objects->second;
      assert(latest->is_update() || latest->is_delete());
      soid = latest->soid;
    } else {
      soid = p->second;
    }
    const pg_missing_item& item = missing.get_items().find(p->second)->second;
    ++p;

    hobject_t head = soid.get_head();

    crimson::get_logger(ceph_subsys_osd).info(
      "{} {} item.need {} {} {} {} {}",
      __func__,
      soid,
      item.need,
      missing.is_missing(soid) ? " (missing)":"",
      missing.is_missing(head) ? " (missing head)":"",
      pg->get_recovery_backend()->is_recovering(soid) ? " (recovering)":"",
      pg->get_recovery_backend()->is_recovering(head) ? " (recovering head)":"");

    // TODO: handle lost/unfound
    if (!pg->get_recovery_backend()->is_recovering(soid)) {
      if (pg->get_recovery_backend()->is_recovering(head)) {
	++skipped;
      } else {
	auto futopt = recover_missing(soid, item.need);
	if (futopt) {
	  out->push_back(std::move(*futopt));
	  ++started;
	} else {
	  ++skipped;
	}
      }
    }

    if (!skipped)
      pg->get_peering_state().set_last_requested(v);
  }

  crimson::get_logger(ceph_subsys_osd).info(
    "{} started {} skipped {}",
    __func__,
    started,
    skipped);

  return started;
}

size_t PGRecovery::start_replica_recovery_ops(
  size_t max_to_start,
  std::vector<crimson::osd::blocking_future<>> *out)
{
  if (!pg->is_recovering()) {
    return 0;
  }
  uint64_t started = 0;

  assert(!pg->get_peering_state().get_acting_recovery_backfill().empty());

  auto recovery_order = get_replica_recovery_order();
  for (auto &peer : recovery_order) {
    assert(peer != pg->get_peering_state().get_primary());
    auto pm = pg->get_peering_state().get_peer_missing().find(peer);
    assert(pm != pg->get_peering_state().get_peer_missing().end());

    size_t m_sz = pm->second.num_missing();

    crimson::get_logger(ceph_subsys_osd).debug(
	"{}: peer osd.{} missing {} objects",
	__func__,
	peer,
	m_sz);
    crimson::get_logger(ceph_subsys_osd).trace(
	"{}: peer osd.{} missing {}", __func__,
	peer, pm->second.get_items());

    // recover oldest first
    const pg_missing_t &m(pm->second);
    for (auto p = m.get_rmissing().begin();
	 p != m.get_rmissing().end() && started < max_to_start;
	 ++p) {
      const auto &soid = p->second;

      if (pg->get_peering_state().get_missing_loc().is_unfound(soid)) {
	crimson::get_logger(ceph_subsys_osd).debug(
	    "{}: object {} still unfound", __func__, soid);
	continue;
      }

      const pg_info_t &pi = pg->get_peering_state().get_peer_info(peer);
      if (soid > pi.last_backfill) {
	if (!pg->get_recovery_backend()->is_recovering(soid)) {
	  crimson::get_logger(ceph_subsys_osd).error(
	    "{}: object {} in missing set for backfill (last_backfill {})"
	    " but not in recovering",
	    __func__,
	    soid,
	    pi.last_backfill);
	  ceph_abort();
	}
	continue;
      }

      if (pg->get_recovery_backend()->is_recovering(soid)) {
	crimson::get_logger(ceph_subsys_osd).debug(
	    "{}: already recovering object {}", __func__, soid);
	continue;
      }

      if (pg->get_peering_state().get_missing_loc().is_deleted(soid)) {
	crimson::get_logger(ceph_subsys_osd).debug(
	    "{}: soid {} is a delete, removing", __func__, soid);
	map<hobject_t,pg_missing_item>::const_iterator r =
	  m.get_items().find(soid);
	started += prep_object_replica_deletes(
	  soid, r->second.need, out);
	continue;
      }

      if (soid.is_snap() &&
	  pg->get_peering_state().get_pg_log().get_missing().is_missing(
	    soid.get_head())) {
	crimson::get_logger(ceph_subsys_osd).debug(
	    "{}: head {} still missing on primary",
	    __func__, soid.get_head());
	continue;
      }

      if (pg->get_peering_state().get_pg_log().get_missing().is_missing(soid)) {
	crimson::get_logger(ceph_subsys_osd).debug(
	    "{}: soid {} still missing on primary", __func__, soid);
	continue;
      }

      crimson::get_logger(ceph_subsys_osd).debug(
	"{}: recover_object_replicas({})",
	__func__,
	soid);
      map<hobject_t,pg_missing_item>::const_iterator r = m.get_items().find(
	soid);
      started += prep_object_replica_pushes(
	soid, r->second.need, out);
    }
  }

  return started;
}

size_t PGRecovery::start_backfill_ops(
  size_t max_to_start,
  std::vector<crimson::osd::blocking_future<>> *out)
{
  assert(!pg->get_peering_state().get_backfill_targets().empty());

  ceph_abort("not implemented!");
}

std::optional<crimson::osd::blocking_future<>> PGRecovery::recover_missing(
  const hobject_t &soid, eversion_t need)
{
  if (pg->get_peering_state().get_missing_loc().is_deleted(soid)) {
    return pg->get_recovery_backend()->get_recovering(soid).make_blocking_future(
	pg->get_recovery_backend()->recover_delete(soid, need));
  } else {
    return pg->get_recovery_backend()->get_recovering(soid).make_blocking_future(
      pg->get_recovery_backend()->recover_object(soid, need).handle_exception(
	[=, soid = std::move(soid)] (auto e) {
	on_failed_recover({ pg->get_pg_whoami() }, soid, need);
	return seastar::make_ready_future<>();
      })
    );
  }
}

size_t PGRecovery::prep_object_replica_deletes(
  const hobject_t& soid,
  eversion_t need,
  std::vector<crimson::osd::blocking_future<>> *in_progress)
{
  in_progress->push_back(
    pg->get_recovery_backend()->get_recovering(soid).make_blocking_future(
      pg->get_recovery_backend()->push_delete(soid, need).then([=] {
	object_stat_sum_t stat_diff;
	stat_diff.num_objects_recovered = 1;
	on_global_recover(soid, stat_diff, true);
	return seastar::make_ready_future<>();
      })
    )
  );
  return 1;
}

size_t PGRecovery::prep_object_replica_pushes(
  const hobject_t& soid,
  eversion_t need,
  std::vector<crimson::osd::blocking_future<>> *in_progress)
{
  in_progress->push_back(
    pg->get_recovery_backend()->get_recovering(soid).make_blocking_future(
      pg->get_recovery_backend()->recover_object(soid, need).handle_exception(
	[=, soid = std::move(soid)] (auto e) {
	on_failed_recover({ pg->get_pg_whoami() }, soid, need);
	return seastar::make_ready_future<>();
      })
    )
  );
  return 1;
}

void PGRecovery::on_local_recover(
  const hobject_t& soid,
  const ObjectRecoveryInfo& recovery_info,
  const bool is_delete,
  ceph::os::Transaction& t)
{
  pg->get_peering_state().recover_got(soid,
      recovery_info.version, is_delete, t);

  if (pg->is_primary()) {
    if (!is_delete) {
      auto& obc = pg->get_recovery_backend()->get_recovering(soid).obc; //TODO: move to pg backend?
      obc->obs.exists = true;
      obc->obs.oi = recovery_info.oi;
      // obc is loaded the excl lock
      obc->put_lock_type(RWState::RWEXCL);
      assert(obc->get_recovery_read());
    }
    if (!pg->is_unreadable_object(soid)) {
      pg->get_recovery_backend()->get_recovering(soid).set_readable();
    }
  }
}

void PGRecovery::on_global_recover (
  const hobject_t& soid,
  const object_stat_sum_t& stat_diff,
  const bool is_delete)
{
  pg->get_peering_state().object_recovered(soid, stat_diff);
  auto& recovery_waiter = pg->get_recovery_backend()->get_recovering(soid);
  if (!is_delete)
    recovery_waiter.obc->drop_recovery_read();
  recovery_waiter.set_recovered();
  pg->get_recovery_backend()->remove_recovering(soid);
}

void PGRecovery::on_failed_recover(
  const set<pg_shard_t>& from,
  const hobject_t& soid,
  const eversion_t& v)
{
  for (auto pg_shard : from) {
    if (pg_shard != pg->get_pg_whoami()) {
      pg->get_peering_state().force_object_missing(pg_shard, soid, v);
    }
  }
}

void PGRecovery::on_peer_recover(
  pg_shard_t peer,
  const hobject_t &oid,
  const ObjectRecoveryInfo &recovery_info)
{
  crimson::get_logger(ceph_subsys_osd).debug(
      "{}: {}, {} on {}", __func__, oid,
      recovery_info.version, peer);
  pg->get_peering_state().on_peer_recover(peer, oid, recovery_info.version);
}

void PGRecovery::_committed_pushed_object(epoch_t epoch,
			      eversion_t last_complete)
{
  if (!pg->has_reset_since(epoch)) {
    pg->get_peering_state().recovery_committed_to(last_complete);
  } else {
    crimson::get_logger(ceph_subsys_osd).debug(
	"{} pg has changed, not touching last_complete_ondisk",
	__func__);
  }
}
