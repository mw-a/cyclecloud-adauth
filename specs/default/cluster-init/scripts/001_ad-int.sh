#!/bin/sh
#Author : Vinil Vadakkepurakkal
#Integrating AD login for Linux Machines using SSSD.
#OS Tested : CentOS 7 / RHEL7 / Alma Linux 8 / Ubuntu 18.04
#Env - Azure CycleCloud
#define variables for AD
AD_DOMAIN=$(jetpack config adauth.ad_domain)
#AD_SERVER_IP=$(jetpack config adauth.ad_server_ip)
AD_OU=$(jetpack config adauth.ad_ou)
ADMIN_NAME=$(jetpack config adauth.ad_admin_user)
ADMIN_PASSWORD=$(jetpack config adauth.ad_admin_password)

if [ -z "$AD_DOMAIN" ] ; then
	exit 0
fi

#removing AD server IP incase used in standalone DNS
#sed -i "/$AD_SERVER_IP/d" /etc/hosts

#Update the nameserver and host file - for resolving AD server and AD has its own DNS
#echo "nameserver ${AD_SERVER_IP}" >> /etc/resolv.conf
#echo "${AD_SERVER_IP} ${AD_DOMAIN}" >> /etc/hosts
update-crypto-policies --set DEFAULT:AD-SUPPORT

#checking for AD availability
#nmap -p 389 $AD_SERVER_IP | grep open
#if [ $? -ne 0 ]; then
#    echo "AD is not reachable - please check your network settings"
#    exit 1
#fi

#AD integration starts from here.
delay=15
n=1
max_retry=3

while true; do
    logger -s "Domain join on $AD_DOMAIN"
    echo $ADMIN_PASSWORD | adcli join --stdin-password -U $ADMIN_NAME ${AD_OU:+-O} $AD_OU -D $AD_DOMAIN
    #-S $SITE_DC

    if ! adcli testjoin -D $AD_DOMAIN ; then
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

systemctl restart sssd
