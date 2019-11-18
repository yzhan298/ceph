#!/bin/bash

# clean rbd
RBD_IMAGE_NAME="bench1"
sudo bin/rbd rm rbdbench/$RBD_IMAGE_NAME
sudo bin/ceph osd pool delete rbdbench rbdbench --yes-i-really-really-mean-it
sudo ../src/stop.sh
