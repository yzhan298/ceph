import fnmatch
import re
from collections import namedtuple
from functools import wraps
from typing import Optional, Dict, Any, List, Union

import six


class ServiceSpecValidationError(Exception):
    """
    Defining an exception here is a bit problematic, cause you cannot properly catch it,
    if it was raised in a different mgr module.
    """

    def __init__(self, msg):
        super(ServiceSpecValidationError, self).__init__(msg)


def assert_valid_host(name):
    p = re.compile('^[a-zA-Z0-9-]+$')
    try:
        assert len(name) <= 250, 'name is too long (max 250 chars)'
        for part in name.split('.'):
            assert len(part) > 0, '.-delimited name component must not be empty'
            assert len(part) <= 63, '.-delimited name component must not be more than 63 chars'
            assert p.match(part), 'name component must include only a-z, 0-9, and -'
    except AssertionError as e:
        raise ServiceSpecValidationError(e)


def handle_type_error(method):
    @wraps(method)
    def inner(cls, *args, **kwargs):
        try:
            return method(cls, *args, **kwargs)
        except (TypeError, AttributeError) as e:
            error_msg = '{}: {}'.format(cls.__name__, e)
        raise ServiceSpecValidationError(error_msg)
    return inner


class HostPlacementSpec(namedtuple('HostPlacementSpec', ['hostname', 'network', 'name'])):
    def __str__(self):
        res = ''
        res += self.hostname
        if self.network:
            res += ':' + self.network
        if self.name:
            res += '=' + self.name
        return res

    @classmethod
    @handle_type_error
    def from_json(cls, data):
        return cls(**data)

    def to_json(self):
        return {
            'hostname': self.hostname,
            'network': self.network,
            'name': self.name
        }

    @classmethod
    def parse(cls, host, require_network=True):
        # type: (str, bool) -> HostPlacementSpec
        """
        Split host into host, network, and (optional) daemon name parts.  The network
        part can be an IP, CIDR, or ceph addrvec like '[v2:1.2.3.4:3300,v1:1.2.3.4:6789]'.
        e.g.,
          "myhost"
          "myhost=name"
          "myhost:1.2.3.4"
          "myhost:1.2.3.4=name"
          "myhost:1.2.3.0/24"
          "myhost:1.2.3.0/24=name"
          "myhost:[v2:1.2.3.4:3000]=name"
          "myhost:[v2:1.2.3.4:3000,v1:1.2.3.4:6789]=name"
        """
        # Matches from start to : or = or until end of string
        host_re = r'^(.*?)(:|=|$)'
        # Matches from : to = or until end of string
        ip_re = r':(.*?)(=|$)'
        # Matches from = to end of string
        name_re = r'=(.*?)$'

        # assign defaults
        host_spec = cls('', '', '')

        match_host = re.search(host_re, host)
        if match_host:
            host_spec = host_spec._replace(hostname=match_host.group(1))

        name_match = re.search(name_re, host)
        if name_match:
            host_spec = host_spec._replace(name=name_match.group(1))

        ip_match = re.search(ip_re, host)
        if ip_match:
            host_spec = host_spec._replace(network=ip_match.group(1))

        if not require_network:
            return host_spec

        from ipaddress import ip_network, ip_address
        networks = list()  # type: List[str]
        network = host_spec.network
        # in case we have [v2:1.2.3.4:3000,v1:1.2.3.4:6478]
        if ',' in network:
            networks = [x for x in network.split(',')]
        else:
            if network != '':
                networks.append(network)

        for network in networks:
            # only if we have versioned network configs
            if network.startswith('v') or network.startswith('[v'):
                network = network.split(':')[1]
            try:
                # if subnets are defined, also verify the validity
                if '/' in network:
                    ip_network(six.text_type(network))
                else:
                    ip_address(six.text_type(network))
            except ValueError as e:
                # logging?
                raise e
        host_spec.validate()
        return host_spec

    def validate(self):
        assert_valid_host(self.hostname)


