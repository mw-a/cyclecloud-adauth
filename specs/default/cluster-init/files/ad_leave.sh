#!/bin/sh
AD_DOMAIN=$(jetpack config adauth.ad_domain)
ADMIN_NAME=$(jetpack config adauth.ad_admin_user)
ADMIN_PASSWORD=$(jetpack config adauth.ad_admin_password)
#SITE_DC=$(/opt/cycle/jetpack/scripts/site_info.py -D "$AD_DOMAIN" --eager | head -1)

# work around 21 char length limit by shortening partition names - make
# sure to produce no collisions here when adding new ones
AD_COMPUTERNAME=$(hostname)
AD_COMPUTERNAME=${AD_COMPUTERNAME/execute-/e}
AD_COMPUTERNAME=${AD_COMPUTERNAME/hpc-/h}
AD_COMPUTERNAME=${AD_COMPUTERNAME/htc-/t}
AD_COMPUTERNAME=${AD_COMPUTERNAME/gpu-/g}
AD_COMPUTERNAME=${AD_COMPUTERNAME/login-/l}

# -S "$SITE_DC"
echo "$ADMIN_PASSWORD" | adcli delete-computer --stdin-password -U "$ADMIN_NAME" -D "$AD_DOMAIN" "$AD_COMPUTERNAME"
