#!/bin/bash

# preconditioning ssd
./preconditioning.sh

# measurement
sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio ssd_baseline.fio | tee ssd_baseline.txt
