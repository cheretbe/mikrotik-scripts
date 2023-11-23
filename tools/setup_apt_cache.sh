#!/bin/bash

if [ -f /usr/bin/apt ] ; then
cat <<-EOF >/etc/apt/apt.conf.d/02proxy
  Acquire::http::proxy "http://${1}";
  Acquire::ftp::proxy "${1}";
EOF
fi
