Collection of scripts for Mikrotik RouterOS (https://mikrotik.com)

```
python3 -m http.server 8008 --bind 192.168.56.1
/tool fetch url="http://192.168.56.1:8008/cloudflare_dns_check.rsc"; /import file=cloudflare_dns_check.rsc
```
