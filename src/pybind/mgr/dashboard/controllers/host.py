# -*- coding: utf-8 -*-
from __future__ import absolute_import
import copy

from typing import List

from mgr_util import merge_dicts
from orchestrator import HostSpec
from . import ApiController, RESTController, Task
from .orchestrator import raise_if_no_orchestrator
from .. import mgr
from ..exceptions import DashboardException
from ..security import Scope
from ..services.orchestrator import OrchClient
from ..services.ceph_service import CephService
from ..services.exception import handle_orchestrator_error


def host_task(name, metadata, wait_for=10.0):
    return Task("host/{}".format(name), metadata, wait_for)


def merge_hosts_by_hostname(ceph_hosts, orch_hosts):
    # type: (List[dict], List[HostSpec]) -> List[dict]
    """Merge Ceph hosts with orchestrator hosts by hostnames.

    :param ceph_hosts: hosts returned from mgr
    :type ceph_hosts: list of dict
    :param orch_hosts: hosts returned from ochestrator
    :type orch_hosts: list of HostSpec
    :return list of dict
    """
    _ceph_hosts = copy.deepcopy(ceph_hosts)
    orch_hostnames = {host.hostname for host in orch_hosts}

    # hosts in both Ceph and Orchestrator
    for ceph_host in _ceph_hosts:
        if ceph_host['hostname'] in orch_hostnames:
            ceph_host['sources']['orchestrator'] = True
            orch_hostnames.remove(ceph_host['hostname'])

    # Hosts only in Orchestrator
    orch_sources = {'ceph': False, 'orchestrator': True}
    _orch_hosts = [dict(hostname=hostname, ceph_version='', services=[], sources=orch_sources)
                   for hostname in orch_hostnames]
    _ceph_hosts.extend(_orch_hosts)
    return _ceph_hosts


def get_hosts(from_ceph=True, from_orchestrator=True):
    """get hosts from various sources"""
    ceph_hosts = []
    if from_ceph:
        ceph_hosts = [merge_dicts(server, {'sources': {'ceph': True, 'orchestrator': False}})
                      for server in mgr.list_servers()]
    if from_orchestrator:
        orch = OrchClient.instance()
        if orch.available():
            return merge_hosts_by_hostname(ceph_hosts, orch.hosts.list())
    return ceph_hosts


@ApiController('/host', Scope.HOSTS)
class Host(RESTController):

    def list(self, sources=None):
        if sources is None:
            return get_hosts()
        _sources = sources.split(',')
        from_ceph = 'ceph' in _sources
        from_orchestrator = 'orchestrator' in _sources
        return get_hosts(from_ceph, from_orchestrator)

    @raise_if_no_orchestrator
    @handle_orchestrator_error('host')
    @host_task('create', {'hostname': '{hostname}'})
    def create(self, hostname):
        orch_client = OrchClient.instance()
        self._check_orchestrator_host_op(orch_client, hostname, True)
        orch_client.hosts.add(hostname)

    @raise_if_no_orchestrator
    @handle_orchestrator_error('host')
    @host_task('delete', {'hostname': '{hostname}'})
    def delete(self, hostname):
        orch_client = OrchClient.instance()
        self._check_orchestrator_host_op(orch_client, hostname, False)
        orch_client.hosts.remove(hostname)

    def _check_orchestrator_host_op(self, orch_client, hostname, add_host=True):
        """Check if we can adding or removing a host with orchestrator

        :param orch_client: Orchestrator client
        :param add: True for adding host operation, False for removing host
        :raise DashboardException
        """
        host = orch_client.hosts.get(hostname)
        if add_host and host:
            raise DashboardException(
                code='orchestrator_add_existed_host',
                msg='{} is already in orchestrator'.format(hostname),
                component='orchestrator')
        if not add_host and not host:
            raise DashboardException(
                code='orchestrator_remove_nonexistent_host',
                msg='Remove a non-existent host {} from orchestrator'.format(
                    hostname),
                component='orchestrator')

    @RESTController.Resource('GET')
    def devices(self, hostname):
        # (str) -> List
        return CephService.get_devices_by_host(hostname)

    @RESTController.Resource('GET')
    def smart(self, hostname):
        # type: (str) -> dict
        return CephService.get_smart_data_by_host(hostname)

    @RESTController.Resource('GET')
    @raise_if_no_orchestrator
    def daemons(self, hostname: str) -> List[dict]:
        orch = OrchClient.instance()
        daemons = orch.services.list_daemons(None, hostname)
        return [d.to_json() for d in daemons]
