:local failoverScriptVersion "0.9"

:local LogDebugMsg do={
  :log debug ("Failover script: " . $debugMsg)
  :put $debugMsg
}

:local LogInfoMsg do={
  :log info ("Failover script: " . $infoMsg)
  :put $infoMsg
}

:local ExitWithError do={
  :log error ("Failover script: $errorMsg")
  :put ("ERROR: $errorMsg")
  :error ("Aborting script execution")
}

:local doPing do={
  :global failoverPingTries
  :global failoverMinPingReplies
  :global failoverPingTimeout

  $LogDebugMsg debugMsg=("Pinging $pingTarget (threshold: $failoverMinPingReplies/$failoverPingTries; " . \
    "src-address: $pingSrcAddress; timeout: $failoverPingTimeout)")
  :local pingCount 0;
  :local pingReplies 0;
  :do {
    # Don't flood ping
    if ($pingCount != 0) do={ :delay 100ms }
    :set pingReplies ($pingReplies + [/ping $pingTarget count=1 src-address=$pingSrcAddress interval=$failoverPingTimeout]);
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
    if (![$doPing pingTarget=$pingTarget pingSrcAddress=$pingSrcAddress LogDebugMsg=$LogDebugMsg]) do={
      :set failedHosts ($failedHosts + 1)
      if ($failedHostsStr != "") do={ :set $failedHostsStr ($failedHostsStr . ", ") }
      :set failedHostsStr ($failedHostsStr . $pingTarget)
    }
  }

  :local totalHosts ([:len $failoverPingTargets])
  $LogDebugMsg debugMsg=("$routeName test results [failed/threshold/total]: " . \
    "$failedHosts/$failoverMaxFailedHosts/$totalHosts")
  if ($failedHosts >= $failoverMaxFailedHosts) do={
    $LogInfoMsg infoMsg=("No ping on $routeName to host(s) " . $failedHostsStr)
  }
  return ($failedHosts < $failoverMaxFailedHosts)
}


$LogDebugMsg debugMsg=("Version " . $failoverScriptVersion)

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
  /import failover_settings.rsc
  :global failoverSwitchRoutes
  :global failoverWan1DefaultRoute
  :global failoverWan2DefaultRoute
  :global failoverPingTargets

  if ($failoverSwitchRoutes) do={
    if ([:len $failoverWan1DefaultRoute] != 1) do={
      $ExitWithError errorMsg=("Invalid failoverWan1DefaultRoute value (len=".[:len $failoverWan1DefaultRoute].")")
    }
    if ([:len $failoverWan2DefaultRoute] != 1) do={
      $ExitWithError errorMsg=("Invalid failoverWan2DefaultRoute value (len=".[:len $failoverWan2DefaultRoute].")")
    }
  }

# WAN1 interface previous state
  :global failoverWan1PrevState
  if ([:typeof $failoverWan1PrevState] = "nothing") do={ :set failoverWan1PrevState true}
# WAN2 interface previous state
  :global failoverWan2PrevState
  if ([:typeof $failoverWan2PrevState] = "nothing") do={ :set failoverWan2PrevState true }

# We presume that WAN1 is active if its route distance is lower than WAN2's
  :local wan1Distance [/ip route get $failoverWan1DefaultRoute distance]
  :local wan2Distance [/ip route get $failoverWan2DefaultRoute distance]
  :local wan1IsActive ($wan1Distance < $wan2Distance)
  $LogDebugMsg debugMsg=("wan1Distance: $wan1Distance; wan2Distance: $wan2Distance; wan1IsActive: $wan1IsActive")


  :global failoverwan1IsUp [$checkAllTargets routeName="wan1" \
    pingSrcAddress="192.168.154.1" doPing=$doPing LogDebugMsg=$LogDebugMsg \
    LogInfoMsg=$LogInfoMsg]
#  :global failoverwan1IsUp true
  :global failoverwan2IsUp [$checkAllTargets routeName="wan2" \
    pingSrcAddress="192.168.154.1" doPing=$doPing LogDebugMsg=$LogDebugMsg \
    LogInfoMsg=$LogInfoMsg]
#  :global failoverwan2IsUp true

  if (($failoverwan1IsUp != $failoverWan1PrevState) || ($failoverwan2IsUp != $failoverWan2PrevState)) do={
    if ([:len [/system script find name=failover_on_up_down]] != 0) do={
      $LogDebugMsg debugMsg=("Running 'failover_on_up_down' script")
      /system script run failover_on_up_down
    }
  }
  :set failoverWan1PrevState $failoverwan1IsUp
  :set failoverWan2PrevState $failoverwan2IsUp

#  :put $failoverPingTargets
} on-error={
  :set failoverCheckIsRunning false
  $ExitWithError errorMsg="Unhandled error in the script"
}
:set failoverCheckIsRunning false