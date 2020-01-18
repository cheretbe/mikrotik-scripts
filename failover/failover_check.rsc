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
#  /import failover_settings.rsc
  /system script run failover_settings
  :global failoverWan1PingSrcAddress
  :global failoverWan2PingSrcAddress
  :global failoverSwitchRoutes
  :global failoverWan1DefaultRoute
  :global failoverWan2DefaultRoute
  :global failoverPingTargets
  :global failoverWan1PingTimeout
  :global failoverWan2PingTimeout
  :global failoverPingTries
  :global failoverMinPingReplies
  :global failoverMaxFailedHosts

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
  if ([:typeof $failoverPingTargets] = "nothing") do={
    :set failoverPingTargets { "1.1.1.1"; "1.0.0.1"; "8.8.8.8"; "8.8.4.4";
      "77.88.8.8"; "77.88.8.1" }
  }
  if ([:typeof $failoverPingTries] = "nothing") do={ :set failoverPingTries 5 }
  if ([:typeof $failoverMinPingReplies] = "nothing") do={ :set failoverMinPingReplies 2 }
  if ([:typeof $failoverMaxFailedHosts] = "nothing") do={ :set failoverMaxFailedHosts 2 }

  /system script environment print terse where name~"^failover"
  $LogDebugMsg debugMsg="Settings has been loaded successfully"

# WAN1 interface previous state
  :global failoverWan1PrevState
  if ([:typeof $failoverWan1PrevState] = "nothing") do={ :set failoverWan1PrevState true }
# WAN2 interface previous state
  :global failoverWan2PrevState
  if ([:typeof $failoverWan2PrevState] = "nothing") do={ :set failoverWan2PrevState true }

# We presume that WAN1 is active if its route distance is lower than WAN2's
  :local wan1Distance [/ip route get $failoverWan1DefaultRoute distance]
  :local wan2Distance [/ip route get $failoverWan2DefaultRoute distance]
  :local wan1IsActive ($wan1Distance < $wan2Distance)
  $LogDebugMsg debugMsg=("wan1Distance: $wan1Distance; wan2Distance: $wan2Distance; wan1IsActive: $wan1IsActive")


  :global failoverWan1IsUp [$checkAllTargets routeName="wan1" \
    pingSrcAddress=$failoverWan1PingSrcAddress pingTimeout=$failoverWan1PingTimeout \
    doPing=$doPing LogDebugMsg=$LogDebugMsg LogInfoMsg=$LogInfoMsg]
#  :global failoverWan1IsUp true
  :global failoverWan2IsUp [$checkAllTargets routeName="wan2" \
    pingSrcAddress=$failoverWan2PingSrcAddress pingTimeout=$failoverWan2PingTimeout \
    doPing=$doPing LogDebugMsg=$LogDebugMsg LogInfoMsg=$LogInfoMsg]
#  :global failoverWan2IsUp true

  if (($failoverWan1IsUp != $failoverWan1PrevState) || ($failoverWan2IsUp != $failoverWan2PrevState)) do={
    if ([:len [/system script find name=failover_on_up_down]] != 0) do={
      $LogDebugMsg debugMsg=("Running 'failover_on_up_down' script")
      /system script run failover_on_up_down
    }
  }
  :set failoverWan1PrevState $failoverWan1IsUp
  :set failoverWan2PrevState $failoverWan2IsUp

} on-error={
  :set failoverCheckIsRunning false
  $ExitWithError errorMsg="Unhandled error in the script"
}
:set failoverCheckIsRunning false