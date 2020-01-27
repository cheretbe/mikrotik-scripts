:local LogDebugMsg do={
  :log debug ("Failover update script: " . $debugMsg)
  :put $debugMsg
}

:local LogWarningMsg do={
  :log warning ("Failover update script: " . $warningMsg)
  :put ("WARNING: $warningMsg")
}

:local ExitWithError do={
  :log error ("Failover update script: $errorMsg")
  :put ("ERROR: $errorMsg")
  :error ("Aborting script execution")
}

:local SendEmailMessage do={
  :global failoverUpdateSendEmail
  :global failoverUpdateEmailRecipient

  if (!$failoverUpdateSendEmail) do={ return nil }
  if ($failoverUpdateEmailRecipient = "") do={
      $LogWarningMsg warningMsg=("Error sending email message: " . \
        "failoverUpdateEmailRecipient parameter is not defined")
      return nil
  }
  :put ("Sending email '$emailSubject' to $failoverUpdateEmailRecipient")
  /tool e-mail send to=$failoverUpdateEmailRecipient subject=$emailSubject \
    body=$emailBody
}


$LogDebugMsg debugMsg=("Checking for updates")

$LogDebugMsg debugMsg="Loading settings"
do {
  /system script run failover_settings
} on-error={
  $ExitWithError errorMsg=("Error in 'failover_settings' script. " . \
    "Run '/system script run failover_settings' in the console to view details")
}

:global failoverAutoUpdate
:global failoverUpdateSendEmail
:global failoverUpdateEmailRecipient

if ([:typeof $failoverAutoUpdate] = "nothing") do={ :set failoverAutoUpdate false }
if ([:typeof $failoverUpdateSendEmail] = "nothing") do={ :set failoverUpdateSendEmail false }
if ([:typeof $failoverUpdateEmailRecipient] = "nothing") do={ :set failoverUpdateEmailRecipient "" }

:put ("  failoverAutoUpdate=$failoverAutoUpdate")
:put ("  failoverUpdateSendEmail=$failoverUpdateSendEmail")
:put ("  failoverUpdateEmailRecipient=$failoverUpdateEmailRecipient")

$LogDebugMsg debugMsg="Settings have been loaded successfully"

:local versionFileName
if ([:len [/file find where name="flash" and type="directory"]] = 1) do={
  :set versionFileName "flash/failover/version.txt"
} else={
  :set versionFileName "failover/version.txt"
}

:local installedVersion
if ([:len [/file find name=$versionFileName]] = 0) do={
  :set installedVersion "UNKNOWN"
} else={
  :set installedVersion [/file get $versionFileName contents]
  # Remove \n symbol if present
  if ([:typeof [:find $installedVersion "\n"]] != "nil") do={
    :set installedVersion [:pick $installedVersion 0 [:find $installedVersion "\n"]]
  }
}
$LogDebugMsg debugMsg=("Installed version: $installedVersion")

:local latestVersion
do {
  :set latestVersion ([/tool fetch ("https://raw.githubusercontent.com/cheretbe/" \
    . "mikrotik-scripts/master/failover/version.txt") output=user as-value]->"data")
} on-error={
  $ExitWithError errorMsg=("Error downloading https://raw.githubusercontent" \
    . ".com/cheretbe/mikrotik-scripts/master/failover/version.txt")
}
$LogDebugMsg debugMsg=("Latest version: $latestVersion")

if ($latestVersion = $installedVersion) do={
  $LogDebugMsg debugMsg=("Latest version is already installed")
} else={
  $LogWarningMsg warningMsg=("There is an update from $installedVersion to $latestVersion")
  if ($failoverAutoUpdate) do={
    $LogDebugMsg debugMsg=("Updating from $installedVersion to $latestVersion")
  } else={
    $SendEmailMessage LogWarningMsg=$LogWarningMsg \
      emailSubject=([/system identity get name] . ": Failover script update is available") \
      emailBody=("There is an update to failover script from version " . \
        "$installedVersion to version $latestVersion on router '" . \
        [/system identity get name] . "'\r\nMore info: " . \
        "https://github.com/cheretbe/mikrotik-scripts/blob/master/failover/README.md")
  }
}