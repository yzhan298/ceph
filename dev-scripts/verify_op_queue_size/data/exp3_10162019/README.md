## verify the op\_queue size when throttler is set to 1 IO

We set the throttler to allow 1 IO ata time:
```
        osd_op_num_shards = 1
        enable_throttle = true
        bluestore_throttle_bytes = 670000
        bluestore_throttle_deferred_bytes = 134217728
        bluestore_throttle_cost_per_io = 5000
        bluestore_throttle_cost_per_io_hdd = 670000
        bluestore_throttle_cost_per_io_ssd = 4000
```
Running on a harddisk(same disk as the Ceph source code).

For rados bench, we set the -t to 8 in this experiment.

runtime 180s

discard the first 60s

op\_queue size 
