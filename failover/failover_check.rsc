# Do not change this script
# Settings are in 'failover_settings' script ("System" > "Scripts" in WinBox
# or '/system script edit value-name=source failover_settings' in console)
# https://github.com/cheretbe/mikrotik-scripts/blob/master/failover/README.md

:local LogDebugMsg do={
  :log debug ("Failover script: " . $debugMsg)
  :put $debugMsg
}

:local LogInfoMsg do={
  :log info ("Failover script: " . $infoMsg)
  :put $infoMsg
}

:local LogWarningMsg do={
  :log warning ("Failover script: " . $warningMsg)
  :put ("WARNING: $warningMsg")
}

:local ExitWithError do={
  :log error ("Failover script: $errorMsg")
  :put ("ERROR: $errorMsg")
  :error ("Aborting script execution")
}

:local doPing do={
  :global failoverPingTries
  :global failoverMinPingReplies

  $LogDebugMsg debugMsg=("Pinging $pingTarget (threshold: $failoverMinPingReplies/$failoverPingTries; " . \
    "src-address: $pingSrcAddress; timeout: $pingTimeout)")
  :local pingCount 0;
  :local pingReplies 0;
  :do {
    # Delay so we don't flood ping (check if we need this at all)
    if ($pingCount != 0) do={ :delay 100ms }
    :set pingReplies ($pingReplies + [/ping $pingTarget count=1 src-address=$pingSrcAddress interval=$pingTimeout]);
    :set pingCount ($pingCount + 1);
  } while=($pingCount < $failoverPingTries)
  :local pingIsOk ($pingReplies >= $failoverMinPingReplies)
  $LogDebugMsg debugMsg=("$pingTarget ping result: $pingIsOk ($pingReplies/$failoverPingTries)")
  :return $pingIsOk
}

:local checkAllTargets do={
  :global failoverPingTargets
  :global failoverMaxFailedHosts

  $LogDebugMsg debugMsg=("Checking $routeName")
  :local failedHosts 0 
  :local failedHostsStr ""
  :foreach pingTarget in=$failoverPingTargets do={
    if (![$doPing pingTarget=$pingTarget pingSrcAddress=$pingSrcAddress pingTimeout=$pingTimeout LogDebugMsg=$LogDebugMsg]) do={
      :set failedHosts ($failedHosts + 1)
      if ($failedHostsStr != "") do={ :set $failedHostsStr ($failedHostsStr . ", ") }
      :set failedHostsStr ($failedHostsStr . $pingTarget)
    }
  }

  :local totalHosts ([:len $failoverPingTargets])
  $LogDebugMsg debugMsg=("$routeName test results [failed/threshold/total]: " . \
    "$failedHosts/$failoverMaxFailedHosts/$totalHosts")
  if ($failedHosts >= $failoverMaxFailedHosts) do={
    $LogInfoMsg infoMsg=("$routeName check failed - no ping to host(s) " . $failedHostsStr)
  }
  return ($failedHosts < $failoverMaxFailedHosts)
}

:local versionFileName
if ([:len [/file find where name="flash" and type="directory"]] = 1) do={
  :set versionFileName "flash/failover/version.txt"
} else={
  :set versionFileName "failover/version.txt"
}
:local scriptVersion
if ([:len [/file find name=$versionFileName]] = 0) do={
  :set scriptVersion "UNKNOWN"
} else={
  :set scriptVersion [/file get $versionFileName contents]
  # Remove \n symbol if present
  if ([:typeof [:find $scriptVersion "\n"]] != "nil") do={
    :set scriptVersion [:pick $scriptVersion 0 [:find $scriptVersion "\n"]]
  }
}
$LogDebugMsg debugMsg=("Version $scriptVersion")