class PlacementSpec(object):
    """
    For APIs that need to specify a host subset
    """

    def __init__(self,
                 label=None,  # type: Optional[str]
                 hosts=None,  # type: Union[List[str],List[HostPlacementSpec]]
                 count=None,  # type: Optional[int]
                 host_pattern=None  # type: Optional[str]
                 ):
        # type: (...) -> None
        self.label = label
        self.hosts = []  # type: List[HostPlacementSpec]

        if hosts:
            if all([isinstance(host, HostPlacementSpec) for host in hosts]):
                self.hosts = hosts  # type: ignore
            else:
                self.hosts = [HostPlacementSpec.parse(x, require_network=False)  # type: ignore
                              for x in hosts if x]

        self.count = count  # type: Optional[int]

        #: fnmatch patterns to select hosts. Can also be a single host.
        self.host_pattern = host_pattern  # type: Optional[str]

        self.validate()

    def is_empty(self):
        return self.label is None and \
            not self.hosts and \
            not self.host_pattern and \
            self.count is None

    def set_hosts(self, hosts):
        # To backpopulate the .hosts attribute when using labels or count
        # in the orchestrator backend.
        self.hosts = hosts

    def pattern_matches_hosts(self, all_hosts):
        # type: (List[str]) -> List[str]
        if not self.host_pattern:
            return []
        return fnmatch.filter(all_hosts, self.host_pattern)

    def pretty_str(self):
        kv = []
        if self.count:
            kv.append('count:%d' % self.count)
        if self.label:
            kv.append('label:%s' % self.label)
        if self.hosts:
            kv.append('%s' % ','.join([str(h) for h in self.hosts]))
        if self.host_pattern:
            kv.append(self.host_pattern)
        return ' '.join(kv)

    def __repr__(self):
        kv = []
        if self.count:
            kv.append('count=%d' % self.count)
        if self.label:
            kv.append('label=%s' % repr(self.label))
        if self.hosts:
            kv.append('hosts={!r}'.format(self.hosts))
        if self.host_pattern:
            kv.append('host_pattern={!r}'.format(self.host_pattern))
        return "PlacementSpec(%s)" % ', '.join(kv)

    @classmethod
    @handle_type_error
    def from_json(cls, data):
        c = data.copy()
        hosts = c.get('hosts', [])
        if hosts:
            c['hosts'] = []
            for host in hosts:
                c['hosts'].append(HostPlacementSpec.parse(host) if
                                  isinstance(host, str) else
                                  HostPlacementSpec.from_json(host))
        _cls = cls(**c)
        _cls.validate()
        return _cls

    def to_json(self):
        r = {}
        if self.label:
            r['label'] = self.label
        if self.hosts:
            r['hosts'] = [host.to_json() for host in self.hosts]
        if self.count:
            r['count'] = self.count
        if self.host_pattern:
            r['host_pattern'] = self.host_pattern
        return r

    def validate(self):
        if self.hosts and self.label:
            # TODO: a less generic Exception
            raise ServiceSpecValidationError('Host and label are mutually exclusive')
        if self.count is not None and self.count <= 0:
            raise ServiceSpecValidationError("num/count must be > 1")
        if self.host_pattern and self.hosts:
            raise ServiceSpecValidationError('cannot combine host patterns and hosts')
        for h in self.hosts:
            h.validate()

    @classmethod
    def from_string(cls, arg):
        # type: (Optional[str]) -> PlacementSpec
        """
        A single integer is parsed as a count:
        >>> PlacementSpec.from_string('3')
        PlacementSpec(count=3)

        A list of names is parsed as host specifications:
        >>> PlacementSpec.from_string('host1 host2')
        PlacementSpec(hosts=[HostPlacementSpec(hostname='host1', network='', name=''), HostPlacemen\
tSpec(hostname='host2', network='', name='')])

        You can also prefix the hosts with a count as follows:
        >>> PlacementSpec.from_string('2 host1 host2')
        PlacementSpec(count=2, hosts=[HostPlacementSpec(hostname='host1', network='', name=''), Hos\
tPlacementSpec(hostname='host2', network='', name='')])

        You can spefify labels using `label:<label>`
        >>> PlacementSpec.from_string('label:mon')
        PlacementSpec(label='mon')

        Labels als support a count:
        >>> PlacementSpec.from_string('3 label:mon')
        PlacementSpec(count=3, label='mon')

        fnmatch is also supported:
        >>> PlacementSpec.from_string('data[1-3]')
        PlacementSpec(host_pattern='data[1-3]')

        >>> PlacementSpec.from_string(None)
        PlacementSpec()
        """
        if arg is None or not arg:
            strings = []
        elif isinstance(arg, str):
            if ' ' in arg:
                strings = arg.split(' ')
            elif ';' in arg:
                strings = arg.split(';')
            elif ',' in arg and '[' not in arg:
                # FIXME: this isn't quite right.  we want to avoid breaking
                # a list of mons with addrvecs... so we're basically allowing
                # , most of the time, except when addrvecs are used.  maybe
                # ok?
                strings = arg.split(',')
            else:
                strings = [arg]
        else:
            raise ServiceSpecValidationError('invalid placement %s' % arg)

        count = None
        if strings:
            try:
                count = int(strings[0])
                strings = strings[1:]
            except ValueError:
                pass
        for s in strings:
            if s.startswith('count:'):
                try:
                    count = int(s[6:])
                    strings.remove(s)
                    break
                except ValueError:
                    pass

        advanced_hostspecs = [h for h in strings if
                              (':' in h or '=' in h or not any(c in '[]?*:=' for c in h)) and
                              'label:' not in h]
        for a_h in advanced_hostspecs:
            strings.remove(a_h)

        labels = [x for x in strings if 'label:' in x]
        if len(labels) > 1:
            raise ServiceSpecValidationError('more than one label provided: {}'.format(labels))
        for l in labels:
            strings.remove(l)
        label = labels[0][6:] if labels else None

        host_patterns = strings
        if len(host_patterns) > 1:
            raise ServiceSpecValidationError(
                'more than one host pattern provided: {}'.format(host_patterns))

        ps = PlacementSpec(count=count,
                           hosts=advanced_hostspecs,
                           label=label,
                           host_pattern=host_patterns[0] if host_patterns else None)
        return ps


