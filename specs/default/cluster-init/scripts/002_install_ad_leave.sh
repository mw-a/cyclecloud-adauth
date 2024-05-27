#!/bin/sh -e

mkdir -p /opt/cycle/jetpack/scripts
cp /mnt/cluster-init/adauth/default/files/site_info.py /opt/cycle/jetpack/scripts

cat >/opt/cycle/jetpack/scripts/onTerminate.sh << EOF
#!/bin/sh
AD_DOMAIN=\$(jetpack config adauth.ad_domain)
ADMIN_NAME=\$(jetpack config adauth.ad_admin_user)
ADMIN_PASSWORD=\$(jetpack config adauth.ad_admin_password)
#SITE_DC=\$(/opt/cycle/jetpack/scripts/site_info.py -D "\$AD_DOMAIN" --eager | head -1)

# -S "\$SITE_DC"
echo "\$ADMIN_PASSWORD" | adcli delete-computer --stdin-password -U "\$ADMIN_NAME" -D "\$AD_DOMAIN" "\$HOSTNAME"
EOF
cat >/opt/cycle/jetpack/scripts/onPreempt.sh << EOF
#!/bin/sh
AD_DOMAIN=\$(jetpack config adauth.ad_domain)
ADMIN_NAME=\$(jetpack config adauth.ad_admin_user)
ADMIN_PASSWORD=\$(jetpack config adauth.ad_admin_password)
#SITE_DC=\$(/opt/cycle/jetpack/scripts/site_info.py -D "\$AD_DOMAIN" --eager | head -1)

# -S "\$SITE_DC"
echo "\$ADMIN_PASSWORD" | adcli delete-computer --stdin-password -U "\$ADMIN_NAME" -D "\$AD_DOMAIN" "\$HOSTNAME"
EOF
chmod +x /opt/cycle/jetpack/scripts/onTerminate.sh
chmod +x /opt/cycle/jetpack/scripts/onPreempt.sh
