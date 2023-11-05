* :bulb: If future me comes here for a very complicated config example, [there it is](https://github.com/cheretbe/notes/blob/master/mikrotik/README.md#complicated-config-example).


```shell
# For 'develop' branch
# -e ms_install_branch=develop
ansible-playbook ~/projects/mikrotik-scripts/tools/ansible/install_script.yml -l all -e "ms_install_script_name=cloudflare-dns"
```

Debugging
```
/log print follow  where (topics~"script" and message~"Cloudflare")
/system script environment remove [find name~"^cfdns"]

python3 -m http.server 8008 --bind 192.168.56.1

/system script add name=cloudflare_dns_settings source=[/file get cloudflare_dns_settings.example contents]
/system script add name=cloudflare_dns_settings source=([/tool fetch url="http://192.168.56.1:8008/cloudflare_dns_settings.example" as-value output=user]->"data")

/tool fetch url="http://192.168.56.1:8008/cloudflare_dns_check.rsc"; /import file=cloudflare_dns_check.rsc
```