class ServiceSpec(object):
    """
    Details of service creation.

    Request to the orchestrator for a cluster of daemons
    such as MDS, RGW, iscsi gateway, MONs, MGRs, Prometheus

    This structure is supposed to be enough information to
    start the services.

    """
    KNOWN_SERVICE_TYPES = 'alertmanager crash grafana iscsi mds mgr mon nfs ' \
                          'node-exporter osd prometheus rbd-mirror rgw'.split()

    @classmethod
    def _cls(cls, service_type):
        from ceph.deployment.drive_group import DriveGroupSpec

        ret = {
            'rgw': RGWSpec,
            'nfs': NFSServiceSpec,
            'osd': DriveGroupSpec,
            'iscsi': IscsiServiceSpec,
        }.get(service_type, cls)
        if ret == ServiceSpec and not service_type:
            raise ServiceSpecValidationError('Spec needs a "service_type" key.')
        return ret

    def __new__(cls, *args, **kwargs):
        """
        Some Python foo to make sure, we don't have an object
        like `ServiceSpec('rgw')` of type `ServiceSpec`. Now we have:

        >>> type(ServiceSpec('rgw')) == type(RGWSpec('rgw'))
        True

        """
        if cls != ServiceSpec:
            return object.__new__(cls)
        service_type = kwargs.get('service_type', args[0] if args else None)
        sub_cls = cls._cls(service_type)
        return object.__new__(sub_cls)

    def __init__(self,
                 service_type,     # type: str
                 service_id=None,  # type: Optional[str]
                 placement=None,   # type: Optional[PlacementSpec]
                 count=None,       # type: Optional[int]
                 unmanaged=False,  # type: bool
                 ):
        self.placement = PlacementSpec() if placement is None else placement  # type: PlacementSpec

        assert service_type in ServiceSpec.KNOWN_SERVICE_TYPES, service_type
        self.service_type = service_type
        self.service_id = service_id
        self.unmanaged = unmanaged

    @classmethod
    @handle_type_error
    def from_json(cls, json_spec):
        # type: (dict) -> Any
        # Python 3:
        # >>> ServiceSpecs = TypeVar('Base', bound=ServiceSpec)
        # then, the real type is: (dict) -> ServiceSpecs
        """
        Initialize 'ServiceSpec' object data from a json structure
        :param json_spec: A valid dict with ServiceSpec
        """

        c = json_spec.copy()

        # kludge to make `from_json` compatible to `Orchestrator.describe_service`
        # Open question: Remove `service_id` form to_json?
        if c.get('service_name', ''):
            service_type_id = c['service_name'].split('.', 1)

            if not c.get('service_type', ''):
                c['service_type'] = service_type_id[0]
            if not c.get('service_id', '') and len(service_type_id) > 1:
                c['service_id'] = service_type_id[1]
            del c['service_name']

        service_type = c.get('service_type', '')
        _cls = cls._cls(service_type)

        if 'status' in c:
            del c['status']  # kludge to make us compatible to `ServiceDescription.to_json()`

        return _cls._from_json_impl(c)  # type: ignore

    @classmethod
    def _from_json_impl(cls, json_spec):
        args = {}  # type: Dict[str, Dict[Any, Any]]
        for k, v in json_spec.items():
            if k == 'placement':
                v = PlacementSpec.from_json(v)
            if k == 'spec':
                args.update(v)
                continue
            args.update({k: v})
        _cls = cls(**args)
        _cls.validate()
        return _cls

    def service_name(self):
        n = self.service_type
        if self.service_id:
            n += '.' + self.service_id
        return n

    def to_json(self):
        # type: () -> Dict[str, Any]
        c = {}
        for key, val in self.__dict__.items():
            if hasattr(val, 'to_json'):
                val = val.to_json()
            if val:
                c[key] = val

        c['service_name'] = self.service_name()
        return c

    def validate(self):
        if not self.service_type:
            raise ServiceSpecValidationError('Cannot add Service: type required')

        if self.placement is not None:
            self.placement.validate()

    def __repr__(self):
        return "{}({!r})".format(self.__class__.__name__, self.__dict__)

    def one_line_str(self):
        return '<{} for service_name={}>'.format(self.__class__.__name__, self.service_name())


