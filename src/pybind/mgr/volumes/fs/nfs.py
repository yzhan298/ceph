import json
import errno
import logging

import cephfs
import orchestrator
from .fs_util import create_pool

log = logging.getLogger(__name__)

class GaneshaConfParser(object):
    def __init__(self, raw_config):
        self.pos = 0
        self.text = ""

    @staticmethod
    def _indentation(depth, size=4):
        conf_str = ""
        for _ in range(0, depth*size):
            conf_str += " "
        return conf_str

    @staticmethod
    def write_block_body(block, depth=0):
        def format_val(key, val):
            if isinstance(val, list):
                return ', '.join([format_val(key, v) for v in val])
            if isinstance(val, bool):
                return str(val).lower()
            if isinstance(val, int) or (block['block_name'] == 'CLIENT'
                                        and key == 'clients'):
                return '{}'.format(val)
            return '"{}"'.format(val)

        conf_str = ""
        for key, val in block.items():
            if key == 'block_name':
                continue
            elif key == '_blocks_':
                for blo in val:
                    conf_str += GaneshaConfParser.write_block(blo, depth)
            elif val:
                conf_str += GaneshaConfParser._indentation(depth)
                conf_str += '{} = {};\n'.format(key, format_val(key, val))
        return conf_str

    @staticmethod
    def write_block(block, depth):
        if block['block_name'] == "%url":
            return '%url "{}"\n\n'.format(block['value'])

        conf_str = ""
        conf_str += GaneshaConfParser._indentation(depth)
        conf_str += format(block['block_name'])
        conf_str += " {\n"
        conf_str += GaneshaConfParser.write_block_body(block, depth+1)
        conf_str += GaneshaConfParser._indentation(depth)
        conf_str += "}\n\n"
        return conf_str

    @staticmethod
    def write_conf(blocks):
        if not isinstance(blocks, list):
            blocks = [blocks]
        conf_str = ""
        for block in blocks:
            conf_str += GaneshaConfParser.write_block(block, 0)
        return conf_str

class CephFSFSal():
    def __init__(self, name, user_id=None, fs_name=None, sec_label_xattr=None,
                 cephx_key=None):
        self.name = name
        self.fs_name = fs_name
        self.user_id = user_id
        self.sec_label_xattr = sec_label_xattr
        self.cephx_key = cephx_key

    @classmethod
    def from_fsal_block(cls, fsal_block):
        return cls(fsal_block['name'],
                   fsal_block.get('user_id', None),
                   fsal_block.get('filesystem', None),
                   fsal_block.get('sec_label_xattr', None),
                   fsal_block.get('secret_access_key', None))

    def to_fsal_block(self):
        result = {
            'block_name': 'FSAL',
            'name': self.name,
        }
        if self.user_id:
            result['user_id'] = self.user_id
        if self.fs_name:
            result['filesystem'] = self.fs_name
        if self.sec_label_xattr:
            result['sec_label_xattr'] = self.sec_label_xattr
        if self.cephx_key:
            result['secret_access_key'] = self.cephx_key
        return result

    @classmethod
    def from_dict(cls, fsal_dict):
        return cls(fsal_dict['name'], fsal_dict['user_id'],
                   fsal_dict['fs_name'], fsal_dict['sec_label_xattr'], None)

class Client(object):
    def __init__(self, addresses, access_type=None, squash=None):
        self.addresses = addresses
        self.access_type = access_type
        self.squash = squash

    @classmethod
    def from_client_block(cls, client_block):
        addresses = client_block['clients']
        if not isinstance(addresses, list):
            addresses = [addresses]
        return cls(addresses,
                   client_block.get('access_type', None),
                   client_block.get('squash', None))

    def to_client_block(self):
        result = {
            'block_name': 'CLIENT',
            'clients': self.addresses,
        }
        if self.access_type:
            result['access_type'] = self.access_type
        if self.squash:
            result['squash'] = self.squash
        return result

    @classmethod
    def from_dict(cls, client_dict):
        return cls(client_dict['addresses'], client_dict['access_type'],
                   client_dict['squash'])

    def to_dict(self):
        return {
            'addresses': self.addresses,
            'access_type': self.access_type,
            'squash': self.squash
        }

