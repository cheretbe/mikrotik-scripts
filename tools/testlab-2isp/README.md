* https://stackoverflow.com/questions/614795/simulate-delayed-and-dropped-packets-on-linux

```shell
ip -oneline addr show | grep '192.168.120.10' | awk '{print $2}'

tc qdisc add dev enp0s8 root netem loss 25%
tc qdisc show dev enp0s8
tc qdisc del dev enp0s8 root netem loss 25%
```