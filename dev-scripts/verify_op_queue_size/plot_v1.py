import matplotlib.pyplot as plt
import numpy as np

data = np.loadtxt('dump-result.csv', delimiter=',', skiprows=2, unpack=True)

# check op_queue_size
plt.figure(1)
plt.plot(data[5], 'bo-')
plt.title('Op Queue Size Over Time')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Time')
plt.ylabel('Op Queue Size')
plt.savefig("dump_plot_op_queue.png", bbox_inches='tight')

data1 = np.loadtxt('dump-rados-bench.csv', delimiter=',', skiprows=1, unpack=True)
# check latency and throughput

plt.figure(2)
plt.plot(data1[0], data1[1], 'bo-')
plt.title('Latency vs Throughput')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Throughput (MB/s)')
plt.ylabel('Latency (s)')
plt.savefig("dump_plot_lat_vs_throughput.png", bbox_inches='tight')

# plot lat and throughput
fig1 = plt.figure(3)
ax1 = fig1.add_subplot(111)
line1 = ax1.plot(data1[0], 'bo-', label='Throughput')
ax1.set_xlabel('Time')
ax1.set_ylabel('Throughput (MB/s)')
ax2 = ax1.twinx()
line2 = ax2.plot(data1[1], 'ro-', label='Latency')
ax2.yaxis.tick_right()
ax2.yaxis.set_label_position("right")
ax2.set_ylabel('Latency (s)') 
fig1.tight_layout() 
fig1.legend(loc='upper right', bbox_to_anchor=(1.2, 0.97))
fig1.savefig("dump_plot_lat_and_throughput.png", bbox_inches='tight')

#plt.show()
