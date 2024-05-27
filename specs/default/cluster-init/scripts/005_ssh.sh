#!/bin/sh

sed -i -e "s,#HostbasedAuthentication no,HostbasedAuthentication yes," \
	-e "s/PasswordAuthentication no/PasswordAuthentication yes/g" \
	/etc/ssh/sshd_config

systemctl restart sshd

rm -f /etc/hosts.equiv
echo "# managed by cyclecloud" > /etc/hosts.equiv

name_base=${HOSTNAME%s}
[ "$name_base" != "$HOSTNAME" ] || name_base=${HOSTNAME%login-*}
[ "$name_base" != "$HOSTNAME" ] || name_base=${HOSTNAME%hpc-*}
search_list=$(jetpack config dns.search_list)
partitions="hpc login"

hosts=""
for domain in ${search_list/,/ } ; do
	cc=vm-hpc2-cyclecloud-p.$domain
	echo $cc >> /etc/hosts.equiv
	scheduler=${name_base}scheduler.$domain
	echo $scheduler >> /etc/hosts.equiv

	hosts="$hosts,$cc,$scheduler"

	for partition in $partitions ; do
		for instance in `seq 1 50` ; do
			node=${name_base}$partition-$instance.$domain
			echo $node >> /etc/hosts.equiv
			hosts="$hosts,$node"
		done
	done
done

rm -f /etc/ssh/ssh_known_hosts
echo "# managed by cyclecloud" > /etc/ssh/ssh_known_hosts

hosts=${hosts#,}
for keyalgo in rsa ecdsa ed25519 ; do
	hostpub=$(cat /etc/ssh/ssh_host_${keyalgo}_key.pub)
	echo "$hosts $hostpub" >> /etc/ssh/ssh_known_hosts
done
