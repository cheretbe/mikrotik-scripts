:local ExitWithError do={
  :put ("[ERROR]: $errorMessage")
  :error ("Load-balancing setup script has been aborted")
}

:put "Detecting network interfaces..."

:if ([:len [/interface find name="wan1"]] != 0) do={
  :put "'wan1' interface is present"
} else {
  :put "Could not find 'wan1' interface"
  $ExitWithError errorMessage="For this script to run two interfaces named 'wan1' and 'wan2' have to be present"
}

:if ([:len [/interface find name="wan2"]] != 0) do={
  :put "'wan2' interface is present"
} else {
  :put "Could not find 'wan2' interface"
  $ExitWithError errorMessage="For this script to run two interfaces named 'wan1' and 'wan2' have to be present"
}

:local lanInterface ""
:if ([:len [/interface find name="lan"]] != 0) do={
  :set lanInterface "lan"
} else={
  :if ([:len [/interface find name="lan-bridge"]] != 0) do={
    :set lanInterface "lan-bridge"
  }
}

if ($lanInterface = "") do={
  $ExitWithError errorMessage="For this script to run an interface named 'lan' or bridge named 'lan-brigde' has to be present"
}
:put ("LAN interface name: " . $lanInterface)

:put "Detecting routes..."

:local defaultRoute1
:local defaultRoute2

:foreach route in=[/ip route find dst-address="0.0.0.0/0" && (!(comment~"autoconf: ")) && disabled=no] do={
  :local routeDst [/ip route get $route dst-address]
  :local routeGw [/ip route get $route gateway]
  :local routeDistance [/ip route get $route distance]
  :if ([:typeof $defaultRoute1] = "nothing") do={
    :set defaultRoute1 { "dst"=$routeDst; "gw"=$routeGw; "distance"=$routeDistance }
  } else={
    :if ([:typeof $defaultRoute2] = "nothing") do={
      :set defaultRoute2 { "dst"=$routeDst; "gw"=$routeGw; "distance"=$routeDistance }
    } else={
      $ExitWithError errorMessage="More than 2 initial default routes are present"
    }
  }
}

:local wan1defaultRoute
:local wan2defaultRoute
:if (($defaultRoute2->"distance") > ($defaultRoute1->"distance")) do={
  :set wan1defaultRoute $defaultRoute1
  :set wan2defaultRoute $defaultRoute2
} else={
  :set wan1defaultRoute $defaultRoute2
  :set wan2defaultRoute $defaultRoute1
}

:if (([:typeof $defaultRoute1] = "nothing") or ([:typeof $defaultRoute2] = "nothing")) do={
  $ExitWithError errorMessage="Could not find 2 initial default routes"
}
:put ("'wan1' default route: " . [:tostr $wan1defaultRoute])
:put ("'wan2' default route: " . [:tostr $wan2defaultRoute])


:if ([:len [/ip firewall mangle find comment~"autoconf: "]] != 0) do={
  :put "Removing existing autoconf mangle rules..."
  /ip firewall mangle remove [find comment~"autoconf: "]
}

:put "Adding mangle rules..."
/ip firewall mangle
# Mark INPUT connections
add action=mark-connection chain=input in-interface=wan1 new-connection-mark="input-wan1" \
  passthrough=no comment="autoconf: Mark wan1 input"
add action=mark-connection chain=input in-interface=wan2 new-connection-mark="input-wan2" \
  passthrough=no comment="autoconf: Mark wan2 input"
# Apply routing marks to OUTPUT connections that originated from one interface
# to be routed through that same interface
add action=mark-routing chain=output connection-mark="input-wan1" new-routing-mark="force-wan1" \
  passthrough=no comment="autoconf: Force output connections originated from wan1 to be routed through wan1"
add action=mark-routing chain=output connection-mark="input-wan2" new-routing-mark="force-wan2" \
  passthrough=no comment="autoconf: Force output connections originated from wan2 to be routed through wan2"
# Mark FORWARDED connections
add action=mark-connection chain=forward connection-state=new \
  in-interface=wan1 new-connection-mark="fw-wan1" passthrough=no \
  comment="autoconf: Mark wan1 forwarded connections"
add action=mark-connection chain=forward connection-state=new \
  in-interface=wan2 new-connection-mark="fw-wan2" passthrough=no \
  comment="autoconf: Mark wan2 forwarded connections"
# Apply routing marks to FORWARDED connections that originated from one interface
# to be routed back through that same interface
add action=mark-routing chain=prerouting connection-mark="fw-wan1" \
  in-interface=$lanInterface new-routing-mark="force-wan1" passthrough=no \
  comment= "autoconf: Force forwarded connections originated from wan1 to be routed through wan1"
add action=mark-routing chain=prerouting connection-mark="fw-wan2" \
  in-interface=$lanInterface new-routing-mark="force-wan2" passthrough=no \
  comment= "autoconf: Force forwarded connections originated from wan2 to be routed through wan2"

# Actual load balancing
add action=mark-routing chain=prerouting comment="autoconf: LAN load balancing 2-0" \
    dst-address-type=!local in-interface=$lanInterface new-routing-mark=\
    "force-wan1" passthrough=yes per-connection-classifier=\
    both-addresses-and-ports:2/0
add action=mark-routing chain=prerouting comment="autoconf: LAN load balancing 2-1" \
    dst-address-type=!local in-interface=$lanInterface new-routing-mark=\
    "force-wan2" passthrough=yes per-connection-classifier=\
    both-addresses-and-ports:2/1

:if ([:len [/ip route find comment~"autoconf: "]] != 0) do={
  :put "Removing existing autoconf routes..."
  /ip route remove [find comment~"autoconf: "]
}

:put "Adding routes..."
/ip route
add distance=1 gateway=($wan1defaultRoute->"gw") routing-mark="force-wan1" \
  comment="autoconf: Force wan1 output"
add distance=1 gateway=($wan2defaultRoute->"gw") routing-mark="force-wan2" \
  comment="autoconf: Force wan2 output"

:put "[OK] Load balancing setup has finished"