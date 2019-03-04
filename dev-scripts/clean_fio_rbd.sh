#!/bin/bash

## delete rbd
sudo umount /mnt/vol1-block-device
sudo bin/rbd unmap vol1
sudo bin/rbd rm vol1
sudo bin/ceph osd pool delete rbd rbd --yes-i-really-really-mean-it
