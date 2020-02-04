import matplotlib.pyplot as plt
import numpy as np

data = np.loadtxt('dump-result-sampling.csv', delimiter=',', skiprows=2, unpack=True)

# plot op_queue_size over time
plt.figure(1)
plt.plot(data[3], 'bo-')
plt.title('Op Queue Size Over Time')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Time')
plt.ylabel('Op Queue Size')
plt.savefig("dump_op_queue_sampling.png", bbox_inches='tight')

#plot kv_queue_size over time
plt.figure(2)
plt.plot(data[4], 'bo-')
plt.title('BlueStore Queue Size Over Time')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Time')
plt.ylabel('Kv Queue Size')
plt.savefig("dump_kv_queue_sampling.png", bbox_inches='tight')

#plot throttle_in_flight_ios(direct write, NOT deferred write) over time
plt.figure(3)
plt.plot(data[6], 'bo-')
plt.title('BlueStore In-Flight IOs (Direct IO) Over Time Through Throttle')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Time')
plt.ylabel('In-Flight IOs')
plt.savefig("dump_throttle_inflight_io.png", bbox_inches='tight')

#####
data1 = np.loadtxt('dump-kvq-size.csv', unpack=True)

# plot every kv_queue size from osd.log
plt.figure(4)
plt.plot(data1, 'bo')
plt.title('BlueStore Every KV Queue Size')
plt.xlim(0)
plt.ylim(0)
#plt.xlabel('')
plt.ylabel('Every KV Queue Size')
plt.savefig("dump_every_kvq_size.png", bbox_inches='tight')

# histogram of kv_queue size
#plt.figure(5)
#n, bins, patches = plt.hist(data1, bins=5, color='#0504aa',alpha=0.7, rwidth=0.85)
#plt.savefig("dump_kvq_hist.png", bbox_inches='tight')

#plt.show()
