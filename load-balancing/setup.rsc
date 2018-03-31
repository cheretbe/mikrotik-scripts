#:put "Press any key"
#:put [/terminal inkey ]

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

:put "Detecting routes..."

:local defaultRoute1
:local defaultRoute2

# TODO: try to optimize search with :foreach route in=[/ip route find where dst-address="0.0.0.0/0"]
:foreach route in=[/ip route find] do={
  :local routeDst [/ip route get $route dst-address]
  :local routeGw [/ip route get $route gateway]
  :local routeDistance [/ip route get $route distance]
  :local routeComment [/ip route get $route comment]
  :local routeIsEnabled (![/ip route get $route disabled])
  :if ((!($routeComment~"autoconf: ")) and $routeIsEnabled) do={
    :if ($routeDst = "0.0.0.0/0") do={
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


/ip firewall mangle
add action=mark-connection chain=input comment="autoconf: Mark wan1 input (old)" in-interface=wan1 new-connection-mark="wan1"

/ip firewall mangle print

:if ([:len [/ip firewall mangle find comment~"autoconf: "]] != 0) do={
  :put "Removing existing mangle rules..."
  /ip firewall mangle remove [find comment~"autoconf: "]
}

:put "Adding mangle rules..."
/ip firewall mangle
add action=mark-connection chain=input  in-interface=wan1 new-connection-mark="input-wan1" \
  comment="autoconf: Mark wan1 input"
