#!/bin/sh

# fix permissions screwed up by cloud-init
chmod 644 /etc/ssh/ssh_host_*_key.pub
chgrp ssh_keys /etc/ssh/ssh_host_*_key
chmod 640 /etc/ssh/ssh_host_*_key

cat <<EOF >/etc/ssh/ssh_config.d/90-hostbased.conf
HostbasedAuthentication yes
EnableSSHKeysign yes
EOF

sed -i -e "s,#HostbasedAuthentication no,HostbasedAuthentication yes," \
	-e "s/PasswordAuthentication no/PasswordAuthentication yes/g" \
	/etc/ssh/sshd_config

systemctl restart sshd

rm -f /etc/hosts.equiv
echo "# managed by cyclecloud" > /etc/hosts.equiv

hosts=""
for i in $(seq 1 255) ; do
	echo 10.242.3.$i >> /etc/hosts.equiv
	hosts="$hosts,10.242.3.$i"
done

name=$HOSTNAME
use_nodename_as_hostname=$(jetpack config slurm.use_nodename_as_hostname 2>/dev/null)
if [ "$use_nodename_as_hostname" = "True" ] ; then
       name=$(jetpack config cyclecloud.node.name)
fi
name_base=${name%s}
[ "$name_base" != "$name" ] || name_base=${name%login-*}
[ "$name_base" != "$name" ] || name_base=${name%hpc-*}
[ "$name_base" != "$name" ] || name_base=${name%gpu-*}
[ "$name_base" != "$name" ] || name_base=${name%ood[0-9][0-9]}

search_list=$(jetpack config dns.search_list)
partitions="hpc login gpu"

for domain in ${search_list/,/ } internal.cloudapp.net ; do
	cc=vm-hpc2-cyclecloud-p
	hosts="$hosts,$cc,$cc.$domain"

	scheduler=${name_base}s
	hosts="$hosts,$scheduler,$scheduler.$domain"

	for partition in $partitions ; do
		for instance in `seq 1 20` ; do
			node=${name_base}$partition-$instance
			hosts="$hosts,$node,$node.$domain"
		done
	done

	for instance in `seq -w 01 10` ; do
		node=${name_base}ood$instance
		hosts="$hosts,$node,$node.$domain"
	done
done

rm -f /etc/ssh/ssh_known_hosts
echo "# managed by cyclecloud" > /etc/ssh/ssh_known_hosts

hosts=${hosts#,}
for keyalgo in rsa ecdsa ed25519 ; do
	hostpub=$(cat /etc/ssh/ssh_host_${keyalgo}_key.pub)
	echo "$hosts $hostpub" >> /etc/ssh/ssh_known_hosts
done
