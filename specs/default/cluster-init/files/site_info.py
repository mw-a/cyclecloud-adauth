#!/usr/bin/python3

"""Lookup information about Active Directory Sites.

https://msdn.microsoft.com/en-us/library/cc223811.aspx
"""

__docformat__ = "restructuredtext en"

import asyncio
import itertools
import sys
import logging
import argparse
import struct
import collections
import socket
import ldap
import ldap.filter
import dns.name
import dns.resolver
import dns.rdtypes.IN.SRV

logger = logging.getLogger(__file__)
logger.addHandler(logging.StreamHandler())
logger.setLevel(logging.WARNING)

# query flags
NETLOGON_NT_VERSION_5 = 0x00000002
NETLOGON_NT_VERSION_5EX = 0x00000004

# response types
LOGON_SAM_LOGON_RESPONSE_EX = 23

# response flags
DS_LDAP_FLAG = 0x00000008
DS_DS_FLAG = 0x00000010
DS_KDC_FLAG = 0x00000020
DS_CLOSEST_FLAG = 0x00000080
DS_WRITABLE_FLAG = 0x00000100

DCInfo = collections.namedtuple(
    'DCInfo',
    ['flags', 'dnsforestname', 'dnsdomainname', 'dnshostname',
     'netbiosdomainname', 'netbioscomputername', 'dcsitename',
     'clientsitename'])

def lookup_ldap_servers(domain, site=None):
    """ Lookup LDAP Servers in a domain using SRV DNS records

    :param domain: DNS domain name to look for SRV records in
    :param site: (optional) Active Directory Site name to prepend to domain

    :return: List of named collections SRV containing target, port, priority
             and weight of response.
    """
    SRV = collections.namedtuple('SRV', ['target', 'port', 'priority', 'weight'])
    info = []

    if site is not None:
        domain = "%s._sites.dc._msdcs.%s" % (site, domain)

    resolver = dns.resolver.get_default_resolver()

    logger.debug("Querying DNS for _ldap._tcp SRV records in %s", domain)
    try:
        answers = resolver.query("_ldap._tcp.%s" % domain, "SRV", "IN")
    except dns.exception.Timeout as timeout:
        logger.warning("DNS error: %s", timeout)
        return []

    for answer in answers:
        if isinstance(answer, dns.rdtypes.IN.SRV.SRV):
            info.append(SRV(
                answer.target, answer.port,
                answer.priority, answer.weight))

    return info

def sort_srv(info):
    """ Sort SRV records by priority and weight. The implemented algorithm is
    not really the weighing algorithm according to RFC 2782 but close enough
    for us.

    :param info: List of objects to sort by their properties priority and
                 weight.

    :return: Sorted list of input elements.
    """
    return sorted(info, key=lambda i: (i.priority, -i.weight, i.target))

def decompress_name(msg, pos):
    """ Get a name from an Active Directory Domain Controller Netlogon
    response. Apparently, the netlogon response is basically DNS response with
    strings compressed in a compatible fashion - taken from adcli which uses
    libresolve's dn_expand() for decoding.

    :param msg: The whole message in binary form as received from the Domain
                Controller.
    :type msg: str (Python 2) or bytes (Python 3)
    :param pos: Denoting the offset to the start of the message at which
                to start extracting the name.
    :type pos: int

    :return: Tuple of extracted name and new position where extraction of next
             name can continue (i.e. old pos plus number of message bytes
             consumed by the current extraction).
    """
    (name, consumed) = dns.name.from_wire(msg, pos)

    # empty absolute name (the one component being the root) would yield '.'
    if name.is_absolute() and len(name) == 1:
        name = None
    else:
        name = name.to_text(omit_final_dot=True)

    return (name, pos + consumed)

