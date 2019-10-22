import matplotlib.pyplot as plt
import numpy as np

data = np.loadtxt('dump-rbd-bench.csv', delimiter=',', skiprows=1, unpack=True)

# plot throughput
plt.figure(1)
plt.plot(data[1], 'bo-')
plt.title('RBD Bench Rand Write Throughput')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Time')
plt.ylabel('Throughput (MB/s)')
plt.savefig("dump_rbd_bench_throughput_rand_write.png", bbox_inches='tight')

#plt.show()
