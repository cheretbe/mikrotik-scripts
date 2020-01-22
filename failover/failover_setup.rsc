:if ([:len [/system script find name="failover_on_up_down"]] = 0) do={
  :put "Adding 'failover_on_up_down' script"
  /system script add name=failover_on_up_down source=\
    "# Place custom route up/down handler here"
}