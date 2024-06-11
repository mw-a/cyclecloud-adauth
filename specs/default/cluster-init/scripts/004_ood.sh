#!/bin/sh

role=$(jetpack config slurm.role 2>/dev/null)
if [ "$role" != "execute" ] ; then
	exit 0
fi

partition=$(jetpack config slurm.partition 2>/dev/null)
if [ "$partition" != "gpu" ] ; then
	exit 0
fi

rpm -q epel-release >/dev/null 2>&1 || dnf install -y epel-release

# only Microsoft-modified NVIDIA grid driver has this config file
if ! [ -f /etc/nvidia/gridd.conf ] ; then
	nv=$(mktemp)
	wget -O $nv https://go.microsoft.com/fwlink/?linkid=874272
	chmod +x $nv
	sudo $nv -s
	rm -f $nv

	cp -f /etc/nvidia/gridd.conf.template /etc/nvidia/gridd.conf
	cat <<EOF >>/etc/nvidia/gridd.conf
IgnoreSP=FALSE
EnableUI=FALSE
EOF
	sed -i '/FeatureType=0/d' /etc/nvidia/gridd.conf

	systemctl restart nvidia-gridd
fi

cat << EOF >>/etc/sysctl.d/net.conf
net.core.rmem_max=2097152
net.core.wmem_max=2097152
EOF

sysctl -f /etc/sysctl.d/net.conf

# microsoft docker conflicts with gui server
! rpm -q moby-runc >/dev/null 2>&1 || dnf remove -y moby-runc

dnf grouplist --installed | grep -i "Server with GUI" || dnf groupinstall -y "Server with GUI"

[ -f /etc/yum.repos.d/TurboVNC.repo ] || \
	wget https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.repo -O /etc/yum.repos.d/TurboVNC.repo

[ -f /etc/yum.repos.d/VirtualGL.repo ] || \
	wget https://virtualgl.com/pmwiki/uploads/Downloads/VirtualGL.repo -O /etc/yum.repos.d/VirtualGL.repo

[ "$(rpm -qa turbovnc git VirtualGL turbojpeg xorg-x11-apps nmap | wc -l)" -eq 6 ] || \
	dnf install --enablerepo=powertools -y turbovnc git VirtualGL turbojpeg xorg-x11-apps nmap

dnf grouplist --installed | grep -i "xfce" || dnf groupinstall -y xfce

if ! [ -f /etc/profile.d/desktop.sh ] ; then
	git clone https://github.com/novnc/websockify.git
	cd websockify
	git checkout v0.10.0
	sed -i "s/'numpy'//g" setup.py
	/usr/bin/python3 setup.py install
	ln -s /usr/local/bin/websockify /usr/bin/websockify
	echo '#!/bin/bash' > /etc/profile.d/desktop.sh
	echo 'export PATH=/opt/TurboVNC/bin:$PATH' >> /etc/profile.d/desktop.sh
	echo 'export WEBSOCKIFY_CMD=/usr/local/bin/websockify' >> /etc/profile.d/desktop.sh
fi

service gdm stop
rmmod nvidia_drm nvidia_uvm nvidia_modeset nvidia
/usr/bin/vglserver_config -config +s +f -t

cat <<EOF >/etc/rc.d/rc3.d/busidupdate.sh
#!/bin/bash
BUSID=\$(nvidia-xconfig --query-gpu-info | awk '/PCI BusID/{print \$4}')
nvidia-xconfig --enable-all-gpus --allow-empty-initial-configuration -c /etc/X11/xorg.conf --virtual=1920x1200 --busid \$BUSID -s
sed -i '/BusID/a\ Option "HardDPMS" "false"' /etc/X11/xorg.conf
EOF
chmod +x /etc/rc.d/rc3.d/busidupdate.sh
/etc/rc.d/rc3.d/busidupdate.sh

service gdm start

systemctl set-default graphical.target
systemctl isolate graphical.target

cat <<EOF >/etc/profile.d/vglrun.sh
#!/bin/bash
ngpu=\$(/usr/sbin/lspci | grep NVIDIA | wc -l)
alias vglrun='/usr/bin/vglrun -d :0.\$(( \${port:-0} % \${ngpu:-1}))'
EOF

if ! [ -f /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml ] ; then
	cat <<EOF >/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-screensaver" version="1.0">
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false" unlocked="root"/>
  </property>
</channel>
EOF
fi
