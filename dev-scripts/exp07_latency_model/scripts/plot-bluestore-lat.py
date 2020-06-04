import sys
import numpy as np
from pandas import read_csv
import pandas as pd
from dateutil import parser
from datetime import datetime, timedelta, timezone
import pytz
import matplotlib.pyplot as plt

utc=pytz.UTC # work with offset-naive and offset-aware datetimes

f1='dump_time_stamps_vec.csv'
data1=read_csv(f1, skiprows=10000, parse_dates=True, squeeze=True, sep=',', header=None)
datalen = len(data1.values)

def check_bracket(str):
    if str == None:
        return "0"
    if str.startswith('['):
        return str[1:]
    if str.endswith(']'):
        return str[:-1]
    return str

# for bluestore latency(with compactions)
x_bs_lat = [] # bluestore starting timestamps(all)
y_bs_lat = [] # bluestore latencies(all)
# process spikes(timestamps)
big_spikes_ts = [] 
small_spikes_ts = []
non_big_spikes_ts = []
non_spikes_ts = []
# process spikes(latencies)
big_spikes_lat = []
small_spikes_lat = []
non_big_spikes_lat = []
non_spikes_lat = []

# process the time stamps
for i in range(datalen-1):
    # simple writes
    #if len(data1.values[i,:]) == len(data1.values[i+1,:]) and data1.values[i,2] == 'simple_s':
    if data1.values[i,2] == 'simple_s':
        # for first ctx
        ctr_ctx1 = parser.parse(check_bracket(data1.values[i,1])).replace(tzinfo=utc)
        simple_s1 = parser.parse(check_bracket(data1.values[i,3])).replace(tzinfo=utc)
        aio_done1 = parser.parse(check_bracket(data1.values[i,5])).replace(tzinfo=utc)
        flush_cmt_s1 = parser.parse(check_bracket(data1.values[i,7])).replace(tzinfo=utc)
        flush_cmt_e1 = parser.parse(check_bracket(data1.values[i,9])).replace(tzinfo=utc)
        simple_e1 = parser.parse(check_bracket(data1.values[i,11])).replace(tzinfo=utc)
        # for second ctx
        '''ctr_ctx2 = parser.parse(check_bracket(data1.values[i+1,1]))
        simple_s2 = parser.parse(check_bracket(data1.values[i+1,3]))
        aio_done2 = parser.parse(check_bracket(data1.values[i+1,5]))
        flush_cmt_s2 = parser.parse(check_bracket(data1.values[i+1,7]))
        flush_cmt_e2 = parser.parse(check_bracket(data1.values[i+1,9]))
        simple_e2 = parser.parse(check_bracket(data1.values[i+1,11]))'''
        
        # sanity check of timestamps
        if simple_s1 < ctr_ctx1 or aio_done1 < simple_s1 or flush_cmt_s1 < aio_done1 or flush_cmt_e1 < flush_cmt_s1 or simple_e1 < flush_cmt_e1:
            print("simple writes timestamp order is incorrect")
        
        # bluestore latency(including compactions)
        bluestore_lat_simple = simple_e1 - simple_s1
        x_bs_lat.append(simple_s1)
        y_bs_lat.append(bluestore_lat_simple.total_seconds())
        
        # separate spikes with NON-spikes
        if bluestore_lat_simple.total_seconds() > 0.04:
            print("[simple_writes] big_spike lat:",bluestore_lat_simple.total_seconds(),", big_spike starting time:",check_bracket(data1.values[i,3]))
            big_spikes_ts.append(simple_s1)
            big_spikes_lat.append(bluestore_lat_simple.total_seconds())
        if bluestore_lat_simple.total_seconds() <= 0.04:
            non_big_spikes_ts.append(simple_s1)
            non_big_spikes_lat.append(bluestore_lat_simple.total_seconds())
        if bluestore_lat_simple.total_seconds() > 0.02 and bluestore_lat_simple.total_seconds() <= 0.04:
            print("[simple_writes] small_spike lat:",bluestore_lat_simple.total_seconds(),", small_spike starting time:",check_bracket(data1.values[i,3]))
            small_spikes_ts.append(simple_s1)
            small_spikes_lat.append(bluestore_lat_simple.total_seconds())
        if bluestore_lat_simple.total_seconds() <= 0.02:
            non_spikes_ts.append(simple_s1)
            non_spikes_lat.append(bluestore_lat_simple.total_seconds())
            
    # deferred writes
    elif data1.values[i,2] == 'deferred_s':
        ctr_ctx1 = parser.parse(check_bracket(data1.values[i,1])).replace(tzinfo=utc)
        deferred_s1 = parser.parse(check_bracket(data1.values[i,3])).replace(tzinfo=utc)
        flush_cmt_s1 = parser.parse(check_bracket(data1.values[i,5])).replace(tzinfo=utc)
        flush_cmt_e1 = parser.parse(check_bracket(data1.values[i,7])).replace(tzinfo=utc)
        deferred_e1 = parser.parse(check_bracket(data1.values[i,9])).replace(tzinfo=utc)
        # sanity check of timestamps
        if deferred_s1 < ctr_ctx1 or flush_cmt_s1 < deferred_s1 or flush_cmt_e1 < flush_cmt_s1 or deferred_e1 < flush_cmt_e1:
            print("deferred writes timestamp order is incorrect")
        # bluestore latency
        bluestore_lat_deferred = deferred_e1 - deferred_s1
        x_bs_lat.append(deferred_s1)
        y_bs_lat.append(bluestore_lat_deferred.total_seconds())
        
        # separate spikes with NON-spikes
        if bluestore_lat_deferred.total_seconds() > 0.04:
            print("[deferred_writes] big_spike lat:",bluestore_lat_simple.total_seconds(),", big_spike starting time:",check_bracket(data1.values[i,3]))
            big_spikes_ts.append(simple_s1)
            big_spikes_lat.append(bluestore_lat_simple.total_seconds())
        if bluestore_lat_deferred.total_seconds() <= 0.04:
            non_big_spikes_ts.append(simple_s1)
            non_big_spikes_lat.append(bluestore_lat_simple.total_seconds())
        if bluestore_lat_deferred.total_seconds() > 0.02 and bluestore_lat_simple.total_seconds() <= 0.04:
            print("[deferred_writes] small_spike lat:",bluestore_lat_simple.total_seconds(),", small_spike starting time:",check_bracket(data1.values[i,3]))
            small_spikes_ts.append(simple_s1)
            small_spikes_lat.append(bluestore_lat_simple.total_seconds())
        if bluestore_lat_deferred.total_seconds() <= 0.02:
            non_spikes_ts.append(simple_s1)
            non_spikes_lat.append(bluestore_lat_simple.total_seconds())
        



