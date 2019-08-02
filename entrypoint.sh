#!/bin/bash
set -euo pipefail

ip=$(ip addr show dev ${NET_DEV} | grep inet | awk '{ print $2 }' | awk -F '/' '{ print $1 }')
echo "${ip} $(hostname).${SAMBA_REALM}" >> /etc/hosts

if [ "$#" -eq 0 ]; then
  if [[ ! -f /etc/samba/smb.conf ]]; then
    echo "No samba config exists, provisioning new samba domain"
    samba-tool domain provision --use-rfc2307 --domain=${SAMBA_DOMAIN} --realm=${SAMBA_REALM} --server-role=dc --dns-backend=BIND9_DLZ --adminpass=${SAMBA_DOMAIN_PASSWORD} --option "bind interfaces only = yes" --option "interfaces = lo ${NET_DEV}" --option "log file = /var/log/samba/%m.log" --option "max log size = 10000"
  fi

  cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
  chgrp bind /etc/krb5.conf
  /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n -e debug
else
  eval ${@}
fi
