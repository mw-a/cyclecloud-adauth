#!/bin/sh
#Author : Vinil Vadakkepurakkal
#Integrating AD login for Linux Machines using SSSD.
#OS Tested : CentOS 7 / RHEL7 / Alma Linux 8 / Ubuntu 18.04
#Env - Azure CycleCloud

#Installing the required Packages

OS_VER=$(jetpack config platform_family)
case $OS_VER in 
rhel)
    yum clean all
    pkgs="sssd sssd-tools oddjob oddjob-mkhomedir adcli krb5-workstation openldap-clients python3-ldap python3-dns"
    pkgcount=$(echo $pkgs | wc -w)
    [ "$(rpm -qa $pkgs | wc -l )" -eq $pkgcount ] || dnf install -y $pkgs
    setenforce 0
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    ;;
debian)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    sudo -E apt -y -qq install sssd sssd-tools sssd-ad oddjob oddjob-mkhomedir adcli krb5-user ldap-utils python3-ldap python3-dns -y
    sleep 300
    echo "session required pam_mkhomedir.so" >> /etc/pam.d/common-session
    ;;
esac
