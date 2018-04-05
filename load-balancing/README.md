Tracing routes

When using both connections and ports for PCC it is not guaranteed that traceroute
on a client will go the same route as, for example, ssh connection. To run a trace
on specific connection it has to be run on the router:

```
/tool traceroute 8.8.8.8 interface=wan2
```