# read compaction data from RocksDB
if0='flush_job_timestamps.csv'     # Compaction for L0
if1='compact_job_timestamps.csv'   # Compaction for other levels
id0=read_csv(if0, parse_dates=True, squeeze=True, sep=',', header=None)
id1=read_csv(if1, parse_dates=True, squeeze=True, sep=',', header=None)

# L0
id0len = len(id0.values)
x_l0_timestamps = [] # flush(L0) timestamps
x_l0_timestamps_us = [] #timestamps in microseconds for L0
y_l0_dummy = [] # dummp y value for L0
dur_l0 = [] # durations(width of compaction) for l0

# >=L1
id1len = len(id1.values)
x_l1_timestamps = [] # flush(L1) timestamps
x_l1_timestamps_us = [] #timestamps in microseconds for L1
y_l1_dummy = [] # dummp y value for L1
dur_l1 = [] # durations(width of compaction) for l1

# L0 compaction timestamps and durations
for i in range(id0len):
    x_l0_timestamps.append((parser.parse(id0.values[i,1])-timedelta(hours=5)).replace(tzinfo=utc))
    dur_l0.append(id0.values[i,5]/1000000)
    y_l0_dummy.append(0.02)
    x_l0_timestamps_us.append(id0.values[i,3])
# >=L1 compaction timestamps and durations
for i in range(id1len):
    x_l1_timestamps.append((parser.parse(id1.values[i,1])-timedelta(hours=5)).replace(tzinfo=utc))
    dur_l1.append(id1.values[i,5]/1000000)
    y_l1_dummy.append(0.02)
    x_l1_timestamps_us.append(id1.values[i,3])

avg_dur_l0 = 0 # average compaction duration for L0
avg_gap_l0 = 0 # average time interval between two compactions for L0
avg_dur_l1 = 0 # average compaction duration for >=L1
avg_gap_l1 = 0 # average time interval between two compactions for >=L1

# L0 avgs
for i in range(len(dur_l0)):
    avg_dur_l0 = avg_dur_l0 + dur_l0[i]
