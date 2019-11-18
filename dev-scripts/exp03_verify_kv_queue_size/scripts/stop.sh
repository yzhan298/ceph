#!/bin/bash

sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
sudo ../src/stop.sh

