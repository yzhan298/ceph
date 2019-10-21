## verify the op\_queue size when throttler is set to 1 IO

We set the throttler to allow 1 IO ata time:
```
        bluestore_debug_enforce_settings=hdd
        osd_op_num_shards = 1
        enable_throttle = true
        bluestore_throttle_bytes = 67108864
        ;bluestore_throttle_deferred_bytes = 134217728
        bluestore_throttle_deferred_bytes = 670000
        bluestore_throttle_cost_per_io = 0
        bluestore_throttle_cost_per_io_hdd = 670000
        bluestore_throttle_cost_per_io_ssd = 4000
	```
Running on a harddisk(same disk as the Ceph source code).

For rados bench, we set the -t from 1 to 256 in this experiment. 1 shard for op\_queue. 1 thread for each shard(this is default for HDD in ceph). 

runtime 180s, and discard the first 60s.

rados bench 128KB seq write on a HDD(with file system beneath).

Goal: observe op\_queue with 1 IO throttler and  saturation in BlueStore.

Result: The op\_queue size is close to the number of -t in rados bench. This is correct, because we only allow 1 IO to be processed in the BlueStore, so the ops will be accumulated in the op\_queue. 

Issiue: The issue we found in test01 is solved.

Next Step: we run the rbd bench to get random perforance.

