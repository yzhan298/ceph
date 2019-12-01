#!/bin/bash

# check ops status
sudo bin/ceph daemon osd.0 dump_historic_ops > dump-ops

# dump bluestore
sudo bin/ceph daemon osd.0 perf dump > dump-bs
