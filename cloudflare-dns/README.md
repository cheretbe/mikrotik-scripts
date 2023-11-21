* :bulb: If future me comes here for a very complicated config example, [there it is](https://github.com/cheretbe/notes/blob/master/mikrotik/README.md#complicated-config-example).

**TODO:** Switch from using [API keys](https://developers.cloudflare.com/fundamentals/api/get-started/keys/) to [API tokens](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)


```shell
# For 'develop' branch
# -e ms_install_branch=develop
ansible-playbook ~/projects/mikrotik-scripts/tools/ansible/install_script.yml -l all -e "ms_install_script_name=cloudflare-dns"

# Apply host settings from inventory (see example below)
ansible-playbook ~/projects/mikrotik-scripts/cloudflare-dns/update_settings.yml -l host.domain.tld
```

Inventory host settings example
```yaml
mt_cloudflare_api_email: user@domain.tld
mt_cloudflare_api_token: token_value

mt_cloudflare_dns:
  - interface: wan1
    records:
      - {name: "host-1.domain.tld", zoneid: "000000000000", recordid: "000000000000", ttl: 60}
      - {name: "host-2.domain.tld", zoneid: "000000000000", recordid: "000000000000", ttl: 60}
  - interface: wan2
    records:
      - {name: "host-1.domain.tld", zoneid: "000000000000", recordid: "000000000000", ttl: 60}
      - {name: "host-2.domain.tld", zoneid: "000000000000", recordid: "000000000000", ttl: 60}
```

Debugging
```
/log print follow  where (topics~"script" and message~"Cloudflare")
/system script environment print terse where name~"^cfdns"
/system script environment remove [find name~"^cfdns"]

python3 -m http.server 8008 --bind 192.168.56.1

/system script add name=cloudflare_dns_settings source=[/file get cloudflare_dns_settings.example contents]
/system script add name=cloudflare_dns_settings source=([/tool fetch url="http://192.168.56.1:8008/cloudflare_dns_settings.example" as-value output=user]->"data")

/tool fetch url="http://192.168.56.1:8008/cloudflare_dns_check.rsc"; /import file=cloudflare_dns_check.rsc
```
