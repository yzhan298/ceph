import matplotlib.pyplot as plt
import numpy as np

data1 = np.loadtxt('result-single-dump.csv', delimiter=',', unpack=True)
# check kv_queue_size vs bluestore latency(from KV_PREPARED TO KV_FINISHED)
plt.figure(1)
plt.plot(data1[3], data1[7], 'bo-')
plt.title('BlueStore Latency vs KV Queue Size')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Average KV Queue Size')
plt.ylabel('Average BlueStore Commit Latency')
plt.savefig("dump_avgkvq_vs_bslat.png", bbox_inches='tight')

# check kv_queue_size vs bluestore kv_sync_latency
plt.figure(2)
plt.plot(data1[3], data1[4], 'bo-')
plt.title('BlueStore KV Sync Latency vs KV Queue Size')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Average KV Queue Size')
plt.ylabel('Average BlueStore KV Sync Latency')
plt.savefig("dump_avgkvq_vs_kvlat.png", bbox_inches='tight')

#plt.show()
