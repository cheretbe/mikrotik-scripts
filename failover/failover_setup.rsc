:local LogDebugMsg do={
  :log debug ("Failover script installation: $debugMsg")
  :put $debugMsg
}

:local LogInfoMsg do={
  :log info ("Failover script installation: $infoMsg")
  :put $infoMsg
}

:local ExitWithError do={
  :log error ("Failover script installation: $errorMsg")
  :put ("ERROR: $errorMsg")
  :error ("Aborting script execution")
}

:local DownloadFile do={
  :local dlSrcName ("https://raw.githubusercontent.com/cheretbe/" . \
    "mikrotik-scripts/master/failover/$fileName")
  :local dlDstName ("$scriptDstDir/$fileName")
  $LogDebugMsg debugMsg=("Downloading $dlSrcName as $dlDstName")
  do {
    /tool fetch mode=https url=$dlSrcName dst-path=$dlDstName
  } on-error={
    $ExitWithError errorMsg=("Error downloading $dlSrcName")
  }
}


$LogInfoMsg infoMsg="Starting installation"

:local scriptDstDir

if ([:len [/file find where name="flash" and type="directory"]] = 1) do={
  :set scriptDstDir "flash/failover"
} else={
  :set scriptDstDir "failover"
}

$DownloadFile fileName="failover_check.rsc" scriptDstDir=$scriptDstDir \
  LogDebugMsg=$LogDebugMsg ExitWithError=$ExitWithError

$DownloadFile fileName="failover_update.rsc" scriptDstDir=$scriptDstDir \
  LogDebugMsg=$LogDebugMsg ExitWithError=$ExitWithError

$DownloadFile fileName="version.txt" scriptDstDir=$scriptDstDir \
  LogDebugMsg=$LogDebugMsg ExitWithError=$ExitWithError

if ([:len [/system scheduler find name="failover_check"]] = 0) do={
  $LogDebugMsg debugMsg="Adding 'failover_check' scheduled event"
  /system scheduler add disabled=yes interval=1m name=failover_check on-event=\
      "# https://github.com/cheretbe/mikrotik-scripts/blob/master/failover/README.md\r\
      \n/import $scriptDstDir/failover_check.rsc" start-date=jan/01/1970 start-time=\
      00:00:00
} else={
  $LogDebugMsg debugMsg="Will not overwrite existing 'failover_check' scheduled event"
}

if ([:len [/system scheduler find name="failover_update"]] = 0) do={
  $LogDebugMsg debugMsg="Adding 'failover_update' scheduled event"
  # Check for updates weekly every Thursday between 12am and 1am
  # Use current minute value to randomize update checks on different devices
  :local cTime [/system clock get time] 
  :local cMinutes [:pick $cTime ([:len $cTime]-5) ([:len $cTime]-3)]
  /system scheduler add disabled=no interval=1w name=failover_update on-event=\
      "# https://github.com/cheretbe/mikrotik-scripts/blob/master/failover/README.md\r\
      \n/import $scriptDstDir/failover_update.rsc" start-date=jan/01/1970 start-time=\
      ("00:$cMinutes:00")
} else={
  $LogDebugMsg debugMsg="Will not overwrite existing 'failover_update' scheduled event"
}

:if ([:len [/system script find name="failover_settings"]] = 0) do={
  $LogDebugMsg debugMsg="Adding 'failover_settings' script"
  /system script add name=failover_settings source=\
    "# Failover script settings\r\
    \n# https://github.com/cheretbe/mikrotik-scripts/blob/master/failover/README.md#configuration-options\r\
    \n\r\
    \n#:global failoverWan1PingSrcAddress 172.19.10.1\r\
    \n#:global failoverWan2PingSrcAddress 172.19.10.2\r\
    "
} else={
  $LogDebugMsg debugMsg="Will not overwrite existing 'failover_settings' script"
}

:if ([:len [/system script find name="failover_on_up_down"]] = 0) do={
  $LogDebugMsg debugMsg="Adding 'failover_on_up_down' script"
  /system script add name=failover_on_up_down source=\
    "# Place custom route up/down handler here\r\
    \n# https://github.com/cheretbe/mikrotik-scripts/blob/master/failover/README.md"
} else={
  $LogDebugMsg debugMsg="Will not overwrite existing 'failover_on_up_down' script"
}

:if ([:len [/system logging find topics="script;debug"]] = 0) do={
  $LogDebugMsg debugMsg="Adding debug logging rule"
  /system logging add topics=script,debug disabled=yes
}


$LogInfoMsg infoMsg="Installation complete"