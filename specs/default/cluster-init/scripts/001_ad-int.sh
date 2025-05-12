#!/bin/bash
#Author : Vinil Vadakkepurakkal
#Integrating AD login for Linux Machines using SSSD.
#OS Tested : CentOS 7 / RHEL7 / Alma Linux 8 / Ubuntu 18.04
#Env - Azure CycleCloud
#define variables for AD
AD_JOIN=$(jetpack config adauth.ad_join "")
AD_DOMAIN=$(jetpack config adauth.ad_domain "")

[ "$AD_JOIN" = True -a -n "$AD_DOMAIN" ] || exit 0

AD_OU=$(jetpack config adauth.ad_ou)
ADMIN_NAME=$(jetpack config adauth.ad_admin_user)
ADMIN_PASSWORD=$(jetpack config adauth.ad_admin_password)
AD_ID_MAPPING=$(jetpack config adauth.ad_id_mapping "")

use_nodename_as_hostname=$(jetpack config slurm.use_nodename_as_hostname "$(jetpack config pbspro.use_nodename_as_hostname "")")
AD_COMPUTERNAME=
if [ "$use_nodename_as_hostname" = True ] ; then
	AD_COMPUTERNAME=$(hostname)

	# work around 21 char length limit by shortening partition names - make
	# sure to produce no collisions here when adding new ones
	AD_COMPUTERNAME=${AD_COMPUTERNAME/execute-/e}
	AD_COMPUTERNAME=${AD_COMPUTERNAME/hpc-/h}
	AD_COMPUTERNAME=${AD_COMPUTERNAME/htc-/t}
	AD_COMPUTERNAME=${AD_COMPUTERNAME/gpu-/g}
	AD_COMPUTERNAME=${AD_COMPUTERNAME/login-/l}
fi

if [ -z "$AD_COMPUTERNAME" ] ; then
	servername=$(jetpack config ondemand.portal.serverName "")

	if [ -n "$servername" ] ; then
		AD_COMPUTERNAME=${servername%%.*}
	fi
fi

update-crypto-policies --set DEFAULT:AD-SUPPORT

#AD integration starts from here.
delay=15
n=1
max_retry=3

while true; do
    logger -s "Domain join on $AD_DOMAIN"
    echo "$ADMIN_PASSWORD" | adcli join --stdin-password -U "$ADMIN_NAME" ${AD_OU:+-O "$AD_OU"} ${AD_COMPUTERNAME:+-N "$AD_COMPUTERNAME"} -D "$AD_DOMAIN"
    #-S $SITE_DC

    if ! adcli testjoin -D "$AD_DOMAIN" ; then
        if [[ $n -le $max_retry ]]; then
            logger -s "Failed to domain join the server - Attempt $n/$max_retry:"
            sleep $delay
            ((n++))
        else
            logger -s "Failed to domain join the server after $n attempts."
            exit 1
        fi
    else
        logger -s "Successfully joined domain $AD_DOMAIN"
        break
    fi
done

REALM=${AD_DOMAIN^^*}

cat <<EOF > /etc/sssd/conf.d/ad.conf
[sssd]
domains = $AD_DOMAIN
services = nss, pam
config_file_version = 2

[nss]
filter_groups = root
filter_users = root

[pam]

[domain/$AD_DOMAIN]
id_provider = ad
EOF

if [ "$AD_ID_MAPPING" = True ] ; then
	cat <<EOF >> /etc/sssd/conf.d/ad.conf
override_homedir = /shared/home/%u
override_shell = /bin/bash

# keep cache primed for user group name enumeration (e.g. id)
refresh_expired_interval = 4050

# prevent watchdog from terminating domain child
timeout = 60
EOF
else
	cat <<EOF >> /etc/sssd/conf.d/ad.conf
ldap_id_mapping = false
override_homedir = /shared/home/%u
EOF
fi

if [ -n "$AD_COMPUTERNAME" ] ; then
	cat <<EOF >> /etc/sssd/conf.d/ad.conf
ldap_sasl_authid = $AD_COMPUTERNAME\$@${REALM}
EOF
fi

chmod 600 /etc/sssd/conf.d/ad.conf

systemctl restart sssd
systemctl enable oddjobd
systemctl restart oddjobd

authselect select -f sssd
authselect enable-feature with-mkhomedir

# configure default realm in krb5.conf
sed -i -e "s,^#    default_realm = EXAMPLE.COM,    default_realm = ${REALM}," /etc/krb5.conf
