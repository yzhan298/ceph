## study the in-flight I/O in BlueStore

there are two ways to check Ceph in-flight I/O:
1. check throttle value in BlueStore: the throttle value is the in-flight tokens taken, which is the in-flight number of I/Os.
2. create a new perf counter to count the kv\_queue size and committing kv numbers (the in-flight I/Os). The sum is the total I/Os in BlueStore. 

In this experiment, we study the in-flight I/Os.
