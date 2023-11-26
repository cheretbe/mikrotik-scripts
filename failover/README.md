### Maintenance

```
:put [/file get scripts/failover/git_commit_sha.txt contents]
/log print where (topics="script;warning" or topics="script;info") and message~"Failover"

:global failoverWan1PrevState -1
:global failoverWan2PrevState -1
```

#### Installation

```shell
# For 'develop' branch
# -e ms_install_branch=develop
ansible-playbook ~/projects/mikrotik-scripts/tools/ansible/install_script.yml -l router -e "ms_install_script_name=failover"
```

Ansible-managed settings example:
```json
ms_failover_script_settings:
  failoverWan1PingSrcAddress: '"172.19.10.1"'
  failoverWan2PingSrcAddress: '"172.19.10.2"'
  # failoverPingTargets: ""
  failoverRecoverCount: 5
```

```shell
# Apply settings
ansible-playbook ~/projects/mikrotik-scripts/tools/ansible/update_settings.yml -l router -e "ms_install_script_name=failover"
```

#### Configuration options

```
:global failoverWan1DefaultRoute [/ip route find dst-address=0.0.0.0/0 and gateway="wan" and !routing-mark]
:global failoverWan2DefaultRoute [/ip route find dst-address=0.0.0.0/0 and gateway=192.168.7.6 and !routing-mark]
:global failoverSwitchRoutes true
```

| Option                     | Required  | Default<br>Value   | Description |
| -------------------------- | --------- | ------------------ | ----------- |
| failoverWan1PingSrcAddress | yes       |                    | Source IP address to use as packets<br>source for wan1 tests |
| failoverWan2PingSrcAddress | yes       |                    | Source IP address to use as packets<br>source for wan2 tests |
| failoverSwitchRoutes       | no        | `false`            | Automatically swap distances for routes,<br>specified in `failoverWan1DefaultRoute`<br>and `failoverWan1DefaultRoute` variables<br>when one of gateways go down or up |
| failoverPreferWan2         | no        | `false`            | Use wan2 as main route and wan1 as a<br>backup (used only when<br>`failoverSwitchRoutes=true`) |
| failoverWan1DefaultRoute   | no        |                    | Search query that unambiguously identifies<br>default route via wan1 gateway<br>(required when `failoverSwitchRoutes=true`)|
| failoverWan2DefaultRoute   | no        |                    | Search query that unambiguously identifies<br>default route via wan2 gateway<br>(required when `failoverSwitchRoutes=true`)|
| failoverPingTargets        | no        | {"`1.1.1.1`";<br>"`1.0.0.1`";<br>"`8.8.8.8`";<br>"`8.8.4.4`";<br>"`77.88.8.8`";<br>"`77.88.8.1`"} | List of IP addresses to ping during test |
| failoverPingTries          | no        | `5`                | Number of packets to send during single host test |
| failoverMinPingReplies     | no        | `2`                | Minimal number of ping replies for a single<br>host to consider it up |
| failoverMaxFailedHosts     | no        | `2`                | Maximum number of failed hosts to consider<br>a route as down |
| failoverRecoverCount       | no        | `30`               | Minimal successive count of successful<br>test after a fail to consider<br>a route as up again |
| failoverWan1PingTimeout    | no        | `00:00:00.500`     | If no responce is received within specified<br>time, single ping attempt<br>is considered failed for wan1 |
| failoverWan2PingTimeout    | no        | `00:00:00.500`     | If no responce is received within specified<br>time, single ping attempt<br>is considered failed for wan2 |
