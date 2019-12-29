:local failoverScriptVersion "0.9"

:local LogDebugMsg do={
  :log debug ("Failover script: " . $debugMsg)
  :put $debugMsg
}

:local ExitWithError do={
  :log error ("Failover script: $errorMsg")
  :put ("ERROR: $errorMsg")
  :error ("Aborting script execution")
}

$LogDebugMsg debugMsg=("Version " . $failoverScriptVersion)

#:log warning "warning test"

#$ExitWithError errorMsg="Error test"

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

#  :delay 10
#  aaaa

  :put $failoverPingTargets
} on-error={
  :set failoverCheckIsRunning false
  $ExitWithError errorMsg="Unhandled error in the script"
}
:set failoverCheckIsRunning false