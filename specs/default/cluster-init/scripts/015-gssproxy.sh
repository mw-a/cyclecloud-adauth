#!/bin/sh
set -e

deleg=$(jetpack config adauth.ad_delegation "")
deleg_account=$(jetpack config adauth.ad_delegation_account "")
deleg_pwd=$(jetpack config adauth.ad_delegation_passwd "")

[ -n "$deleg" -a -n "$deleg_account" -a -n "$deleg_pwd" ] || exit 0

rpm -q cifs-utils >/dev/null 2>&1 || dnf install -y cifs-utils

rm -f /var/lib/gssprox/deleg.keytab
ktutil <<EOF
addent -e aes256-cts -k 0 -password -p $deleg_account -f
$deleg_pwd
wkt /var/lib/gssproxy/deleg.keytab
EOF

cat <<EOF > /etc/gssproxy/99-cifs-client.conf
[service/cifs-client]
  mechs = krb5
  cred_store = keytab:/var/lib/gssproxy/deleg.keytab
  cred_store = ccache:FILE:/var/lib/gssproxy/clients/krb5cc_%U
  cred_store = client_keytab:/var/lib/gssproxy/clients/%U.keytab
  cred_usage = initiate
  allow_any_uid = yes
  trusted = yes
  impersonate = yes
  euid = 0
  min_lifetime = 60
  program = /usr/sbin/cifs.upcall
EOF

# prevent cifs/server.file.core.windows.net being canonicalised to
# cifs/server.privatelink.file.core.windows.net, causing error
# "Server not found in Kerberos database"
cat > /etc/krb5.conf.d/nocanon.conf <<EOF
[libdefaults]
dns_canonicalize_hostname = false
EOF

systemctl restart gssproxy

echo "create  cifs.spnego    * * /bin/env GSS_USE_PROXY=yes /usr/sbin/cifs.upcall %k" > /etc/request-key.d/cifs.spnego.conf