class Export(object):
    # pylint: disable=R0902
    def __init__(self, export_id, path, fsal, cluster_id, pseudo,
                 access_type='R', clients=None):
        self.export_id = export_id
        self.path = path
        self.fsal = fsal
        self.cluster_id = cluster_id
        self.pseudo = pseudo
        self.access_type = access_type
        self.squash = 'no_root_squash'
        self.attr_expiration_time = 0
        self.security_label = True
        self.protocols = [4]
        self.transports = ["TCP"]
        self.clients = clients

    def to_export_block(self):
        # pylint: disable=too-many-branches
        result = {
            'block_name': 'EXPORT',
            'export_id': self.export_id,
            'path': self.path,
            'pseudo': self.pseudo,
            'access_type': self.access_type,
            'squash': self.squash,
            'attr_expiration_time': self.attr_expiration_time,
            'security_label': self.security_label,
            'protocols': self.protocols,
            'transports': [self.transports],
        }
        result['_blocks_'] = [self.fsal.to_fsal_block()]
        result['_blocks_'].extend([client.to_client_block()
                                   for client in self.clients])
        return result

    @classmethod
    def from_dict(cls, export_id, ex_dict):
        return cls(export_id,
                   ex_dict['path'],
                   CephFSFSal.from_dict(ex_dict['fsal']),
                   ex_dict['cluster_id'],
                   ex_dict['pseudo'],
                   ex_dict['access_type'],
                   [Client.from_dict(client) for client in ex_dict['clients']])

class FSExport(object):
    def __init__(self, mgr, namespace=None):
        self.mgr = mgr
        self.rados_pool = 'nfs-ganesha'
        self.rados_namespace = namespace #TODO check if cluster exists
        self.export_conf_blocks = []
        self.exports = {}

    def check_fs(self, fs_name):
        fs_map = self.mgr.get('fs_map')
        return fs_name in [fs['mdsmap']['fs_name'] for fs in fs_map['filesystems']]

    def check_pseudo_path(self, pseudo_path):
        for ex in self.exports[self.rados_namespace]:
            if ex.pseudo == pseudo_path:
                return True
        return False

    def _create_user_key(self, entity):
        osd_cap = 'allow rw pool={} namespace={}, allow rw tag cephfs data=a'.format(
                self.rados_pool, self.rados_namespace)
        ret, out, err = self.mgr.mon_command({
            'prefix': 'auth get-or-create',
            'entity': 'client.{}'.format(entity),
            'caps' : ['mon', 'allow r', 'osd', osd_cap, 'mds', 'allow rw path=/'],
            'format': 'json',
            })

        if ret!= 0:
            return ret, err

        json_res = json.loads(out)
        log.info("Export user is {}".format(json_res[0]['entity']))

        return json_res[0]['entity'], json_res[0]['key']

    def format_path(self, path):
        if path is not None:
            path = path.strip()
            if len(path) > 1 and path[-1] == '/':
                path = path[:-1]
        return path

    def _gen_export_id(self):
        exports = sorted([ex.export_id for ex in self.exports[self.rados_namespace]])
        nid = 1
        for e_id in exports:
            if e_id == nid:
                nid += 1
            else:
                break
        return nid

    def _write_raw_config(self, conf_block, obj, append=False):
        raw_config = GaneshaConfParser.write_conf(conf_block)
        with self.mgr.rados.open_ioctx(self.rados_pool) as ioctx:
            if self.rados_namespace:
                ioctx.set_namespace(self.rados_namespace)
            if append:
                ioctx.append(obj, raw_config.encode('utf-8'))
            else:
                ioctx.write_full(obj, raw_config.encode('utf-8'))
            log.debug(
                    "write configuration into rados object %s/%s/%s:\n%s",
                    self.rados_pool, self.rados_namespace, obj, raw_config)

    def _update_common_conf(self, ex_id):
        common_conf = 'conf-nfs'
        conf_blocks = {
                'block_name': '%url',
                'value': self.make_rados_url(
                'export-{}'.format(ex_id))
                }
        self._write_raw_config(conf_blocks, common_conf, True)

    def _save_export(self, export):
        self.exports[self.rados_namespace].append(export)
        conf_block = export.to_export_block()
        self._write_raw_config(conf_block, "export-{}".format(export.export_id))
        self._update_common_conf(export.export_id)

    def create_export(self, export_type, fs_name, pseudo_path, read_only, path, cluster_id):
        if export_type != 'cephfs':
            return -errno.EINVAL,"", f"Invalid export type: {export_type}"
        #TODO Check if valid cluster
        if cluster_id not in self.exports:
            self.exports[cluster_id] = []

        self.rados_namespace = cluster_id
        if not self.check_fs(fs_name) or self.check_pseudo_path(pseudo_path):
            return -errno.EINVAL,"", "Invalid CephFS name or export already exists"

        user_id, key = self._create_user_key(cluster_id)
        if isinstance(user_id, int):
            return user_id, "", key
        access_type = "RW"
        if read_only:
            access_type = "R"

        ex_dict = {
            'path': self.format_path(path),
            'pseudo': self.format_path(pseudo_path),
            'cluster_id': cluster_id,
            'access_type': access_type,
            'fsal': {"name": "CEPH", "user_id":cluster_id, "fs_name": fs_name, "sec_label_xattr": ""},
            'clients': []
            }

        ex_id = self._gen_export_id()
        export = Export.from_dict(ex_id, ex_dict)
        export.fsal.cephx_key = key
        self._save_export(export)

        result = {
            "bind": pseudo_path,
            "fs": fs_name,
            "path": path,
            "cluster": cluster_id,
            "mode": access_type,
            }

        return (0, json.dumps(result, indent=4), '')

    def delete_export(self, ex_id):
        raise NotImplementedError()

    def make_rados_url(self, obj):
        if self.rados_namespace:
            return "rados://{}/{}/{}".format(self.rados_pool, self.rados_namespace, obj)
        return "rados://{}/{}".format(self.rados_pool, obj)