avg_dur_l0 = avg_dur_l0 / len(dur_l0)
for i in range(len(x_l0_timestamps_us)-1):
    avg_gap_l0 = avg_gap_l0 + x_l0_timestamps_us[i+1] - x_l0_timestamps_us[i] - dur_l0[i]
avg_gap_l0 = avg_gap_l0 / (len(x_l0_timestamps_us)-1)
# >=L1 avgs
for i in range(len(dur_l1)):
    avg_dur_l1 = avg_dur_l1 + dur_l1[i]
avg_dur_l1 = avg_dur_l1 / len(dur_l1)
for i in range(len(x_l1_timestamps_us)-1):
    avg_gap_l1 = avg_gap_l1 + x_l1_timestamps_us[i+1] - x_l1_timestamps_us[i] - dur_l1[i]
avg_gap_l1 = avg_gap_l1 / (len(x_l1_timestamps_us)-1)

print("L0 average compaction duration[secs]:",avg_dur_l0)
print("L1 average compaction duration[secs]:",avg_dur_l1)
print("L0 average time interval between two compactions[secs]:",avg_gap_l0/1000000)
print("L1 average time interval between two compactions[secs]:",avg_gap_l1/1000000)    
    
    
# write timestamps to files             
tmpf1=open('bs_big_spikes_ts.txt','w')
for ele in big_spikes_ts:
    tmpf1.write(ele.strftime("%Y-%m-%d %H:%M:%S.%f")+'\n')
tmpf1.close()
tmpf2=open('bs_non_big_spikes_ts.txt','w')
for ele in non_big_spikes_ts:
    tmpf2.write(ele.strftime("%Y-%m-%d %H:%M:%S.%f")+'\n')
tmpf2.close()
tmpf3=open('bs_small_spikes_ts.txt','w')
for ele in small_spikes_ts:
    tmpf3.write(ele.strftime("%Y-%m-%d %H:%M:%S.%f")+'\n')
tmpf3.close()
tmpf4=open('bs_non_spikes_ts.txt','w')
for ele in non_spikes_ts:
    tmpf4.write(ele.strftime("%Y-%m-%d %H:%M:%S.%f")+'\n')
tmpf4.close()

    
# plot both blustore latency and compacion
p0 = plt.figure(figsize=(28, 16), dpi= 80, facecolor='w', edgecolor='k')
ax0 = p0.add_subplot(111)
ax0.plot(x_l0_timestamps, y_l0_dummy, label='L0 compaction',marker='^', c='g', linestyle='')
ax0.plot(x_l1_timestamps, y_l1_dummy, label='>=L1 compaction',marker='d', c='r', linestyle='')
ax0.plot(x_bs_lat, y_bs_lat, label='bluestore')
ax0.set(xlabel='time stamps', ylabel='latency [secs]', title='BlueStore Latency Time Series with Compactions')
ax0.figure.savefig("p0-bslat.pdf", bbox_inches='tight')

# plot time series of big spikes
p11 = plt.figure(figsize=(28, 16), dpi= 80, facecolor='w', edgecolor='k') # big spikes
ax11 = p11.add_subplot(111)
ax11.set_ylim(0,0.2)
ax11.plot(big_spikes_ts, big_spikes_lat, label='big spikes', marker='s', c='b', linestyle='')
ax11.set(xlabel='Timestamps', ylabel='Latency[s]', title='Time Series of BlueStore Latency Big Spikes')
ax11.figure.savefig("p11-bslat-big-spikes.pdf", bbox_inches='tight')
# plot time series of NON-big-spikes
p12 = plt.figure(figsize=(28, 16), dpi= 80, facecolor='w', edgecolor='k') # NON-big-spikes
ax12 = p12.add_subplot(111)
ax12.set_ylim(0,0.2)
ax12.plot(non_big_spikes_ts, non_big_spikes_lat, label='NON-big spikes')
ax12.set(xlabel='Timestamps', ylabel='Latency[s]', title='Time Series of BlueStore Latency NON-Big-Spikes')
ax12.figure.savefig("p12-bslat-non-big-spikes.pdf", bbox_inches='tight')
# plot time series of small spikes
p21 = plt.figure(figsize=(28, 16), dpi= 80, facecolor='w', edgecolor='k') # small spikes
ax21 = p21.add_subplot(111)
ax21.set_ylim(0,0.2)
ax21.plot(small_spikes_ts, small_spikes_lat, label='small spikes', marker='s', c='g', linestyle='')
ax21.set(xlabel='Timestamps', ylabel='Latency[s]', title='Time Series of BlueStore Latency Small Spikes')
ax21.figure.savefig("p21-bslat-small-spikes.pdf", bbox_inches='tight')
# plot time series of NON-spikes
p22 = plt.figure(figsize=(28, 16), dpi= 80, facecolor='w', edgecolor='k') # NON-spikes
ax22 = p22.add_subplot(111)
ax22.set_ylim(0,0.2)
ax22.plot(non_spikes_ts, non_spikes_lat, label='NON-spikes')
ax22.set(xlabel='Timestamps', ylabel='Latency[s]', title='Time Series of BlueStore Latency NON-Spikes')
ax22.figure.savefig("p22-bslat-non-small-spikes.pdf", bbox_inches='tight')

