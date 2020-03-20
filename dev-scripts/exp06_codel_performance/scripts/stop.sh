#!/bin/bash

sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
sudo ../src/stop.sh
#sudo bin/init-ceph --verbose stop 
#sleep 5
sudo rm -rf dev out
#sudo rm -rf ceph.conf
#sudo pkill ceph
#sudo  ps ax | grep -p ceph | awk -F ' ' '{print $1}' | xargs sudo kill -9

