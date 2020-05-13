import datetime
import json
from contextlib import contextmanager

import pytest

from ceph.deployment.drive_group import DriveGroupSpec, DeviceSelection
from cephadm.services.osd import OSDRemoval

try:
    from typing import Any, List
except ImportError:
    pass

from execnet.gateway_bootstrap import HostNotFound

from ceph.deployment.service_spec import ServiceSpec, PlacementSpec, RGWSpec, \
    NFSServiceSpec, IscsiServiceSpec
from ceph.deployment.drive_selection.selector import DriveSelection
from ceph.deployment.inventory import Devices, Device
from orchestrator import ServiceDescription, DaemonDescription, InventoryHost, \
    HostSpec, OrchestratorError
from tests import mock
from .fixtures import cephadm_module, wait, _run_cephadm, mon_command, match_glob
from cephadm.module import CephadmOrchestrator


"""
TODOs:
    There is really room for improvement here. I just quickly assembled theses tests.
    I general, everything should be testes in Teuthology as well. Reasons for
    also testing this here is the development roundtrip time.
"""


def assert_rm_service(cephadm, srv_name):
    assert wait(cephadm, cephadm.remove_service(srv_name)) == [
        f'Removed service {srv_name}']
    cephadm._apply_all_services()


def assert_rm_daemon(cephadm: CephadmOrchestrator, prefix, host):
    dds: List[DaemonDescription] = wait(cephadm, cephadm.list_daemons(host=host))
    d_names = [dd.name() for dd in dds if dd.name().startswith(prefix)]
    assert d_names
    c = cephadm.remove_daemons(d_names)
    [out] = wait(cephadm, c)
    match_glob(out, f"Removed {d_names}* from host '{host}'")


