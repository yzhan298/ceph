import datetime
from copy import copy
import json
import logging
from typing import TYPE_CHECKING, Dict, List, Iterator, Optional, Any, Tuple

import six

import orchestrator
from ceph.deployment import inventory
from ceph.deployment.service_spec import ServiceSpec
from orchestrator import OrchestratorError, HostSpec

if TYPE_CHECKING:
    from .module import CephadmOrchestrator


logger = logging.getLogger(__name__)

HOST_CACHE_PREFIX = "host."
SPEC_STORE_PREFIX = "spec."
DATEFMT = '%Y-%m-%dT%H:%M:%S.%f'


class Inventory:
    def __init__(self, mgr: 'CephadmOrchestrator'):
        self.mgr = mgr
        # load inventory
        i = self.mgr.get_store('inventory')
        if i:
            self._inventory: Dict[str, dict] = json.loads(i)
        else:
            self._inventory = dict()
        logger.debug('Loaded inventory %s' % self._inventory)

    def keys(self) -> List[str]:
        return list(self._inventory.keys())

    def __contains__(self, host: str) -> bool:
        return host in self._inventory

    def assert_host(self, host):
        if host not in self._inventory:
            raise OrchestratorError('host %s does not exist' % host)

    def add_host(self, spec: HostSpec):
        self._inventory[spec.hostname] = spec.to_json()
        self.save()

    def rm_host(self, host: str):
        self.assert_host(host)
        del self._inventory[host]
        self.save()

    def set_addr(self, host, addr):
        self.assert_host(host)
        self._inventory[host]['addr'] = addr
        self.save()

    def add_label(self, host, label):
        self.assert_host(host)

        if 'labels' not in self._inventory[host]:
            self._inventory[host]['labels'] = list()
        if label not in self._inventory[host]['labels']:
            self._inventory[host]['labels'].append(label)
        self.save()

    def rm_label(self, host, label):
        self.assert_host(host)

        if 'labels' not in self._inventory[host]:
            self._inventory[host]['labels'] = list()
        if label in self._inventory[host]['labels']:
            self._inventory[host]['labels'].remove(label)
        self.save()

    def get_addr(self, host) -> str:
        self.assert_host(host)
        return self._inventory[host].get('addr', host)

    def filter_by_label(self, label=None) -> Iterator[str]:
        for h, hostspec in self._inventory.items():
            if not label or label in hostspec.get('labels', []):
                yield h

    def spec_from_dict(self, info):
        hostname = info['hostname']
        return HostSpec(
                hostname,
                addr=info.get('addr', hostname),
                labels=info.get('labels', []),
                status='Offline' if hostname in self.mgr.offline_hosts else info.get('status', ''),
            )

    def all_specs(self) -> Iterator[HostSpec]:
        return map(self.spec_from_dict, self._inventory.values())

    def save(self):
        self.mgr.set_store('inventory', json.dumps(self._inventory))


class SpecStore():
    def __init__(self, mgr):
        # type: (CephadmOrchestrator) -> None
        self.mgr = mgr
        self.specs = {} # type: Dict[str, ServiceSpec]
        self.spec_created = {} # type: Dict[str, datetime.datetime]

    def load(self):
        # type: () -> None
        for k, v in six.iteritems(self.mgr.get_store_prefix(SPEC_STORE_PREFIX)):
            service_name = k[len(SPEC_STORE_PREFIX):]
            try:
                v = json.loads(v)
                spec = ServiceSpec.from_json(v['spec'])
                created = datetime.datetime.strptime(v['created'], DATEFMT)
                self.specs[service_name] = spec
                self.spec_created[service_name] = created
                self.mgr.log.debug('SpecStore: loaded spec for %s' % (
                    service_name))
            except Exception as e:
                self.mgr.log.warning('unable to load spec for %s: %s' % (
                    service_name, e))
                pass

    def save(self, spec):
        # type: (ServiceSpec) -> None
        self.specs[spec.service_name()] = spec
        self.spec_created[spec.service_name()] = datetime.datetime.utcnow()
        self.mgr.set_store(
            SPEC_STORE_PREFIX + spec.service_name(),
            json.dumps({
                'spec': spec.to_json(),
                'created': self.spec_created[spec.service_name()].strftime(DATEFMT),
            }, sort_keys=True),
        )

    def rm(self, service_name):
        # type: (str) -> bool
        found = service_name in self.specs
        if found:
            del self.specs[service_name]
            del self.spec_created[service_name]
            self.mgr.set_store(SPEC_STORE_PREFIX + service_name, None)
        return found

    def find(self, service_name: Optional[str] = None) -> List[ServiceSpec]:
        specs = []
        for sn, spec in self.specs.items():
            if not service_name or \
                    sn == service_name or \
                    sn.startswith(service_name + '.'):
                specs.append(spec)
        self.mgr.log.debug('SpecStore: find spec for %s returned: %s' % (
            service_name, specs))
        return specs

