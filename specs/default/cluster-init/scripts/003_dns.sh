#!/bin/sh

DNS_SERVERS=$(jetpack config dns.servers)
SEARCH_LIST=$(jetpack config dns.search_list)

if [ -n "$SEARCH_LIST" -o -n "$DNS_SERVERS" ] ; then
	restorecon /etc/sysconfig/network-scripts/ifcfg-*
	nmcli c m "System eth0" ipv4.ignore-auto-dns yes ipv4.dns-search "$SEARCH_LIST" ipv4.dns "$DNS_SERVERS"
	nmcli c u "System eth0"
fi