class TestCephadm(object):

    @contextmanager
    def _with_host(self, m, name):
        # type: (CephadmOrchestrator, str) -> None
        wait(m, m.add_host(HostSpec(hostname=name)))
        yield
        wait(m, m.remove_host(name))

    def test_get_unique_name(self, cephadm_module):
        # type: (CephadmOrchestrator) -> None
        existing = [
            DaemonDescription(daemon_type='mon', daemon_id='a')
        ]
        new_mon = cephadm_module.get_unique_name('mon', 'myhost', existing)
        match_glob(new_mon, 'myhost')
        new_mgr = cephadm_module.get_unique_name('mgr', 'myhost', existing)
        match_glob(new_mgr, 'myhost.*')

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('[]'))
    def test_host(self, cephadm_module):
        assert wait(cephadm_module, cephadm_module.get_hosts()) == []
        with self._with_host(cephadm_module, 'test'):
            assert wait(cephadm_module, cephadm_module.get_hosts()) == [HostSpec('test', 'test')]

            # Be careful with backward compatibility when changing things here:
            assert json.loads(cephadm_module._store['inventory']) == \
                   {"test": {"hostname": "test", "addr": "test", "labels": [], "status": ""}}

            with self._with_host(cephadm_module, 'second'):
                assert wait(cephadm_module, cephadm_module.get_hosts()) == [
                    HostSpec('test', 'test'),
                    HostSpec('second', 'second')
                ]

            assert wait(cephadm_module, cephadm_module.get_hosts()) == [HostSpec('test', 'test')]
        assert wait(cephadm_module, cephadm_module.get_hosts()) == []

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('[]'))
    def test_service_ls(self, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            c = cephadm_module.list_daemons(refresh=True)
            assert wait(cephadm_module, c) == []

            ps = PlacementSpec(hosts=['test'], count=1)
            c = cephadm_module.add_mds(ServiceSpec('mds', 'name', placement=ps))
            [out] = wait(cephadm_module, c)
            match_glob(out, "Deployed mds.name.* on host 'test'")

            c = cephadm_module.list_daemons()

            def remove_id(dd):
                out = dd.to_json()
                del out['daemon_id']
                return out

            assert [remove_id(dd) for dd in wait(cephadm_module, c)] == [
                {
                    'daemon_type': 'mds',
                    'hostname': 'test',
                    'status': 1,
                    'status_desc': 'starting'}
            ]

            ps = PlacementSpec(hosts=['test'], count=1)
            spec = ServiceSpec('rgw', 'r.z', placement=ps)
            c = cephadm_module.apply_rgw(spec)
            assert wait(cephadm_module, c) == 'Scheduled rgw.r.z update...'

            c = cephadm_module.describe_service()
            out = [o.to_json() for o in wait(cephadm_module, c)]
            expected = [
                {
                    'placement': {'hosts': [{'hostname': 'test', 'name': '', 'network': ''}]},
                    'service_id': 'name',
                    'service_name': 'mds.name',
                    'service_type': 'mds',
                    'status': {'running': 1, 'size': 0},
                    'unmanaged': True
                },
                {
                    'placement': {
                        'count': 1,
                        'hosts': [{'hostname': 'test', 'name': '', 'network': ''}]
                    },
                    'rgw_realm': 'r',
                    'rgw_zone': 'z',
                    'service_id': 'r.z',
                    'service_name': 'rgw.r.z',
                    'service_type': 'rgw',
                    'status': {'running': 0, 'size': 1}
                }
            ]
            assert out == expected
            assert [ServiceDescription.from_json(o).to_json() for o in expected] == expected

            assert_rm_service(cephadm_module, 'rgw.r.z')
            assert_rm_daemon(cephadm_module, 'mds.name', 'test')

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('[]'))
    def test_device_ls(self, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            c = cephadm_module.get_inventory()
            assert wait(cephadm_module, c) == [InventoryHost('test')]

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm(
        json.dumps([
            dict(
                name='rgw.myrgw.foobar',
                style='cephadm',
                fsid='fsid',
                container_id='container_id',
                version='version',
                state='running',
            )
        ])
    ))
    def test_daemon_action(self, cephadm_module):
        cephadm_module.service_cache_timeout = 10
        with self._with_host(cephadm_module, 'test'):
            c = cephadm_module.list_daemons(refresh=True)
            wait(cephadm_module, c)
            c = cephadm_module.daemon_action('redeploy', 'rgw', 'myrgw.foobar')
            assert wait(cephadm_module, c) == ["Deployed rgw.myrgw.foobar on host 'test'"]

            for what in ('start', 'stop', 'restart'):
                c = cephadm_module.daemon_action(what, 'rgw', 'myrgw.foobar')
                assert wait(cephadm_module, c) == [what + " rgw.myrgw.foobar from host 'test'"]

            assert_rm_daemon(cephadm_module, 'rgw.myrgw.foobar', 'test')

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('[]'))
    def test_mon_add(self, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            ps = PlacementSpec(hosts=['test:0.0.0.0=a'], count=1)
            c = cephadm_module.add_mon(ServiceSpec('mon', placement=ps))
            assert wait(cephadm_module, c) == ["Deployed mon.a on host 'test'"]

            with pytest.raises(OrchestratorError, match="Must set public_network config option or specify a CIDR network,"):
                ps = PlacementSpec(hosts=['test'], count=1)
                c = cephadm_module.add_mon(ServiceSpec('mon', placement=ps))
                wait(cephadm_module, c)

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('[]'))
    def test_mgr_update(self, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            ps = PlacementSpec(hosts=['test:0.0.0.0=a'], count=1)
            r = cephadm_module._apply_service(ServiceSpec('mgr', placement=ps))
            assert r

            assert_rm_daemon(cephadm_module, 'mgr.a', 'test')

    @mock.patch("cephadm.module.CephadmOrchestrator.mon_command")
    def test_find_destroyed_osds(self, _mon_cmd, cephadm_module):
        dict_out = {
            "nodes": [
                {
                    "id": -1,
                    "name": "default",
                    "type": "root",
                    "type_id": 11,
                    "children": [
                        -3
                    ]
                },
                {
                    "id": -3,
                    "name": "host1",
                    "type": "host",
                    "type_id": 1,
                    "pool_weights": {},
                    "children": [
                        0
                    ]
                },
                {
                    "id": 0,
                    "device_class": "hdd",
                    "name": "osd.0",
                    "type": "osd",
                    "type_id": 0,
                    "crush_weight": 0.0243988037109375,
                    "depth": 2,
                    "pool_weights": {},
                    "exists": 1,
                    "status": "destroyed",
                    "reweight": 1,
                    "primary_affinity": 1
                }
            ],
            "stray": []
        }
        json_out = json.dumps(dict_out)
        _mon_cmd.return_value = (0, json_out, '')
        out = cephadm_module.osd_service.find_destroyed_osds()
        assert out == {'host1': ['0']}

    @mock.patch("cephadm.module.CephadmOrchestrator.mon_command")
    def test_find_destroyed_osds_cmd_failure(self, _mon_cmd, cephadm_module):
        _mon_cmd.return_value = (1, "", "fail_msg")
        with pytest.raises(OrchestratorError):
            out = cephadm_module.osd_service.find_destroyed_osds()

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    @mock.patch("cephadm.module.SpecStore.save")
    def test_apply_osd_save(self, _save_spec, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            json_spec = {'service_type': 'osd', 'host_pattern': 'test', 'service_id': 'foo', 'data_devices': {'all': True}}
            spec = ServiceSpec.from_json(json_spec)
            assert isinstance(spec, DriveGroupSpec)
            c = cephadm_module.apply_drivegroups([spec])
            assert wait(cephadm_module, c) == ['Scheduled osd.foo update...']
            _save_spec.assert_called_with(spec)

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    @mock.patch("cephadm.module.SpecStore.save")
    def test_apply_osd_save_placement(self, _save_spec, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            json_spec = {'service_type': 'osd', 'placement': {'host_pattern': 'test'}, 'service_id': 'foo', 'data_devices': {'all': True}}
            spec = ServiceSpec.from_json(json_spec)
            assert isinstance(spec, DriveGroupSpec)
            c = cephadm_module.apply_drivegroups([spec])
            assert wait(cephadm_module, c) == ['Scheduled osd.foo update...']
            _save_spec.assert_called_with(spec)

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    def test_create_osds(self, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            dg = DriveGroupSpec(placement=PlacementSpec(host_pattern='test'), data_devices=DeviceSelection(paths=['']))
            c = cephadm_module.create_osds(dg)
            out = wait(cephadm_module, c)
            assert out == "Created no osd(s) on host test; already created?"

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    def test_prepare_drivegroup(self, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            dg = DriveGroupSpec(placement=PlacementSpec(host_pattern='test'), data_devices=DeviceSelection(paths=['']))
            out = cephadm_module.osd_service.prepare_drivegroup(dg)
            assert len(out) == 1
            f1 = out[0]
            assert f1[0] == 'test'
            assert isinstance(f1[1], DriveSelection)

    @pytest.mark.parametrize(
        "devices, preview, exp_command",
        [
            # no preview and only one disk, prepare is used due the hack that is in place.
            (['/dev/sda'], False, "lvm prepare --bluestore --data /dev/sda --no-systemd"),
            # no preview and multiple disks, uses batch
            (['/dev/sda', '/dev/sdb'], False, "CEPH_VOLUME_OSDSPEC_AFFINITY=test.spec lvm batch --no-auto /dev/sda /dev/sdb --yes --no-systemd"),
            # preview and only one disk needs to use batch again to generate the preview
            (['/dev/sda'], True, "lvm batch --no-auto /dev/sda --report --format json"),
            # preview and multiple disks work the same
            (['/dev/sda', '/dev/sdb'], True, "CEPH_VOLUME_OSDSPEC_AFFINITY=test.spec lvm batch --no-auto /dev/sda /dev/sdb --yes --no-systemd --report --format json"),
        ]
    )
    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    def test_driveselection_to_ceph_volume(self, cephadm_module, devices, preview, exp_command):
        with self._with_host(cephadm_module, 'test'):
            dg = DriveGroupSpec(service_id='test.spec', placement=PlacementSpec(host_pattern='test'), data_devices=DeviceSelection(paths=devices))
            ds = DriveSelection(dg, Devices([Device(path) for path in devices]))
            preview = preview
            out = cephadm_module.osd_service.driveselection_to_ceph_volume(dg, ds, [], preview)
            assert out in exp_command

    @mock.patch("cephadm.module.SpecStore.find")
    @mock.patch("cephadm.services.osd.OSDService.prepare_drivegroup")
    @mock.patch("cephadm.services.osd.OSDService.driveselection_to_ceph_volume")
    @mock.patch("cephadm.services.osd.OSDService._run_ceph_volume_command")
    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    def test_preview_drivegroups_str(self, _run_c_v_command, _ds_to_cv, _prepare_dg, _find_store, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            dg = DriveGroupSpec(placement=PlacementSpec(host_pattern='test'), data_devices=DeviceSelection(paths=['']))
            _find_store.return_value = [dg]
            _prepare_dg.return_value = [('host1', 'ds_dummy')]
            _run_c_v_command.return_value = ("{}", '', 0)
            cephadm_module.osd_service.preview_drivegroups(drive_group_name='foo')
            _find_store.assert_called_once_with(service_name='foo')
            _prepare_dg.assert_called_once_with(dg)
            _run_c_v_command.assert_called_once()

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm(
        json.dumps([
            dict(
                name='osd.0',
                style='cephadm',
                fsid='fsid',
                container_id='container_id',
                version='version',
                state='running',
            )
        ])
    ))
    @mock.patch("cephadm.services.osd.RemoveUtil.get_pg_count", lambda _, __: 0)
    def test_remove_osds(self, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            c = cephadm_module.list_daemons(refresh=True)
            wait(cephadm_module, c)

            c = cephadm_module.remove_daemons(['osd.0'])
            out = wait(cephadm_module, c)
            assert out == ["Removed osd.0 from host 'test'"]

            osd_removal_op = OSDRemoval(0, False, False, 'test', 'osd.0', datetime.datetime.utcnow(), -1)
            cephadm_module.rm_util.queue_osds_for_removal({osd_removal_op})
            cephadm_module.rm_util._remove_osds_bg()
            assert cephadm_module.rm_util.to_remove_osds == set()

            c = cephadm_module.remove_osds_status()
            out = wait(cephadm_module, c)
            assert out == set()

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    def test_rgw_update(self, cephadm_module):
        with self._with_host(cephadm_module, 'host1'):
            with self._with_host(cephadm_module, 'host2'):
                ps = PlacementSpec(hosts=['host1'], count=1)
                c = cephadm_module.add_rgw(RGWSpec(rgw_realm='realm', rgw_zone='zone1', placement=ps))
                [out] = wait(cephadm_module, c)
                match_glob(out, "Deployed rgw.realm.zone1.host1.* on host 'host1'")

                ps = PlacementSpec(hosts=['host1', 'host2'], count=2)
                r = cephadm_module._apply_service(RGWSpec(rgw_realm='realm', rgw_zone='zone1', placement=ps))
                assert r

                assert_rm_daemon(cephadm_module, 'rgw.realm.zone1', 'host1')
                assert_rm_daemon(cephadm_module, 'rgw.realm.zone1', 'host2')

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm(
        json.dumps([
            dict(
                name='rgw.myrgw.myhost.myid',
                style='cephadm',
                fsid='fsid',
                container_id='container_id',
                version='version',
                state='running',
            )
        ])
    ))
    def test_remove_daemon(self, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            c = cephadm_module.list_daemons(refresh=True)
            wait(cephadm_module, c)
            c = cephadm_module.remove_daemons(['rgw.myrgw.myhost.myid'])
            out = wait(cephadm_module, c)
            assert out == ["Removed rgw.myrgw.myhost.myid from host 'test'"]

    @pytest.mark.parametrize(
        "spec, meth",
        [
            (ServiceSpec('crash'), CephadmOrchestrator.add_crash),
            (ServiceSpec('prometheus'), CephadmOrchestrator.add_prometheus),
            (ServiceSpec('grafana'), CephadmOrchestrator.add_grafana),
            (ServiceSpec('node-exporter'), CephadmOrchestrator.add_node_exporter),
            (ServiceSpec('alertmanager'), CephadmOrchestrator.add_alertmanager),
            (ServiceSpec('rbd-mirror'), CephadmOrchestrator.add_rbd_mirror),
            (ServiceSpec('mds', service_id='fsname'), CephadmOrchestrator.add_mds),
            (RGWSpec(rgw_realm='realm', rgw_zone='zone'), CephadmOrchestrator.add_rgw),
        ]
    )
    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    def test_daemon_add(self, spec: ServiceSpec, meth, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            spec.placement = PlacementSpec(hosts=['test'], count=1)

            c = meth(cephadm_module, spec)
            [out] = wait(cephadm_module, c)
            match_glob(out, f"Deployed {spec.service_name()}.* on host 'test'")

            assert_rm_daemon(cephadm_module, spec.service_name(), 'test')

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    @mock.patch("cephadm.module.CephadmOrchestrator.rados", mock.MagicMock())
    def test_nfs(self, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            ps = PlacementSpec(hosts=['test'], count=1)
            spec = NFSServiceSpec('name', pool='pool', namespace='namespace', placement=ps)
            c = cephadm_module.add_nfs(spec)
            [out] = wait(cephadm_module, c)
            match_glob(out, "Deployed nfs.name.* on host 'test'")

            assert_rm_daemon(cephadm_module, 'nfs.name.test', 'test')

            # Hack. We never created the service, but we now need to remove it.
            # this is in contrast to the other services, which don't create this service
            # automatically.
            assert_rm_service(cephadm_module, 'nfs.name')

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    @mock.patch("cephadm.module.CephadmOrchestrator.rados", mock.MagicMock())
    def test_iscsi(self, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            ps = PlacementSpec(hosts=['test'], count=1)
            spec = IscsiServiceSpec('name', pool='pool', placement=ps)
            c = cephadm_module.add_iscsi(spec)
            [out] = wait(cephadm_module, c)
            match_glob(out, "Deployed iscsi.name.* on host 'test'")

            assert_rm_daemon(cephadm_module, 'iscsi.name.test', 'test')

            # Hack. We never created the service, but we now need to remove it.
            # this is in contrast to the other services, which don't create this service
            # automatically.
            assert_rm_service(cephadm_module, 'iscsi.name')

    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    def test_blink_device_light(self, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            c = cephadm_module.blink_device_light('ident', True, [('test', '', '')])
            assert wait(cephadm_module, c) == ['Set ident light for test: on']

    @pytest.mark.parametrize(
        "spec, meth",
        [
            (ServiceSpec('mgr'), CephadmOrchestrator.apply_mgr),
            (ServiceSpec('crash'), CephadmOrchestrator.apply_crash),
            (ServiceSpec('prometheus'), CephadmOrchestrator.apply_prometheus),
            (ServiceSpec('grafana'), CephadmOrchestrator.apply_grafana),
            (ServiceSpec('node-exporter'), CephadmOrchestrator.apply_node_exporter),
            (ServiceSpec('alertmanager'), CephadmOrchestrator.apply_alertmanager),
            (ServiceSpec('rbd-mirror'), CephadmOrchestrator.apply_rbd_mirror),
            (ServiceSpec('mds', service_id='fsname'), CephadmOrchestrator.apply_mds),
            (RGWSpec(rgw_realm='realm', rgw_zone='zone'), CephadmOrchestrator.apply_rgw),
            (NFSServiceSpec('name', pool='pool', namespace='namespace'), CephadmOrchestrator.apply_nfs),
            (IscsiServiceSpec('name', pool='pool'), CephadmOrchestrator.apply_iscsi),
        ]
    )
    @mock.patch("cephadm.module.CephadmOrchestrator._run_cephadm", _run_cephadm('{}'))
    def test_apply_save(self, spec: ServiceSpec, meth, cephadm_module):
        with self._with_host(cephadm_module, 'test'):
            spec.placement = PlacementSpec(hosts=['test'], count=1)
            c = meth(cephadm_module, spec)
            assert wait(cephadm_module, c) == f'Scheduled {spec.service_name()} update...'
            assert [d.spec for d in wait(cephadm_module, cephadm_module.describe_service())] == [spec]

            assert_rm_service(cephadm_module, spec.service_name())


    @mock.patch("cephadm.module.CephadmOrchestrator._get_connection")
    @mock.patch("remoto.process.check")
    def test_offline(self, _check, _get_connection, cephadm_module):
        _check.return_value = '{}', '', 0
        _get_connection.return_value = mock.Mock(), mock.Mock()
        with self._with_host(cephadm_module, 'test'):
            _get_connection.side_effect = HostNotFound
            code, out, err = cephadm_module.check_host('test')
            assert out == ''
            assert 'Failed to connect to test (test)' in err

            out = wait(cephadm_module, cephadm_module.get_hosts())[0].to_json()
            assert out == HostSpec('test', 'test', status='Offline').to_json()

            _get_connection.side_effect = None
            assert cephadm_module._check_host('test') is None
            out = wait(cephadm_module, cephadm_module.get_hosts())[0].to_json()
            assert out == HostSpec('test', 'test').to_json()
