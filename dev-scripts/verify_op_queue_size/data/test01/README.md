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

For rados bench, we set the -t from 1 to 256 in this experiment.

runtime 180s, and discard the first 60s

rados bench 4KB write on a HDD.

Goal: observe the saturation in BlueStore.

Result: The op\_queue size is always 0. 

Issiue: The throttle bytes is not using the 670000 as cost .

Solution: set the ```bluestore_throttle_cost_per_io = 0``` and change the writing block size to 128KB. On harddisk, the smaller workloads could become deferred writes.

Next Step: In next exeripment, we set the default ```cost_per_io``` to 0, and forcing the osd to read disk as HDD. We also change the bs to 128KB. 

