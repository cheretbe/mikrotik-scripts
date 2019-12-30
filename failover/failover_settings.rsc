:global failoverSwitchRoutes false
:global failoverWan1DefaultRoute [/ip route find dst-address=0.0.0.0/0 and gateway=78.155.176.221 and !routing-mark]
:global failoverWan2DefaultRoute [/ip route find dst-address=0.0.0.0/0 and gateway=83.219.131.197 and !routing-mark]
:global failoverPingTargets {
  "1.1.1.1";
#  "1.0.0.1";
#  "8.8.8.8";
  "8.8.4.4"
}

#:global failoverPingTries 3
:global failoverPingTries 2
:global failoverPingTimeout (:totime 00:00:00.035)
:global failoverMinPingReplies 2
:global failoverMaxFailedHosts 1