## Correlation between kv\_queue size and BlueStore latency

In order to see the signal of saturation in BlueStore, we need to observe the correlation between BlueStore I/O and latency.

1. exp01: turn off throttle, and dump op\_queue, kv\_queue, perf state
2. exp02: turn on throttle, and dump op\_queue, kv\_queue, perf state
