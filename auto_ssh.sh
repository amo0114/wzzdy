#!/bin/sh
wget -O /tmp/dropbear https://github.com/amo0114/wzzdy/raw/refs/heads/master/dropbear
chmod +x /tmp/dropbear
mkdir -p /etc/dropbear
[ -f /etc/dropbear/dropbear_rsa_host_key ] || /tmp/dropbear -R
/tmp/dropbear -p 22