def dispatch_ping(server, domain=None, client=None, client_fqdn=None, connection=None):
    """ Send ping request to an Active Directory Domain Controller via LDAP
    protocol, requesting an extended Netlogon response.

    :param server: name of server to contact
    :type server: string
    :param domain: (optional) name of Active Directory DNS domain to ask for
                   information about in the ping request. Defaults to domain of
                   the responding server.
    :type domain: string
    :param client: (optional) NETBIOS name of client to submit to DC
    :type client: string
    :param client_fqdn: (optional) fully qualified domain name of client to
                        submit to DC
    :type client_fqdn: string

    :return: LDAP connection object via which a search request has been sent.
    """
    logger.debug("Dispatching ping to %s", server)

    ldap.set_option(ldap.OPT_PROTOCOL_VERSION, ldap.VERSION3)
    ldap.set_option(ldap.OPT_REFERRALS, False)
    ldap.set_option(ldap.OPT_TIMEOUT, 1)
    ldap.set_option(ldap.OPT_NETWORK_TIMEOUT, 1)
    connection = ldap.initialize("ldap://%s" % server, fileno=connection)

    domain_assertion = ""
    if domain is not None:
        domain_assertion = "(dnsdomain=%s)" % (
            ldap.filter.escape_filter_chars(domain))

    client_assertion = ""
    if client is not None:
        client_assertion = "(host=%s)" % (
            ldap.filter.escape_filter_chars(client))

    client_fqdn_assertion = ""
    if client_fqdn is not None:
        client_fqdn_assertion = "(dnshostname=%s)" % (
            ldap.filter.escape_filter_chars(client_fqdn))

    # request LOGON_SAM_LOGON_RESPONSE_EX from DC
    ntver = NETLOGON_NT_VERSION_5 | NETLOGON_NT_VERSION_5EX

    # encode as little-endian DWORD and escape resulting binary data for use in
    # search filter: 0x6 -> \\06\\00\\00\\00
    ntver_quads = []
    for byte in struct.pack("<L", ntver):
        # python2 struct returns str() where python3 returns bytes(). Iterating
        # str() gives str()s of length 1 where iterating bytes() gives int()s
        # already. Therefore we convert str() to int() using ord() on python2.
        if isinstance(byte, str):
            byte = ord(byte)

        ntver_quads.append("\\%02x" % byte)

    ntver_assertion = "".join(ntver_quads)

    search_filter = "(&(ntver=%s)%s%s%s)" % (
        ntver_assertion, domain_assertion, client_assertion,
        client_fqdn_assertion)
    logger.debug("LDAP search filter: %s", search_filter)

    try:
        connection.search_ext("", ldap.SCOPE_BASE, search_filter, ["netlogon"], timeout=1)
    except ldap.SERVER_DOWN as server_down:
        logger.warning("%s: %s" % (server, server_down))
        return None

    return connection

def collect_ping_response(search):
    """ Collect and parse a ping request response from an LDAP connection object.
    https://msdn.microsoft.com/en-us/library/cc223807.aspx

    :param search: LDAP connection object from which to collect the search
                   request response.

    :return: Named collection DCInfo containing information parsed from the
             ping response in properties flags, dnsforestname, dnsdomainname,
             dnshostname, netbiosdomainname, netbioscomputername, dcsitename,
             clientsitename or None in case of error.
    """
    if search is None:
        return None

    try:
        res = search.result(timeout=1)
    except ldap.TIMEOUT:
        logger.warning("Search at timed out")
        return None

    for result in res[1]:
        attrs = result[1]
        netlogonvals = attrs.get('netlogon')
        if isinstance(netlogonvals, (tuple, list)):
            netlogonvals = (netlogonvals)

        logger.debug("Got answer")
        for netlogonval in netlogonvals:
            opcode = struct.unpack("<H", netlogonval[0:2])[0]
            if opcode != LOGON_SAM_LOGON_RESPONSE_EX:
                logger.error("Invalid ping response")

            # nl[2:3] - ignore Sbz
            flags = struct.unpack("<L", netlogonval[4:8])[0]
            # nl[8:23] - ignore DomainGuid

            pos = 24
            (dnsforestname, pos) = decompress_name(netlogonval, pos)
            (dnsdomainname, pos) = decompress_name(netlogonval, pos)
            (dnshostname, pos) = decompress_name(netlogonval, pos)
            (netbiosdomainname, pos) = decompress_name(netlogonval, pos)
            (netbioscomputername, pos) = decompress_name(netlogonval, pos)
            (_, pos) = decompress_name(netlogonval, pos)
            (dcsitename, pos) = decompress_name(netlogonval, pos)
            (clientsitename, pos) = decompress_name(netlogonval, pos)

            return DCInfo(
                flags, dnsforestname, dnsdomainname, dnshostname,
                netbiosdomainname, netbioscomputername, dcsitename,
                clientsitename)

    return None

def batched(iterable, n):
     if n < 1:
          raise ValueError('n must be at least one')
     it = iter(iterable)
     batch = tuple(itertools.islice(it, n))
     while batch:
         yield batch
         batch = tuple(itertools.islice(it, n))

