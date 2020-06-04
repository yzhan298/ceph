#!/bin/bash

# create a 32GB tmpfs
sudo mkdir /mnt/mnttmp
sudo mount -t tmpfs -o size=32G tmpfs /mnt/mnttmp
sudo truncate -s 32G /mnt/mnttmp/loopfile

# create and format loop device
sudo losetup -f /mnt/mnttmp/loopfile
sudo losetup -j /mnt/mnttmp/loopfile
# output will say which loop device was used, e.g. loop0

sudo mkfs.xfs /dev/loop0
sudo rm -rf ~/ceph/build/dev/ ~/ceph/build/out/
sudo mkdir ~/ceph/build/dev/
sudo mount -t xfs /dev/loop0 ~/ceph/build/dev
#sudo chown $USER:$USER ~/src/ceph/build/dev
