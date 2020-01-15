:global failoverWan1PingSrcAddress 172.19.10.1
:global failoverWan2PingSrcAddress 172.19.10.2
#:global failoverSwitchRoutes true
:global failoverWan1DefaultRoute [/ip route find dst-address=0.0.0.0/0 and gateway=192.168.120.10 and !routing-mark]
:global failoverWan2DefaultRoute [/ip route find dst-address=0.0.0.0/0 and gateway=192.168.121.10 and !routing-mark]
:global failoverPingTargets {
  "1.1.1.1";
  "8.8.4.4"
}

:global failoverPingTries 2
:global failoverWan1PingTimeout (:totime 00:00:00.035)
:global failoverWan2PingTimeout (:totime 00:00:00.055)
#:global failoverMinPingReplies 3
:global failoverMaxFailedHosts 1