# dispatch pings to all known servers
async def ping_all_dcs(domain, site=None, client=None, client_fqdn=None, eager=False):
    """ Ping all Active Directory Domain Controllers discoverable via SRV
    records in a domain and collect their Netlogon information.

    :param domain: Active Directory DNS domain name to query.
    :type domain: string
    :param site: (optional) name of site to query
    :type site: string
    :param client: (optional) NETBIOS name of client to submit to DC
    :type client: string
    :param client_fqdn: (optional) fully qualified domain name of client to
                        submit to DC
    :type client_fqdn: string
    :param eager: (optional) stop as soon as a single result is received
    :type eager: bool

    :return: list of DCInfo named collections containing information extracted
             from the ping responses.
    """
    dcinfos = []
    srvs = sort_srv(lookup_ldap_servers(domain, site))
    for connection_group in batched(srvs, 10):
        connections = []
        sockets = {}
        for srv in connection_group:
            server = srv.target.to_text()
            logger.debug("Connecting to %s", server)
            sock = socket.socket()
            sock.setblocking(False)
            connection = asyncio.get_event_loop().sock_connect(sock, (server, 389))
            sockets[connection] = sock
            connections.append(connection)

        established_connections, pending_connections = await asyncio.wait(
            connections, timeout=1, return_when=asyncio.FIRST_COMPLETED)
        for pending_connection in pending_connections:
            logger.debug("Cancelling connection to %s", server)
            pending_connection.cancel()

        if not established_connections:
            continue

        searches = []
        for conn in established_connections:
            searches.append((server, dispatch_ping(
                server, domain, client, client_fqdn, sockets[conn._coro])))

        # we preserve the order in which we sent the requests because it is
        # influenced by priorities and weights from DNS SRV records which we want to
        # keep
        for (server, search) in searches:
            logger.debug("Collecting ping response from %s", server)
            dcinfo = collect_ping_response(search)
            if dcinfo is None:
                logger.warning("Error collecting ping response from %s", server)
                continue

            dcinfos.append(dcinfo)
            if eager:
                return dcinfos

    return dcinfos

async def main():
    """ The main program. """
    parser = argparse.ArgumentParser(
        description='Lookup information about Active Directory Sites')
    parser.add_argument(
        '-D', '--domain',
        help='name of AD/DNS domain to query')
    parser.add_argument(
        '-S', '--server',
        help='name of DC to contact directly domain to query')
    parser.add_argument(
        '-s', '--site',
        help='name of site to query')
    parser.add_argument(
        '-C', '--client',
        nargs='?',
        const=True,
        help='send NETBIOS name of client to aid DC in determining site')
    parser.add_argument(
        '-F', '--client-fqdn',
        nargs='?',
        const=True,
        help='send FQDN of client to aid DC in determining site')
    parser.add_argument(
        '--discover-site', action='store_true',
        help='discover only the site name')
    parser.add_argument(
        '--eager',
        nargs='?',
        const=True,
        help='stop as soon as a single result is available')
    parser.add_argument(
        '--yaml',
        nargs='?',
        const=True,
        help='output yaml structure suited for use as facter fact')
    parser.add_argument(
        '-v', '--verbose', action='store_true',
        help='log info messages')
    parser.add_argument(
        '-d', '--debug', action='store_true',
        help='log debug messages')

    args = parser.parse_args()

    if args.verbose:
        logger.setLevel(logging.INFO)
    if args.debug:
        logger.setLevel(logging.DEBUG)

    domain = args.domain
    site = args.site
    server = args.server

    client = args.client
    if client is True:
        client = socket.gethostname()

    client_fqdn = args.client_fqdn
    if client_fqdn is True:
        client_fqdn = socket.getfqdn()

    discover_site = args.discover_site
    if discover_site is True and site is not None:
        logger.error("Do not specify site if it is to be discovered")
        sys.exit(1)

    yaml = args.yaml
    if yaml is not None and discover_site is True:
        discover_site = False

    eager = args.eager

    global_dcs = None
    if server is not None:
        dcinfo = collect_ping_response(dispatch_ping(
            server, domain=domain, client=client, client_fqdn=client_fqdn))
        if dcinfo is None:
            logger.error("Ping of DC %s failed", server)
            sys.exit(1)

        if site is None:
            site = dcinfo.clientsitename
            logger.info("Discovered site to be %s", site)

        # discover domain from DC response if not given on command line
        if domain is None:
            domain = dcinfo.dnsdomainname
            logger.info("Discovered domain to be %s", domain)
    else:
        if domain is None:
            logger.error('Please provide either a domain or dc name')
            sys.exit(1)

        global_dcs = await ping_all_dcs(
            domain, client=client, client_fqdn=client_fqdn, eager=eager)
        if len(global_dcs) == 0:
            logger.error("No working global DCs could be found")
            sys.exit(1)

        if site is None:
            site = global_dcs[0].clientsitename
            logger.info("Discovered site to be %s", site)

    if discover_site is True:
        print(site)
        sys.exit(0)

    site_dcs = await ping_all_dcs(
        domain, site=site, client=client, client_fqdn=client_fqdn, eager=eager)
    if len(site_dcs) == 0:
        logger.warning("No working site DCs could be found")

    # do not use yaml module to avoid dependency
    if yaml is not None:
        # yaml option may specify name of a wrapper element
        if yaml is not True:
            print("{ %s:" % yaml)

        print("{ site: '%s'," % site)
        print("  site_dcs: [")
        for site_dc in site_dcs:
            print("    '%s'," % site_dc.dnshostname)
        print("  ],")

        if global_dcs is not None:
            print("  global_dcs: [")
            for global_dc in global_dcs:
                print("    '%s'," % global_dc.dnshostname)
            print("  ],")

        print("}")
        if yaml is not True:
            print("}")
    else:
        for site_dc in site_dcs:
            print(site_dc.dnshostname)

if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main())
    loop.close()
