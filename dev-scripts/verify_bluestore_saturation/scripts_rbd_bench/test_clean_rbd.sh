#!/bin/bash

sudo umount /mnt/ceph-block-device
sudo rm -rf /mnt/ceph-block-device
sudo bin/rbd unmap rbdbench/bench1
sudo bin/rbd rm rbdbench/bench1
sudo bin/ceph osd pool delete rbdbench rbdbench --yes-i-really-really-mean-it
