#!/bin/bash
sudo ./discard_sectors.sh /dev/sdc
sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio prec.fio
