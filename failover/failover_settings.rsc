:global failoverWan1PingSrcAddress 192.168.154.1
:global failoverWan2PingSrcAddress 172.18.20.1
#:global failoverSwitchRoutes true
:global failoverWan1DefaultRoute [/ip route find dst-address=0.0.0.0/0 and gateway=78.155.176.221 and !routing-mark]
:global failoverWan2DefaultRoute [/ip route find dst-address=0.0.0.0/0 and gateway=83.219.131.197 and !routing-mark]
:global failoverPingTargets {
  "1.1.1.1";
  "8.8.4.4"
}

:global failoverPingTries 2
:global failoverWan1PingTimeout (:totime 00:00:00.035)
:global failoverWan2PingTimeout (:totime 00:00:00.055)
#:global failoverMinPingReplies 3
:global failoverMaxFailedHosts 1