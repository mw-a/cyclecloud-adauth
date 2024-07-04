#!/bin/sh -e

mkdir -p /opt/cycle/jetpack/scripts

cat >/opt/cycle/jetpack/scripts/onTerminate.sh << EOF
#!/bin/sh
AD_DOMAIN=\$(jetpack config adauth.ad_domain)
ADMIN_NAME=\$(jetpack config adauth.ad_admin_user)
ADMIN_PASSWORD=\$(jetpack config adauth.ad_admin_password)

AD_COMPUTERNAME=\$(hostname)

echo "\$ADMIN_PASSWORD" | adcli delete-computer --stdin-password -U "\$ADMIN_NAME" -D "\$AD_DOMAIN" "\$AD_COMPUTERNAME"
EOF
cat >/opt/cycle/jetpack/scripts/onPreempt.sh << EOF
#!/bin/sh
AD_DOMAIN=\$(jetpack config adauth.ad_domain)
ADMIN_NAME=\$(jetpack config adauth.ad_admin_user)
ADMIN_PASSWORD=\$(jetpack config adauth.ad_admin_password)

AD_COMPUTERNAME=\$(hostname)

echo "\$ADMIN_PASSWORD" | adcli delete-computer --stdin-password -U "\$ADMIN_NAME" -D "\$AD_DOMAIN" "\$AD_COMPUTERNAME"
EOF
chmod +x /opt/cycle/jetpack/scripts/onTerminate.sh
chmod +x /opt/cycle/jetpack/scripts/onPreempt.sh
