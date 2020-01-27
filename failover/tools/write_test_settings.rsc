if ([:len [/system script find name=failover_settings]] != 0) do={ /system script remove failover_settings }
:foreach fVar in=[/system script environment find name~"^failover"] do={/system script environment remove $fVar }
/system script add name=failover_settings source="### test settings\r\
    \n:global failoverWan1PingSrcAddress 172.19.10.1\r\
    \n:global failoverWan2PingSrcAddress 172.19.10.2\r\
    \n:global failoverSwitchRoutes true\r\
    \n#:global failoverPreferWan2 true\r\
    \n:global failoverWan1DefaultRoute [/ip route find dst-address=0.0.0.0/0 and gateway=192.168.120.10 and !routing-mark]\r\
    \n:global failoverWan2DefaultRoute [/ip route find dst-address=0.0.0.0/0 and gateway=192.168.121.10 and !routing-mark]\r\
    \n:global failoverPingTargets {\r\
    \n  \"8.8.4.4\"\r\
    \n}\r\
    \n\r\
    \n:global failoverPingTries 1\r\
    \n:global failoverWan1PingTimeout (:totime 00:00:00.055)\r\
    \n:global failoverWan2PingTimeout (:totime 00:00:00.055)\r\
    \n:global failoverMinPingReplies 1\r\
    \n:global failoverRecoverCount 1\r\
    \n:global failoverMaxFailedHosts 1\r\
    \n\r\
    \n:global failoverAutoUpdate false\r\
    \n:global failoverUpdateSendEmail false\r\
    \n:global failoverUpdateEmailRecipient user@domain.tld"