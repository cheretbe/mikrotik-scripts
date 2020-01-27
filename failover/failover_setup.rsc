:put "Installing failover check script..."

:local scriptDstName

if ([:len [/file find where name="flash" and type="directory"]] = 1) do={
  :set scriptDstName "flash/failover/failover_check.rsc"
} else={
  :set scriptDstName "failover/failover_check.rsc"
}

:local scriptSrcName "https://raw.githubusercontent.com/cheretbe/mikrotik-scripts/master/failover/failover_check.rsc"
:put ("Downloading $scriptSrcName as $scriptDstName")
/tool fetch mode=https dst-path=$scriptDstName \
  url="https://raw.githubusercontent.com/cheretbe/mikrotik-scripts/master/failover/failover_check.rsc"

if ([:len [/system scheduler find name="failover_check"]] = 0) do={
  :put "Adding 'failover_check' scheduled event"
  /system scheduler add disabled=yes interval=1m name=failover_check on-event=\
      "# https://github.com/cheretbe/mikrotik-scripts/blob/master/failover/README.md\r\
      \n/import $scriptDstName" start-date=jan/01/1970 start-time=\
      00:00:00
} else={
  :put "[!] Will not overwrite existing 'failover_check' scheduled event"
}

:if ([:len [/system script find name="failover_settings"]] = 0) do={
  :put "Adding 'failover_settings' script"
  /system script add name=failover_settings source=\
    "# Failover script settings\r\
    \n# https://github.com/cheretbe/mikrotik-scripts/blob/master/failover/README.md\r\
    \n\r\
    \n#:global failoverWan1PingSrcAddress 172.19.10.1\r\
    \n#:global failoverWan2PingSrcAddress 172.19.10.2\r\
    "
} else={
  :put "[!] Will not overwrite existing 'failover_settings' script"
}


:if ([:len [/system script find name="failover_on_up_down"]] = 0) do={
  :put "Adding 'failover_on_up_down' script"
  /system script add name=failover_on_up_down source=\
    "# Place custom route up/down handler here\r\
    \n# https://github.com/cheretbe/mikrotik-scripts/blob/master/failover/README.md"
} else={
  :put "[!] Will not overwrite existing 'failover_on_up_down' script"
}

:put "Installation complete"