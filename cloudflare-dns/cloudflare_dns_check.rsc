# Do not change this script
# Settings are in 'cloudflare_dns_settings' script ("System" > "Scripts" in WinBox
# or '/system script edit value-name=source cloudflare_dns_settings' in console)
# https://github.com/cheretbe/mikrotik-scripts/blob/master/cloudflare-dns/README.md

:local LogDebugMsg do={
  :log debug ("Cloudflare DNS script: " . $debugMsg)
  :put $debugMsg
}

:local LogInfoMsg do={
  :log info ("Cloudflare DNS script: " . $infoMsg)
  :put $infoMsg
}

:local LogWarningMsg do={
  :log warning ("Cloudflare DNS script: " . $warningMsg)
  :put ("WARNING: $warningMsg")
}

:local LogErrorMsg do={
  :log error ("Cloudflare DNS script: " . $errorMsg)
  :put ("ERROR: $errorMsg")
}

:local ExitWithError do={
  :log error ("Cloudflare DNS script: " . $errorMsg)
  :put ("ERROR: $errorMsg")
  :error ("Aborting script execution")
}

:local getIfIPAddress do={
  :local ifObj [/ip address find interface=$ifName]
  if ([:len $ifObj] = 0) do={
    return "none"
  }
  if ([/ip address get $ifObj disabled]) do={
    return "none"
  }
  :local ifIPAddress [/ip address get $ifObj address]
  if ($ifIPAddress = "") do={
    return "none"
  }
  if ([:find $ifIPAddress "/"] = 0) do={
    return $ifIPAddress
  } else={
    return [:pick $ifIPAddress 0 [:find $ifIPAddress "/"]]
  }
}

:local checkIfDNSRecords do={

  :local callCFAPI do={
    :global cfdnsAPIAuthEmail
    :global cfdnsAPIAuthKey

    :local apiHTTPHeader ("X-Auth-Email:" . $cfdnsAPIAuthEmail . ",X-Auth-Key:" . $cfdnsAPIAuthKey)
    :local apiHTTPHeaderMasked ("X-Auth-Email:" . $cfdnsAPIAuthEmail . ",X-Auth-Key:*************")
    :local apiResponse
    # $LogDebugMsg debugMsg=("HTTP request, method=". $httpMethod . ", headers=" . $apiHTTPHeaderMasked . ", url=" . $apiUrl)
    do {
      :set apiResponse [/tool fetch mode=https http-method=$httpMethod \
        http-header-field=$apiHTTPHeader http-data=$apiData url=$apiUrl as-value output=user \
      ]
      # $LogDebugMsg debugMsg=($apiResponse)
    } on-error= {
      $LogErrorMsg errorMsg=("API error in $httpMethod method for $apiUrl " . $apiResponse)
      :return {apiresponse=$apiResponse; success=false}
    }
    :return {apiresponse=$apiResponse; success=true}
  }

  :local checkResult true

  $LogDebugMsg debugMsg=("Checking DNS for ". ($mapping->"interface") . " interface")
  foreach record in=($mapping->"records") do={
    :local apiUrl ("https://api.cloudflare.com/client/v4/zones/" . ($record->"zoneid") . "/dns_records/" . ($record->"recordid"))
    :local apiResult [$callCFAPI httpMethod="get" apiUrl=$apiUrl LogDebugMsg=$LogDebugMsg LogErrorMsg=$LogErrorMsg]
    if ($apiResult->"success") do={
      :local dnsRecordIP [:pick ($apiResult->"apiresponse"->"data") ([:find ($apiResult->"apiresponse"->"data") "\"content\":\""] + 11) [:len ($apiResult->"apiresponse"->"data")]]
      :set dnsRecordIP [:pick $dnsRecordIP 0 [:find $dnsRecordIP "\""]]
      $LogDebugMsg debugMsg=("Current DNS record for " . ($record->"name") . ": " . $dnsRecordIP)
      if ($currentIfIP != $dnsRecordIP) do={
        $LogInfoMsg infoMsg=("Updating DNS record for " . ($record->"name") . ": " . $dnsRecordIP . " => " . $currentIfIP)
        :local apiData (\
          "{\"type\": \"A\",\"name\":\"" . ($record->"name") . "\
          \",\"content\":\"" . $currentIfIP . "\",\"ttl\":60,\"proxied\":false}"\
        )
        :local apiResult [$callCFAPI httpMethod="put" apiUrl=$apiUrl apiData=$apiData LogDebugMsg=$LogDebugMsg LogErrorMsg=$LogErrorMsg]
        if (!($apiResult->"success")) do={
          :set checkResult false
        }
      }
    } else={
      :set checkResult false
    }
  }
  :return $checkResult
}

