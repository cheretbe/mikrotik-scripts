:global vmNICMACs
:local lanMACaddr [:pick $vmNICMACs 2]
:local wan1MACaddr [:pick $vmNICMACs 3]
:local wan2MACaddr [:pick $vmNICMACs 4]

:if ([/system identity get name] != "router") do={
  :put "Setting identity to 'router'"
  /system identity set name=router
}

:if ([/interface ethernet get [find mac-address="$lanMACaddr"] name] != "lan") do={
  :put "Setting '$lanMACaddr' interface name to 'lan'"
  /interface ethernet set [find mac-address="$lanMACaddr"] name="lan"
}

:if ([/interface ethernet get [find mac-address="$wan1MACaddr"] name] != "wan1") do={
  :put "Setting '$wan1MACaddr' interface name to 'wan1'"
  /interface ethernet set [find mac-address="$wan1MACaddr"] name="wan1"
}

:if ([/interface ethernet get [find mac-address="$wan2MACaddr"] name] != "wan2") do={
  :put "Setting '$wan2MACaddr' interface name to 'wan2'"
  /interface ethernet set [find mac-address="$wan2MACaddr"] name="wan2"
}

:if ([:len [/interface bridge find name=loopback-force-wan1]] = 0) do={
  :put "Adding bridge 'loopback-force-wan1'"
  /interface bridge add name=loopback-force-wan1
}

:if ([:len [/interface bridge find name=loopback-force-wan2]] = 0) do={
  :put "Adding bridge 'loopback-force-wan2'"
  /interface bridge add name=loopback-force-wan2
}

:if ([:len [/ip address find interface="wan1" and address="192.168.120.11/24"]] = 0) do={
  :put "Adding IP 192.168.120.11/24 on interface 'wan1'"
  /ip address add address=192.168.120.11/24 interface="wan1"
}

:if ([:len [/ip address find interface="wan2" and address="192.168.121.11/24"]] = 0) do={
  :put "Adding IP 192.168.121.11/24 on interface 'wan2'"
  /ip address add address=192.168.121.11/24 interface="wan2"
}

:if ([:len [/ip address find interface="loopback-force-wan1" and address="172.19.10.1/32"]] = 0) do={
  :put "Adding IP 172.19.10.1/32 on interface 'loopback-force-wan1'"
  /ip address add address=172.19.10.1/32 interface="loopback-force-wan1"
}

:if ([:len [/ip address find interface="loopback-force-wan2" and address="172.19.10.2/32"]] = 0) do={
  :put "Adding IP 172.19.10.2/32 on interface 'loopback-force-wan2'"
  /ip address add address=172.19.10.2/32 interface="loopback-force-wan2"
}

:if ([:len [/ip route find dst-address=0.0.0.0/0 and gateway=192.168.120.10]] = 0) do={
  :put "Adding default route via 192.168.120.10"
  /ip route add distance=5 gateway=192.168.120.10
}

:if ([:len [/ip route find dst-address=0.0.0.0/0 and gateway=192.168.121.10]] = 0) do={
  :put "Adding default route via 192.168.121.10"
  /ip route add distance=10 gateway=192.168.121.10
}

:if ([:len [/ip route find routing-mark=wan1 and gateway=192.168.120.10]] = 0) do={
  :put "Adding route via 192.168.120.10 for routing mark 'wan1'"
  /ip route add comment="Force wan1" distance=30 gateway=192.168.120.10 routing-mark=wan1
}

:if ([:len [/ip route find routing-mark=wan2 and gateway=192.168.121.10]] = 0) do={
  :put "Adding route via 192.168.121.10 for routing mark 'wan2'"
  /ip route add comment="Force wan2" distance=30 gateway=192.168.121.10 routing-mark=wan2
}

:if ([:len [/ip firewall mangle find src-address="172.19.10.1" and new-routing-mark="wan1"]] = 0) do={
  :put "Adding mangle rule for wan1 test connections"
  /ip firewall mangle add action=mark-routing chain=output comment=\
    "Force wan1 test connections to be routed through wan1" new-routing-mark=\
    wan1 passthrough=no src-address=172.19.10.1
}

:if ([:len [/ip firewall mangle find src-address="172.19.10.2" and new-routing-mark="wan2"]] = 0) do={
  :put "Adding mangle rule for wan2 test connections"
  /ip firewall mangle add action=mark-routing chain=output comment=\
    "Force wan2 test connections to be routed through wan2" new-routing-mark=\
    wan2 passthrough=no src-address=172.19.10.2
}

:if ([:len [/ip firewall nat find action=masquerade and src-address="172.19.10.1"]] = 0) do={
  :put "Adding NAT rule for wan1 test connections"
  /ip firewall nat add action=masquerade chain=srcnat \
    comment="NAT wan1 test connections" out-interface=wan1 src-address=172.19.10.1
}

:if ([:len [/ip firewall nat find action=masquerade and src-address="172.19.10.2"]] = 0) do={
  :put "Adding NAT rule for wan2 test connections"
  /ip firewall nat add action=masquerade chain=srcnat \
    comment="NAT wan2 test connections" out-interface=wan2 src-address=172.19.10.2
}

if ([/ip dns get servers ] = "") do={
  :put "Setting 1.1.1.1 as DNS server"
  /ip dns set servers="1.1.1.1" 
}