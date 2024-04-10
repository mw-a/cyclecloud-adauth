#!/bin/sh

mkdir -p /opt/cycle/jetpack/scripts
cat >>/opt/cycle/jetpack/scripts/onTerminate.sh << EOF
#!/bin/sh
ADMIN_NAME=\$(jetpack config adauth.ad_admin_user)
ADMIN_PASSWORD=\$(jetpack config adauth.ad_admin_password)

echo "\$ADMIN_PASSWORD" | realm leave -U "\$ADMIN_NAME" -r
EOF
cat >>/opt/cycle/jetpack/scripts/onPreempt.sh << EOF
#!/bin/sh
ADMIN_NAME=\$(jetpack config adauth.ad_admin_user)
ADMIN_PASSWORD=\$(jetpack config adauth.ad_admin_password)

echo "\$ADMIN_PASSWORD" | realm leave -U "\$ADMIN_NAME" -r
EOF
chmod +x /opt/cycle/jetpack/scripts/onTerminate.sh
chmod +x /opt/cycle/jetpack/scripts/onPreempt.sh
