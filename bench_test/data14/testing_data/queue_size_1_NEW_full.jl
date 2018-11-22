# generated Wed Oct 10 09:30:05 PDT 2018
using Plots
gr()
x = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20
 ]
queue_size = [ 8314,8293,8196,8180,8180,8179,8180,8178,8182,8180,8182,8181,8180,8185,8179,8181,8183,8180,8179,8179 ]
latency = [ 4.426412219,6.84311785,7.029864345,6.507422865,5.249370589,5.811377272,5.179724159,6.109844647,5.154215656,6.124003732,5.805254157,5.652300961,5.616927891,5.517016181,5.97675631,6.334163146,5.749640826,6.189461017,5.195357276,6.645161386 ]
plot(x, queue_size, label="op queue size (ops)", legend=:bottomleft, ylim=(0,Inf), markershape=:auto, title="Throtte NEW, Iteration 1")
t = twinx()
plot!(t, x, latency, label="write latency (secs)", color=:red, legend=:bottomright, ylim=(0,Inf), title="Throtte NEW, Iteration 1", markershape=:auto)
savefig("queue_size_1_NEW_full.pdf")