def servicespec_validate_add(self: ServiceSpec):
    # This must not be a method of ServiceSpec, otherwise you'll hunt
    # sub-interpreter affinity bugs.
    ServiceSpec.validate(self)
    if self.service_type in ['mds', 'rgw', 'nfs', 'iscsi'] and not self.service_id:
        raise ServiceSpecValidationError('Cannot add Service: id required')


class NFSServiceSpec(ServiceSpec):
    def __init__(self, service_id=None, pool=None, namespace=None, placement=None,
                 service_type='nfs', unmanaged=False):
        assert service_type == 'nfs'
        super(NFSServiceSpec, self).__init__(
            'nfs', service_id=service_id,
            placement=placement, unmanaged=unmanaged)

        #: RADOS pool where NFS client recovery data is stored.
        self.pool = pool

        #: RADOS namespace where NFS client recovery data is stored in the pool.
        self.namespace = namespace

    def validate_add(self):
        servicespec_validate_add(self)

        if not self.pool:
            raise ServiceSpecValidationError('Cannot add NFS: No Pool specified')

    def rados_config_name(self):
        # type: () -> str
        return 'conf-' + self.service_name()

    def rados_config_location(self):
        # type: () -> str
        url = 'rados://' + self.pool + '/'
        if self.namespace:
            url += self.namespace + '/'
        url += self.rados_config_name()
        return url


class RGWSpec(ServiceSpec):
    """
    Settings to configure a (multisite) Ceph RGW

    """
    def __init__(self,
                 service_type='rgw',
                 service_id=None,  # type: Optional[str]
                 placement=None,
                 rgw_realm=None,  # type: Optional[str]
                 rgw_zone=None,  # type: Optional[str]
                 subcluster=None,  # type: Optional[str]
                 rgw_frontend_port=None,  # type: Optional[int]
                 rgw_frontend_ssl_certificate=None,  # type Optional[List[str]]
                 rgw_frontend_ssl_key=None,  # type: Optional[List[str]]
                 unmanaged=False,  # type: bool
                 ssl=False,   # type: bool
                 ):
        assert service_type == 'rgw', service_type
        if service_id:
            a = service_id.split('.', 2)
            rgw_realm = a[0]
            rgw_zone = a[1]
            if len(a) > 2:
                subcluster = a[2]
        else:
            if subcluster:
                service_id = '%s.%s.%s' % (rgw_realm, rgw_zone, subcluster)
            else:
                service_id = '%s.%s' % (rgw_realm, rgw_zone)
        super(RGWSpec, self).__init__(
            'rgw', service_id=service_id,
            placement=placement, unmanaged=unmanaged)

        self.rgw_realm = rgw_realm
        self.rgw_zone = rgw_zone
        self.subcluster = subcluster
        self.rgw_frontend_port = rgw_frontend_port
        self.rgw_frontend_ssl_certificate = rgw_frontend_ssl_certificate
        self.rgw_frontend_ssl_key = rgw_frontend_ssl_key
        self.ssl = ssl

    def get_port(self):
        if self.rgw_frontend_port:
            return self.rgw_frontend_port
        if self.ssl:
            return 443
        else:
            return 80

    def rgw_frontends_config_value(self):
        ports = []
        if self.ssl:
            ports.append(f"ssl_port={self.get_port()}")
            ports.append(f"ssl_certificate=config://rgw/cert/{self.rgw_realm}/{self.rgw_zone}.crt")
            ports.append(f"ssl_key=config://rgw/cert/{self.rgw_realm}/{self.rgw_zone}.key")
        else:
            ports.append(f"port={self.get_port()}")
        return f'beast {" ".join(ports)}'


class IscsiServiceSpec(ServiceSpec):
    def __init__(self, service_id, pool=None,
                 placement=None,
                 trusted_ip_list=None,
                 api_port=None,
                 api_user=None,
                 api_password=None,
                 api_secure=None,
                 ssl_cert=None,
                 ssl_key=None,
                 service_type='iscsi',
                 unmanaged=False):
        assert service_type == 'iscsi'
        super(IscsiServiceSpec, self).__init__('iscsi', service_id=service_id,
                                               placement=placement, unmanaged=unmanaged)

        #: RADOS pool where ceph-iscsi config data is stored.
        self.pool = pool
        self.trusted_ip_list = trusted_ip_list
        self.api_port = api_port
        self.api_user = api_user
        self.api_password = api_password
        self.api_secure = api_secure
        self.ssl_cert = ssl_cert
        self.ssl_key = ssl_key

        if not self.api_secure and self.ssl_cert and self.ssl_key:
            self.api_secure = True

    def validate_add(self):
        servicespec_validate_add(self)

        if not self.pool:
            raise ServiceSpecValidationError(
                'Cannot add ISCSI: No Pool specified')
