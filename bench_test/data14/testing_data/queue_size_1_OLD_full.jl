# generated Wed Oct 10 09:30:05 PDT 2018
using Plots
gr()
x = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20
 ]
queue_size = [ 8297,8277,7747,4338,1765,616,8,2,30,22,66,54,29,17,42,27,24,36,13,47 ]
latency = [ 4.164264763,5.933098731,6.335475808,5.637649754,5.290173943,5.493752263,5.625998302,6.451259837,5.729366081,6.26400961,5.684803338,5.768109716,5.20861778,4.816762911,5.358342389,4.837385517,5.032484671,5.44371847,4.973976374,5.853045362 ]
plot(x, queue_size, label="op queue size (ops)", legend=:bottomleft, ylim=(0,Inf), markershape=:auto, title="Throtte OLD, Iteration 1")
t = twinx()
plot!(t, x, latency, label="write latency (secs)", color=:red, legend=:bottomright, ylim=(0,Inf), title="Throtte OLD, Iteration 1", markershape=:auto)
savefig("queue_size_1_OLD_full.pdf")