# distributions
big_spikes_lat.sort() # big spikes distribution
non_big_spikes_lat.sort() # non-big-spikes distribution
small_spikes_lat.sort() # small spikes distribution
non_spikes_lat.sort() # non-spikes distribution

x_big_spike_cdf = [] # latency of big spikes, x-axis
y_big_spike_cdf = [] # percentage of big spikes, y-axis
x_non_big_spike_cdf = [] # latency of non big spikes, x-axis
y_non_big_spike_cdf = [] # percentage of non big spikes, y-axis
x_small_spike_cdf = [] # latency of samll spikes, x-axis
y_small_spike_cdf = [] # percentage of small spikes, y-axis
x_non_spike_cdf = [] # latency of non spikes, x-axis
y_non_spike_cdf = [] # percentage of non spikes, y-axis

if len(big_spikes_lat) != 0:
    for i in range(0, 10000, 2):
        x_big_spike_cdf.append(big_spikes_lat[int(i/10000. * len(big_spikes_lat))])
        y_big_spike_cdf.append(i/10000.)        
if len(non_big_spikes_lat) != 0:
    for i in range(0, 10000, 2):
        x_non_big_spike_cdf.append(non_big_spikes_lat[int(i/10000. * len(non_big_spikes_lat))])
        y_non_big_spike_cdf.append(i/10000.)
if len(small_spikes_lat) != 0:
    for i in range(0, 10000, 2):
        x_small_spike_cdf.append(small_spikes_lat[int(i/10000. * len(small_spikes_lat))])
        y_small_spike_cdf.append(i/10000.)        
if len(non_spikes_lat) != 0:
    for i in range(0, 10000, 2):
        x_non_spike_cdf.append(non_spikes_lat[int(i/10000. * len(non_spikes_lat))])
        y_non_spike_cdf.append(i/10000.)
        
# plot distributions
p31 = plt.figure()
ax31 = p31.add_subplot(111)
ax31.set_xscale('log')
ax31.plot(x_big_spike_cdf, y_big_spike_cdf, label='cdf of bluestore big spikes')
ax31.set(xlabel='Latency [secs]', ylabel='Cumulative Fraction', title='CDF of BlueStore Big Spike Latency')
ax31.figure.savefig("p31-cdf-big-spikes.pdf", bbox_inches='tight')
p32 = plt.figure()
ax32 = p32.add_subplot(111)
ax32.set_xscale('log')
ax32.plot(x_non_big_spike_cdf, y_non_big_spike_cdf, label='cdf of bluestore non-big spikes')
ax32.set(xlabel='Latency [secs]', ylabel='Cumulative Fraction', title='CDF of BlueStore Non-Big Spike Latency')
ax32.figure.savefig("p32-cdf-non-big-spikes.pdf", bbox_inches='tight')
p41 = plt.figure()
ax41 = p41.add_subplot(111)
ax41.set_xscale('log')
ax41.plot(x_small_spike_cdf, y_small_spike_cdf, label='cdf of bluestore small spikes')
ax41.set(xlabel='Latency [secs]', ylabel='Cumulative Fraction', title='CDF of BlueStore Small Spike  Latency')
ax41.figure.savefig("p41-cdf-small-spikes.pdf", bbox_inches='tight')
p42 = plt.figure()
ax42 = p42.add_subplot(111)
ax42.set_xscale('log')
ax42.plot(x_non_spike_cdf, y_non_spike_cdf, label='cdf of bluestore non-spikes')
ax42.set(xlabel='Latency [secs]', ylabel='Cumulative Fraction', title='CDF of BlueStore Non-Spike Latency')
ax42.figure.savefig("p42-cdf-non-small-spikes.pdf", bbox_inches='tight')

#plt.show()
plt.close()