class HostCache():
    def __init__(self, mgr):
        # type: (CephadmOrchestrator) -> None
        self.mgr: CephadmOrchestrator = mgr
        self.daemons = {}   # type: Dict[str, Dict[str, orchestrator.DaemonDescription]]
        self.last_daemon_update = {}   # type: Dict[str, datetime.datetime]
        self.devices = {}              # type: Dict[str, List[inventory.Device]]
        self.networks = {}             # type: Dict[str, Dict[str, List[str]]]
        self.last_device_update = {}   # type: Dict[str, datetime.datetime]
        self.daemon_refresh_queue = [] # type: List[str]
        self.device_refresh_queue = [] # type: List[str]
        self.daemon_config_deps = {}   # type: Dict[str, Dict[str, Dict[str,Any]]]
        self.last_host_check = {}      # type: Dict[str, datetime.datetime]

    def load(self):
        # type: () -> None
        for k, v in six.iteritems(self.mgr.get_store_prefix(HOST_CACHE_PREFIX)):
            host = k[len(HOST_CACHE_PREFIX):]
            if host not in self.mgr.inventory:
                self.mgr.log.warning('removing stray HostCache host record %s' % (
                    host))
                self.mgr.set_store(k, None)
            try:
                j = json.loads(v)
                if 'last_device_update' in j:
                    self.last_device_update[host] = datetime.datetime.strptime(
                        j['last_device_update'], DATEFMT)
                else:
                    self.device_refresh_queue.append(host)
                # for services, we ignore the persisted last_*_update
                # and always trigger a new scrape on mgr restart.
                self.daemon_refresh_queue.append(host)
                self.daemons[host] = {}
                self.devices[host] = []
                self.networks[host] = {}
                self.daemon_config_deps[host] = {}
                for name, d in j.get('daemons', {}).items():
                    self.daemons[host][name] = \
                        orchestrator.DaemonDescription.from_json(d)
                for d in j.get('devices', []):
                    self.devices[host].append(inventory.Device.from_json(d))
                self.networks[host] = j.get('networks', {})
                for name, d in j.get('daemon_config_deps', {}).items():
                    self.daemon_config_deps[host][name] = {
                        'deps': d.get('deps', []),
                        'last_config': datetime.datetime.strptime(
                            d['last_config'], DATEFMT),
                    }
                if 'last_host_check' in j:
                    self.last_host_check[host] = datetime.datetime.strptime(
                        j['last_host_check'], DATEFMT)
                self.mgr.log.debug(
                    'HostCache.load: host %s has %d daemons, '
                    '%d devices, %d networks' % (
                        host, len(self.daemons[host]), len(self.devices[host]),
                        len(self.networks[host])))
            except Exception as e:
                self.mgr.log.warning('unable to load cached state for %s: %s' % (
                    host, e))
                pass

    def update_host_daemons(self, host, dm):
        # type: (str, Dict[str, orchestrator.DaemonDescription]) -> None
        self.daemons[host] = dm
        self.last_daemon_update[host] = datetime.datetime.utcnow()

    def update_host_devices_networks(self, host, dls, nets):
        # type: (str, List[inventory.Device], Dict[str,List[str]]) -> None
        self.devices[host] = dls
        self.networks[host] = nets
        self.last_device_update[host] = datetime.datetime.utcnow()

    def update_daemon_config_deps(self, host, name, deps, stamp):
        self.daemon_config_deps[host][name] = {
            'deps': deps,
            'last_config': stamp,
        }

    def update_last_host_check(self, host):
        # type: (str) -> None
        self.last_host_check[host] = datetime.datetime.utcnow()

    def prime_empty_host(self, host):
        # type: (str) -> None
        """
        Install an empty entry for a host
        """
        self.daemons[host] = {}
        self.devices[host] = []
        self.networks[host] = {}
        self.daemon_config_deps[host] = {}
        self.daemon_refresh_queue.append(host)
        self.device_refresh_queue.append(host)

    def invalidate_host_daemons(self, host):
        # type: (str) -> None
        self.daemon_refresh_queue.append(host)
        if host in self.last_daemon_update:
            del self.last_daemon_update[host]
        self.mgr.event.set()

    def invalidate_host_devices(self, host):
        # type: (str) -> None
        self.device_refresh_queue.append(host)
        if host in self.last_device_update:
            del self.last_device_update[host]
        self.mgr.event.set()

    def save_host(self, host):
        # type: (str) -> None
        j = {   # type: ignore
            'daemons': {},
            'devices': [],
            'daemon_config_deps': {},
        }
        if host in self.last_daemon_update:
            j['last_daemon_update'] = self.last_daemon_update[host].strftime(DATEFMT) # type: ignore
        if host in self.last_device_update:
            j['last_device_update'] = self.last_device_update[host].strftime(DATEFMT) # type: ignore
        for name, dd in self.daemons[host].items():
            j['daemons'][name] = dd.to_json()  # type: ignore
        for d in self.devices[host]:
            j['devices'].append(d.to_json())  # type: ignore
        j['networks'] = self.networks[host]
        for name, depi in self.daemon_config_deps[host].items():
            j['daemon_config_deps'][name] = {   # type: ignore
                'deps': depi.get('deps', []),
                'last_config': depi['last_config'].strftime(DATEFMT),
            }
        if host in self.last_host_check:
            j['last_host_check']= self.last_host_check[host].strftime(DATEFMT)
        self.mgr.set_store(HOST_CACHE_PREFIX + host, json.dumps(j))

    def rm_host(self, host):
        # type: (str) -> None
        if host in self.daemons:
            del self.daemons[host]
        if host in self.devices:
            del self.devices[host]
        if host in self.networks:
            del self.networks[host]
        if host in self.last_daemon_update:
            del self.last_daemon_update[host]
        if host in self.last_device_update:
            del self.last_device_update[host]
        if host in self.daemon_config_deps:
            del self.daemon_config_deps[host]
        self.mgr.set_store(HOST_CACHE_PREFIX + host, None)

    def get_hosts(self):
        # type: () -> List[str]
        r = []
        for host, di in self.daemons.items():
            r.append(host)
        return r

    def get_daemons(self):
        # type: () -> List[orchestrator.DaemonDescription]
        r = []
        for host, dm in self.daemons.items():
            for name, dd in dm.items():
                r.append(dd)
        return r

    def get_daemons_with_volatile_status(self) -> Iterator[Tuple[str, Dict[str, orchestrator.DaemonDescription]]]:
        for host, dm in self.daemons.items():
            if host in self.mgr.offline_hosts:
                def set_offline(dd: orchestrator.DaemonDescription) -> orchestrator.DaemonDescription:
                    ret = copy(dd)
                    ret.status = -1
                    ret.status_desc = 'host is offline'
                    return ret
                yield host, {name: set_offline(d) for name, d in dm.items()}
            else:
                yield host, dm

    def get_daemons_by_service(self, service_name):
        # type: (str) -> List[orchestrator.DaemonDescription]
        result = []   # type: List[orchestrator.DaemonDescription]
        for host, dm in self.daemons.items():
            for name, d in dm.items():
                if name.startswith(service_name + '.'):
                    result.append(d)
        return result

    def get_daemon_names(self):
        # type: () -> List[str]
        r = []
        for host, dm in self.daemons.items():
            for name, dd in dm.items():
                r.append(name)
        return r

    def get_daemon_last_config_deps(self, host, name):
        if host in self.daemon_config_deps:
            if name in self.daemon_config_deps[host]:
                return self.daemon_config_deps[host][name].get('deps', []), \
                    self.daemon_config_deps[host][name].get('last_config', None)
        return None, None

    def host_needs_daemon_refresh(self, host):
        # type: (str) -> bool
        if host in self.mgr.offline_hosts:
            logger.debug(f'Host "{host}" marked as offline. Skipping daemon refresh')
            return False
        if host in self.daemon_refresh_queue:
            self.daemon_refresh_queue.remove(host)
            return True
        cutoff = datetime.datetime.utcnow() - datetime.timedelta(
            seconds=self.mgr.daemon_cache_timeout)
        if host not in self.last_daemon_update or self.last_daemon_update[host] < cutoff:
            return True
        return False

    def host_needs_device_refresh(self, host):
        # type: (str) -> bool
        if host in self.mgr.offline_hosts:
            logger.debug(f'Host "{host}" marked as offline. Skipping device refresh')
            return False
        if host in self.device_refresh_queue:
            self.device_refresh_queue.remove(host)
            return True
        cutoff = datetime.datetime.utcnow() - datetime.timedelta(
            seconds=self.mgr.device_cache_timeout)
        if host not in self.last_device_update or self.last_device_update[host] < cutoff:
            return True
        return False

    def host_needs_check(self, host):
        # type: (str) -> bool
        cutoff = datetime.datetime.utcnow() - datetime.timedelta(
            seconds=self.mgr.host_check_interval)
        return host not in self.last_host_check or self.last_host_check[host] < cutoff

    def add_daemon(self, host, dd):
        # type: (str, orchestrator.DaemonDescription) -> None
        assert host in self.daemons
        self.daemons[host][dd.name()] = dd

    def rm_daemon(self, host, name):
        if host in self.daemons:
            if name in self.daemons[host]:
                del self.daemons[host][name]