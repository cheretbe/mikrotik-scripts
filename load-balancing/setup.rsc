#:put "Press any key"
#:put [/terminal inkey ]

:local wan1ifName

if ([:len [/interface find name="wan1"]] != 0) do={
  :put "'wan1' interface is present"
} else {
  :put "'wan1' interface is not present"
}