class NFSCluster:
    def __init__(self, mgr, cluster_id):
        self.cluster_id = "ganesha-%s" % cluster_id
        self.pool_name = 'nfs-ganesha'
        self.pool_ns = cluster_id
        self.mgr = mgr

    def create_empty_rados_obj(self):
        common_conf = 'conf-nfs'
        result = ''
        with self.mgr.rados.open_ioctx(self.pool_name) as ioctx:
            if self.pool_ns:
                ioctx.set_namespace(self.pool_ns)
            ioctx.write_full(common_conf, result.encode('utf-8'))
            log.debug(
                    "write configuration into rados object %s/%s/nfs-conf\n",
                    self.pool_name, self.pool_ns)

    def create_nfs_cluster(self, export_type, size):
        if export_type != 'cephfs':
            return -errno.EINVAL,"", f"Invalid export type: {export_type}"

        pool_list = [p['pool_name'] for p in self.mgr.get_osdmap().dump().get('pools', [])]
        client = 'client.%s' % self.cluster_id

        if self.pool_name not in pool_list:
            r, out, err = create_pool(self.mgr, self.pool_name)
            if r != 0:
                return r, out, err
            log.info("{}".format(out))

            command = {'prefix': 'osd pool application enable', 'pool': self.pool_name, 'app': 'nfs'}
            r, out, err = self.mgr.mon_command(command)

            if r != 0:
                return r, out, err

        self.create_empty_rados_obj()
        #TODO Check if cluster exists
        #TODO Call Orchestrator to deploy cluster

        return 0, "", "NFS Cluster Created Successfully"

    def update_nfs_cluster(self, size):
        raise NotImplementedError()

    def delete_nfs_cluster(self):
        raise NotImplementedError()
