#!/bin/sh

SEARCH_LIST=$(jetpack config dns.search_list)

if [ -n "$SEARCH_LIST" ] ; then
	restorecon /etc/sysconfig/network-scripts/ifcfg-*
	nmcli c m "System eth0" ipv4.dns-search "$SEARCH_LIST"
	# prevent cloud-init from resetting the file on reboot
	chattr +i /etc/sysconfig/network-scripts/ifcfg-eth0
	nmcli c u "System eth0"
fi
