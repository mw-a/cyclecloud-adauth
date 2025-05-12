#!/bin/sh
set -e

mkdir -p /opt/cycle/jetpack/scripts
cp /mnt/cluster-init/adauth/default/files/site_info.py /opt/cycle/jetpack/scripts
cp /mnt/cluster-init/adauth/default/files/ad_leave.sh /opt/cycle/jetpack/scripts
chmod 755 /opt/cycle/jetpack/scripts/ad_leave.sh /opt/cycle/jetpack/scripts/site_info.py

[ -f /opt/cycle/jetpack/scripts/onTerminate.sh ] &&
	mv /opt/cycle/jetpack/scripts/onTerminate.sh /opt/cycle/jetpack/scripts/onTerminate.pre-adauth.sh

cat >/opt/cycle/jetpack/scripts/onTerminate.sh << EOF
#!/bin/sh

/opt/cycle/jetpack/scripts/ad_leave.sh

[ -f /opt/cycle/jetpack/scripts/onTerminate.pre-adauth.sh ] && exec /opt/cycle/jetpack/scripts/onTerminate.pre-adauth.sh
EOF
chmod 755 /opt/cycle/jetpack/scripts/onTerminate.sh

[ -f /opt/cycle/jetpack/scripts/onPreempt.sh ] &&
	mv /opt/cycle/jetpack/scripts/onPreempt.sh /opt/cycle/jetpack/scripts/onPreempt.pre-adauth.sh

cat >/opt/cycle/jetpack/scripts/onPreempt.sh << EOF
#!/bin/sh

/opt/cycle/jetpack/scripts/ad_leave.sh

[ -f /opt/cycle/jetpack/scripts/onPreempt.pre-adauth.sh ] && exec /opt/cycle/jetpack/scripts/onPreempt.pre-adauth.sh
EOF
chmod 755 /opt/cycle/jetpack/scripts/onPreempt.sh