do {
  $LogDebugMsg debugMsg="Loading settings"
  do {
    /system script run cloudflare_dns_settings
  } on-error={
    $ExitWithError errorMsg=("Error in 'cloudflare_dns_settings' script. " . \
      "Run '/system script run cloudflare_dns_settings' in the console to view details")
  }

  :global cfdnsAPIAuthEmail
  :global cfdnsAPIAuthKey
  :global cfdnsMappings
  :global cfdnsForcedCheckInterval
  :global cfdnsPreviousAddresses
  :global cfdnsLastAPICheck

  # Check mandatory parameters
  if ([:typeof $cfdnsAPIAuthEmail] = "nothing") do={
    $ExitWithError errorMsg=("cfdnsAPIAuthEmail parameter is not set")
  }
  if ([:typeof $cfdnsAPIAuthKey] = "nothing") do={
    $ExitWithError errorMsg=("cfdnsAPIAuthKey parameter is not set")
  }
  if ([:typeof $cfdnsMappings] = "nothing") do={
    $ExitWithError errorMsg=("cfdnsMappings parameter is not set")
  }

  # Default values for optional settings
  if ([:typeof $cfdnsForcedCheckInterval] = "nothing") do={ :set cfdnsForcedCheckInterval (:totime "15m") }

  :foreach mapping in=$cfdnsMappings do={
    if ([:len [/interface find name=($mapping->"interface")]] = 0) do={
      $ExitWithError errorMsg=("no such interface: " .  ($mapping->"interface"))
    }
  }

  # Default values for internal state variables
  if ([:typeof $cfdnsPreviousAddresses] = "nothing") do={
    :set cfdnsPreviousAddresses [:toarray ""]
  }
  :foreach mapping in=$cfdnsMappings do={
    if ([:typeof ($cfdnsPreviousAddresses->($mapping->"interface"))] = "nothing") do={
      # Direct assignment to cfdnsPreviousAddresses doesn't work
      # Probably this has something to do with the following rule: "(if) Key name in
      # the array contains any character other than a lowercase character, it should
      # be put in quotes".
      # https://help.mikrotik.com/docs/display/ROS/Scripting#Scripting-OperationswithArrays
      # Attempts to use different kinds of sophisticated qouting didn't help.
      # Which is why we are using an unusal (even by ROS script standards) assignment:
      # Building a string with necessary code and parsing it
      [:parse [(":global cfdnsPreviousAddresses; :set cfdnsPreviousAddresses (\$cfdnsPreviousAddresses, {\"" . ($mapping->"interface") . "\"=\"none\"})")]]
    }
  }
  if ([:typeof $cfdnsLastAPICheck] = "nothing") do={
    :set cfdnsLastAPICheck [:totime "00:00:00"]
  }

  /system script environment print terse where name~"^cfdns"
  $LogDebugMsg debugMsg="Settings have been loaded successfully"

  :local needAPICheck false
  if (([/system resource get uptime] < $cfdnsForcedCheckInterval) || (([/system resource get uptime] - $cfdnsLastAPICheck) > $cfdnsForcedCheckInterval)) do={
    $LogDebugMsg debugMsg=("Over " . $cfdnsForcedCheckInterval . " has passed since last successful API check, forcing check")
    :set needAPICheck true
  }

  :local APIcheckSuccessful true
  :foreach mapping in=$cfdnsMappings do={
    :local needIfCheck false
    :local currentIfIP [$getIfIPAddress ifName=($mapping->"interface")]
    $LogDebugMsg debugMsg=("Current " . ($mapping->"interface") . " IP: " . $currentIfIP)

    if (!$needAPICheck) do={
      if ($currentIfIP != ($cfdnsPreviousAddresses->($mapping->"interface"))) do={
        $LogInfoMsg infoMsg=(($mapping->"interface") . " IP has changed " . ($cfdnsPreviousAddresses->($mapping->"interface")) . \
          " => " . $currentIfIP . ", will check DNS records")
        :set needIfCheck true
        :set ($cfdnsPreviousAddresses->($mapping->"interface")) $currentIfIP
      }
    }

    if (($currentIfIP != "none") and ($needAPICheck or $needIfCheck)) do={
      :local ifCheckResult [$checkIfDNSRecords mapping=$mapping currentIfIP=$currentIfIP LogDebugMsg=$LogDebugMsg LogInfoMsg=$LogInfoMsg LogErrorMsg=$LogErrorMsg]
      if (!$ifCheckResult) do={
        :set APIcheckSuccessful false
      }
    }
  }

  if ($APIcheckSuccessful) do={
    $LogDebugMsg debugMsg=("Setting cfdnsLastAPICheck")
    :set cfdnsLastAPICheck [/system resource get uptime]
  }

} on-error={
  $ExitWithError errorMsg="Unhandled error in the script"
}
