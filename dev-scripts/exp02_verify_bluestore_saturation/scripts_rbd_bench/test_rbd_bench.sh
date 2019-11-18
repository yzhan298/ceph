#!/bin/bash

sudo echo 3 | sudo tee /proc/sys/vm/drop_caches && sudo sync
sudo bin/ceph osd pool create rbdbench 100 100
sudo bin/rbd create --size=10G rbdbench/bench1
sudo bin/rbd feature disable rbdbench/bench1 object-map fast-diff deep-flatten
sudo bin/rbd map rbdbench/bench1 --id admin 
sudo mkfs -t ext4 -m0 /dev/rbd/rbdbench/bench1
sudo mkfs.ext4 /dev/rbd0
sudo mkdir /mnt/ceph-block-device
sudo mount /dev/rbd/rbdbench/bench1 /mnt/ceph-block-device

sudo bin/rbd -p rbdbench bench bench1 --io-type write --io-size 128K --io-threads 1 --io-total 1G --io-pattern seq 
