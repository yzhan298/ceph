#!/bin/bash

# clean rbd
RBD_IMAGE_NAME="image1"
sudo bin/rbd rm mybench/$RBD_IMAGE_NAME
sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
sudo ../src/stop.sh
