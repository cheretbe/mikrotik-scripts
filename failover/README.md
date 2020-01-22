#### Installation

```
/tool fetch mode=https url="https://raw.githubusercontent.com/cheretbe/mikrotik-scripts/master/failover/failover_setup.rsc" 
/import failover_setup.rsc
```

#### Configuration options

| Option                     | Required  | Default<br>Value   | Description |
| -------------------------- | --------- | ------------------ | ----------- |
| failoverWan1PingSrcAddress | yes       |                    |             |
| failoverWan2PingSrcAddress | yes       |                    |             |
| failoverSwitchRoutes       | no        | false              |             |
| failoverPreferWan2         | no        | false              |             |
| failoverWan1DefaultRoute   | no        |                    |             |
