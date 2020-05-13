import logging

import rados
from typing import Dict, Optional, Tuple, Any, List, cast

from ceph.deployment.service_spec import NFSServiceSpec

import orchestrator
from orchestrator import OrchestratorError

import cephadm
from .. import utils

from .cephadmservice import CephadmService
logger = logging.getLogger(__name__)


class NFSService(CephadmService):
    def _generate_nfs_config(self, daemon_type, daemon_id, host):
        # type: (str, str, str) -> Tuple[Dict[str, Any], List[str]]
        deps = []  # type: List[str]

        # find the matching NFSServiceSpec
        # TODO: find the spec and pass via _create_daemon instead ??
        dd = orchestrator.DaemonDescription()
        dd.daemon_type = daemon_type
        dd.daemon_id = daemon_id
        dd.hostname = host

        service_name = dd.service_name()
        specs = self.mgr.spec_store.find(service_name)

        if not specs:
            raise OrchestratorError('Cannot find service spec %s' % (service_name))
        elif len(specs) > 1:
            raise OrchestratorError('Found multiple service specs for %s' % (service_name))
        else:
            # cast to keep mypy happy
            spec = cast(NFSServiceSpec, specs[0])

        nfs = NFSGanesha(self.mgr, daemon_id, spec)

        # create the keyring
        entity = nfs.get_keyring_entity()
        keyring = nfs.get_or_create_keyring(entity=entity)

        # update the caps after get-or-create, the keyring might already exist!
        nfs.update_keyring_caps(entity=entity)

        # create the rados config object
        nfs.create_rados_config_obj()

        # generate the cephadm config
        cephadm_config = nfs.get_cephadm_config()
        cephadm_config.update(
                self.mgr._get_config_and_keyring(
                    daemon_type, daemon_id,
                    keyring=keyring))

        return cephadm_config, deps

    def config(self, spec):
        self.mgr._check_pool_exists(spec.pool, spec.service_name())

        logger.info('Saving service %s spec with placement %s' % (
            spec.service_name(), spec.placement.pretty_str()))
        self.mgr.spec_store.save(spec)

    def create(self, daemon_id, host, spec):
        return self.mgr._create_daemon('nfs', daemon_id, host)


class NFSGanesha(object):
    def __init__(self,
                 mgr,
                 daemon_id,
                 spec):
        # type: (cephadm.CephadmOrchestrator, str, NFSServiceSpec) -> None
        assert spec.service_id and daemon_id.startswith(spec.service_id)
        self.mgr = mgr
        self.daemon_id = daemon_id
        self.spec = spec

    def get_daemon_name(self):
        # type: () -> str
        return '%s.%s' % (self.spec.service_type, self.daemon_id)

    def get_rados_user(self):
        # type: () -> str
        return '%s.%s' % (self.spec.service_type, self.daemon_id)

    def get_keyring_entity(self):
        # type: () -> str
        return utils.name_to_config_section(self.get_rados_user())

    def get_or_create_keyring(self, entity=None):
        # type: (Optional[str]) -> str
        if not entity:
            entity = self.get_keyring_entity()

        logger.info('Create keyring: %s' % entity)
        ret, keyring, err = self.mgr.mon_command({
            'prefix': 'auth get-or-create',
            'entity': entity,
        })

        if ret != 0:
            raise OrchestratorError(
                    'Unable to create keyring %s: %s %s' \
                            % (entity, ret, err))
        return keyring

    def update_keyring_caps(self, entity=None):
        # type: (Optional[str]) -> None
        if not entity:
            entity = self.get_keyring_entity()

        osd_caps='allow rw pool=%s' % (self.spec.pool)
        if self.spec.namespace:
            osd_caps='%s namespace=%s' % (osd_caps, self.spec.namespace)

        logger.info('Updating keyring caps: %s' % entity)
        ret, out, err = self.mgr.mon_command({
            'prefix': 'auth caps',
            'entity': entity,
            'caps': ['mon', 'allow r',
                     'osd', osd_caps,
                     'mds', 'allow rw'],
        })

        if ret != 0:
            raise OrchestratorError(
                    'Unable to update keyring caps %s: %s %s' \
                            % (entity, ret, err))

    def create_rados_config_obj(self, clobber=False):
        # type: (Optional[bool]) -> None
        obj = self.spec.rados_config_name()

        with self.mgr.rados.open_ioctx(self.spec.pool) as ioctx:
            if self.spec.namespace:
                ioctx.set_namespace(self.spec.namespace)

            exists = True
            try:
                ioctx.stat(obj)
            except rados.ObjectNotFound as e:
                exists = False

            if exists and not clobber:
                # Assume an existing config
                logger.info('Rados config object exists: %s' % obj)
            else:
                # Create an empty config object
                logger.info('Creating rados config object: %s' % obj)
                ioctx.write_full(obj, ''.encode('utf-8'))

    def get_ganesha_conf(self):
        # type: () -> str
        return '''# generated by cephadm
NFS_CORE_PARAM {{
        Enable_NLM = false;
        Enable_RQUOTA = false;
        Protocols = 4;
}}

CACHEINODE {{
        Dir_Chunk = 0;
        NParts = 1;
        Cache_Size = 1;
}}

EXPORT_DEFAULTS {{
        Attr_Expiration_Time = 0;
}}

NFSv4 {{
        Delegations = false;
        RecoveryBackend = 'rados_cluster';
        Minor_Versions = 1, 2;
}}

RADOS_KV {{
        UserId = "{user}";
        nodeid = "{nodeid}";
        pool = "{pool}";
        namespace = "{namespace}";
}}

RADOS_URLS {{
        UserId = "{user}";
        watch_url = "{url}";
}}

%url    {url}
'''.format(user=self.get_rados_user(),
           nodeid=self.get_daemon_name(),
           pool=self.spec.pool,
           namespace=self.spec.namespace if self.spec.namespace else '',
           url=self.spec.rados_config_location())

    def get_cephadm_config(self):
        # type: () -> Dict
        config = {'pool' : self.spec.pool} # type: Dict
        if self.spec.namespace:
            config['namespace'] = self.spec.namespace
        config['userid'] = self.get_rados_user()
        config['extra_args'] = ['-N', 'NIV_EVENT']
        config['files'] = {
            'ganesha.conf' : self.get_ganesha_conf(),
        }
        logger.debug('Generated cephadm config-json: %s' % config)
        return config
