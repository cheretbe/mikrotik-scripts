* https://www.manitonetworks.com/networking/2017/7/25/mikrotik-wan-load-balancing
* https://wiki.mikrotik.com/wiki/Manual:PCC
* https://wiki.mikrotik.com/wiki/How_PCC_works_(beginner)

```shell
vagrant ssh-config mt_router > /tmp/ssh-mt_router
# cd to project
scp -F /tmp/ssh-mt_router load-balancing/setup.rsc mt_router: && ssh -F /tmp/ssh-mt_router mt_router "/import setup.rsc"

#scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
#-i /mnt/data/vagrant-home/insecure_private_key \
#load-balancing/setup.rsc vagrant@172.28.128.4:/ && \
#ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
#-i /mnt/data/vagrant-home/insecure_private_key \
#vagrant@172.28.128.4 "/import setup.rsc"
```

Windows
```batch
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i %USERPROFILE%\.vagrant.d\insecure_private_key load-balancing/setup.rsc vagrant@172.28.128.3:/ && ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i %USERPROFILE%\.vagrant.d\insecure_private_key vagrant@172.28.128.3 "/import setup.rsc"
```

```
/queue simple add max-limit=7M/7M name=queue1 target=wan1
```

```shell
vagrant ssh-config remote_server > ~/temp/ssh-config
scp -F ~/temp/ssh-config .vagrant/machines/client/virtualbox/private_key vagrant@remote_server:
```
```
/interface list add name=wan1+wan2
/interface list member add interface=wan1 list=wan1+wan2
/interface list member add interface=wan2 list=wan1+wan2
/ip firewall nat add action=dst-nat chain=dstnat dst-port=2222 in-interface-list=wan1+wan2 protocol=tcp to-addresses=172.25.0.10 to-ports=22
```