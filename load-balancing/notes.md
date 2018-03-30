* https://www.manitonetworks.com/networking/2017/7/25/mikrotik-wan-load-balancing
* https://wiki.mikrotik.com/wiki/Manual:PCC

```
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /mnt/data/vagrant-home/insecure_private_key load-balancing/setup.rsc vagrant@172.28.128.4:/ && ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /mnt/data/vagrant-home/insecure_private_key vagrant@172.28.128.4 "/import setup.rsc"
```