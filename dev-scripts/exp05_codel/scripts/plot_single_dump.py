import matplotlib.pyplot as plt
import numpy as np

data1 = np.loadtxt('result-single-dump.csv', delimiter=',', skiprows=1, unpack=True)
'''
# check kv_queue_size vs bluestore kv_sync_latency
plt.figure(2)
plt.plot(data1[3], data1[5], 'bo-')
plt.title('BlueStore KV Sync Latency vs KV Queue Size')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Average KV Queue Size')
plt.ylabel('Average BlueStore KV Sync Latency')
plt.savefig("dump_avgkvq_vs_kvlat.png", bbox_inches='tight')

# plot qdepth vs latencies
plt.figure(3)
plt.plot(data1[2], data1[5], 'bo-', label="bluestore_kv_sync_lat") # vs bluestore_kv_sync_lat
plt.plot(data1[2], data1[8], 'go-', label="bluestore_commit_lat") # vs bluestore_commit_lat
plt.plot(data1[2], data1[9], 'ro-', label="bs_aio_wait_lat") # vs bs_aio_wait_lat
plt.plot(data1[2], data1[10], 'co-', label="bs_kv_queued_lat") # vs bs_kv_queued_lat
plt.plot(data1[2], data1[11], 'yo-', label="bs_kv_committing_lat") # vs bs_kv_committing_lat
plt.title('BlueStore Latencies vs Worklaod Concurrency')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Workload Concurrency')
plt.ylabel('Latencies (s)')
plt.legend()
plt.savefig("dump_lat_vs_qd.png", bbox_inches='tight')
'''
fig, ax1 = plt.subplots()
ax1.set_xlabel('worklaod concurrency')
ax1.set_ylabel('time (s)')
ax1.plot(data1[2], data1[5], 'bo-', label="bs_kv_sync_lat") # vs bluestore_kv_sync_lat
ax1.plot(data1[2], data1[8], 'go-', label="bs_commit_lat") # vs bluestore_commit_lat
ax1.plot(data1[2], data1[9], 'ro-', label="bs_aio_wait_lat") # vs bs_aio_wait_lat
ax1.plot(data1[2], data1[10], 'co-', label="bs_kv_queued_lat") # vs bs_kv_queued_lat
ax1.plot(data1[2], data1[11], 'yo-', label="bs_kv_committing_lat") # vs bs_kv_committing_lat
ax1.plot(data1[2], data1[7], 'mo-', label="bs_kvq_lat") # vs average delay in kv_queue

ax2 = ax1.twinx()
ax2.set_ylabel("throughput (MB/s)")
ax2.plot(data1[2], data1[12], 'kx--', label="throughput")

fig.tight_layout()  # otherwise the right y-label is slightly clipped
#fig.legend(bbox_to_anchor=(1.29, 0.975))
fig.suptitle("BlueStore Throughput and Latency", y=1.02)
fig.savefig("dump_thp_lat.png", bbox_inches='tight')

plt.figure(2)
plt.plot(data1[12], data1[13], 'bo-')
plt.title('Rados Bench Latency vs Throughput')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('avg throughput (MB/s)')
plt.ylabel('avg latency (s)')
plt.savefig("dump_avglat_vs_avgthp.png", bbox_inches='tight')

#plt.show()