:global failoverCheckIsRunning
if ([:typeof $failoverCheckIsRunning] = "nothing") do={
  :set failoverCheckIsRunning false
}
if ($failoverCheckIsRunning) do={
  $ExitWithError errorMsg="Another instance of the script is already running"
}
:set failoverCheckIsRunning true
do {
  $LogDebugMsg debugMsg="Loading settings"
  do {
    /system script run failover_settings
  } on-error={
    :set failoverCheckIsRunning false
    $ExitWithError errorMsg=("Error in 'failover_settings' script. " . \
      "Run '/system script run failover_settings' in the console to view details")
  }

  :global failoverWan1PingSrcAddress
  :global failoverWan2PingSrcAddress
  :global failoverSwitchRoutes
  :global failoverPreferWan2
  :global failoverWan1DefaultRoute
  :global failoverWan2DefaultRoute
  :global failoverPingTargets
  :global failoverWan1PingTimeout
  :global failoverWan2PingTimeout
  :global failoverPingTries
  :global failoverMinPingReplies
  :global failoverMaxFailedHosts
  :global failoverRecoverCount

# Check mandatory parameters
  if ([:typeof $failoverWan1PingSrcAddress] = "nothing") do={
    $ExitWithError errorMsg=("failoverWan1PingSrcAddress parameter is not set")
  }
  if ([:typeof $failoverWan2PingSrcAddress] = "nothing") do={
    $ExitWithError errorMsg=("failoverWan2PingSrcAddress parameter is not set")
  }
  if ($failoverSwitchRoutes) do={
    if ([:len $failoverWan1DefaultRoute] != 1) do={
      $ExitWithError errorMsg=("Invalid failoverWan1DefaultRoute value (len=".[:len $failoverWan1DefaultRoute].")")
    }
    if ([:len $failoverWan2DefaultRoute] != 1) do={
      $ExitWithError errorMsg=("Invalid failoverWan2DefaultRoute value (len=".[:len $failoverWan2DefaultRoute].")")
    }
  }

# Default values for settings that weren't defined explicitly
  if ([:typeof $failoverWan1PingTimeout] = "nothing") do={ :set failoverWan1PingTimeout (:totime 00:00:00.500) }
  if ([:typeof $failoverWan2PingTimeout] = "nothing") do={ :set failoverWan2PingTimeout (:totime 00:00:00.500) }
  if ([:typeof $failoverSwitchRoutes] = "nothing") do={ :set failoverSwitchRoutes false }
  if ([:typeof $failoverPreferWan2] = "nothing") do={ :set failoverPreferWan2 false }
  if ([:typeof $failoverPingTargets] = "nothing") do={
    :set failoverPingTargets { "1.1.1.1"; "1.0.0.1"; "8.8.8.8"; "8.8.4.4";
      "77.88.8.8"; "77.88.8.1" }
  }
  if ([:typeof $failoverPingTries] = "nothing") do={ :set failoverPingTries 5 }
  if ([:typeof $failoverMinPingReplies] = "nothing") do={ :set failoverMinPingReplies 2 }
  if ([:typeof $failoverMaxFailedHosts] = "nothing") do={ :set failoverMaxFailedHosts 2 }
  if ([:typeof $failoverRecoverCount] = "nothing") do={ :set failoverRecoverCount 30 }

  /system script environment print terse where name~"^failover"
  $LogDebugMsg debugMsg="Settings have been loaded successfully"

# WAN1 interface previous state
  :global failoverWan1PrevState
  if ([:typeof $failoverWan1PrevState] = "nothing") do={ :set failoverWan1PrevState 0 }
# WAN2 interface previous state
  :global failoverWan2PrevState
  if ([:typeof $failoverWan2PrevState] = "nothing") do={ :set failoverWan2PrevState 0 }

  :local wan1CheckResult [$checkAllTargets routeName="wan1" \
    pingSrcAddress=$failoverWan1PingSrcAddress pingTimeout=$failoverWan1PingTimeout \
    doPing=$doPing LogDebugMsg=$LogDebugMsg LogInfoMsg=$LogInfoMsg]
  :local wan2CheckResult [$checkAllTargets routeName="wan2" \
    pingSrcAddress=$failoverWan2PingSrcAddress pingTimeout=$failoverWan2PingTimeout \
    doPing=$doPing LogDebugMsg=$LogDebugMsg LogInfoMsg=$LogInfoMsg]

  :local wan1State
  if ($wan1CheckResult) do={
    if ($failoverWan1PrevState = 0) do={ :set wan1State 0 } else={ :set wan1State ($failoverWan1PrevState + 1) }
  } else={
    :set wan1State (-$failoverRecoverCount)
  }
  :local wan2State
  if ($wan2CheckResult) do={
    if ($failoverWan2PrevState = 0) do={ :set wan2State 0 } else={ :set wan2State ($failoverWan2PrevState + 1) }
  } else={
    :set wan2State (-$failoverRecoverCount)
  }
  :global failoverWan1IsUp ($wan1State = 0)
  :global failoverWan2IsUp ($wan2State = 0)

  :put ("failoverWan1IsUp: $failoverWan1IsUp; wan1State: $wan1State; failoverWan1PrevState: $failoverWan1PrevState")
  :put ("failoverWan2IsUp: $failoverWan2IsUp; wan2State: $wan2State; failoverWan2PrevState: $failoverWan2PrevState")

  :local routeUpOrDown false
  :local stateChange
  if ($failoverWan1IsUp != ($failoverWan1PrevState = 0)) do={
    if ($failoverWan1IsUp) do={ :set stateChange "up" } else={ :set stateChange "down" }
    $LogWarningMsg warningMsg=("wan1 went $stateChange")
    :set routeUpOrDown true
  }
  if ($failoverWan2IsUp != ($failoverWan2PrevState = 0)) do={
    if ($failoverWan2IsUp) do={ :set stateChange "up" } else={ :set stateChange "down" }
    $LogWarningMsg warningMsg=("wan2 went $stateChange")
    :set routeUpOrDown true
  }

  if ($failoverSwitchRoutes) do={
    :local activeDistance
    :local inactiveDistance
    :local mainRouteIsActive
    :local mainRouteName
    :local mainRoute
    :local mainRouteIsUp
    :local backupRouteName
    :local backupRoute
    :local backupRouteIsUp

#     We presume that route is active if its route distance is smaller
    :local wan1Distance [/ip route get $failoverWan1DefaultRoute distance]
    :local wan2Distance [/ip route get $failoverWan2DefaultRoute distance]
    if ($wan1Distance < $wan2Distance) do={
      :set activeDistance $wan1Distance
      :set inactiveDistance $wan2Distance
      :set mainRouteIsActive (!$failoverPreferWan2)
    } else={
      :set activeDistance $wan2Distance
      :set inactiveDistance $wan1Distance
      :set mainRouteIsActive ($failoverPreferWan2)
    }
    $LogDebugMsg debugMsg=("mainRouteIsActive: $mainRouteIsActive; wan1Distance: $wan1Distance; wan2Distance: $wan2Distance")

    if ($failoverPreferWan2) do={
      :set mainRouteName "wan2"
      :set backupRouteName "wan1"
      :set mainRoute $failoverWan2DefaultRoute
      :set backupRoute $failoverWan1DefaultRoute
      :set mainRouteIsUp $failoverWan2IsUp
      :set backupRouteIsUp $failoverWan1IsUp
    } else={
      :set mainRouteName "wan1"
      :set backupRouteName "wan2"
      :set mainRoute $failoverWan1DefaultRoute
      :set backupRoute $failoverWan2DefaultRoute
      :set mainRouteIsUp $failoverWan1IsUp
      :set backupRouteIsUp $failoverWan2IsUp
    }

    if ($mainRouteIsActive) do={
      if ((!$mainRouteIsUp) && $backupRouteIsUp) do={
        $LogWarningMsg warningMsg=("Switching default route to '$backupRouteName'")
        /ip route set $mainRoute distance=$inactiveDistance
        /ip route set $backupRoute distance=$activeDistance
        :set routeUpOrDown true
      }
    } else={
      if ($mainRouteIsUp) do={
        $LogWarningMsg warningMsg=("Switching default route to '$mainRouteName'")
        /ip route set $mainRoute distance=$activeDistance
        /ip route set $backupRoute distance=$inactiveDistance
        :set routeUpOrDown true
      }
    }
  }

  if ($routeUpOrDown) do={
    if ([:len [/system script find name=failover_on_up_down]] != 0) do={
      $LogDebugMsg debugMsg=("Running 'failover_on_up_down' script")
      /system script run failover_on_up_down
    }
  }
  :set failoverWan1PrevState $wan1State
  :set failoverWan2PrevState $wan2State

} on-error={
  :set failoverCheckIsRunning false
  $ExitWithError errorMsg="Unhandled error in the script"
}
:set failoverCheckIsRunning false