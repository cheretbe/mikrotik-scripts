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

:if ([:len [/ip address find interface="wan1" and address="192.168.120.11/24"]] = 0) do={
  :put "Adding IP 192.168.120.11/24 on interface 'wan1'"
  /ip address add address=192.168.120.11/24 interface="wan1"
}

:if ([:len [/ip address find interface="wan2" and address="192.168.121.11/24"]] = 0) do={
  :put "Adding IP 192.168.121.11/24 on interface 'wan2'"
  /ip address add address=192.168.121.11/24 interface="wan2"
}

:if ([:len [/ip route find dst-address=0.0.0.0/0 and gateway=192.168.120.10]] = 0) do={
  :put "Adding default route via 192.168.120.10"
  /ip route add distance=5 gateway=192.168.120.10
}

:if ([:len [/ip route find dst-address=0.0.0.0/0 and gateway=192.168.121.10]] = 0) do={
  :put "Adding default route via 192.168.121.10"
  /ip route add distance=10 gateway=192.168.121.10
}