```shell
ip -oneline addr show | grep '192.168.120.10' | awk '{print $2}'

# fast 3g
tc qdisc add dev enp0s8 root netem delay 100ms 10ms 25%
# normal 3g
tc qdisc change dev enp0s8 root netem delay 150ms 10ms 25%
# slow 3g
tc qdisc change dev enp0s8 root netem delay 200ms 20ms 25%

tc qdisc add dev enp0s8 root netem loss 25%
tc qdisc show dev enp0s8
tc qdisc del dev enp0s8 root netem loss 25%
```

```
qdisc: queueing discipline
htb: hierarchical token bucket
```
* https://wiki.debian.org/TrafficControl
* https://stackoverflow.com/questions/614795/simulate-delayed-and-dropped-packets-on-linux