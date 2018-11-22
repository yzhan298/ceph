# generated Wed Nov 21 09:53:54 PST 2018
using Plots
gr()
x = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20
 ]
queue_size = [ 315,115,200,164,94,98,35,0,0,0,0,0,0,0,0,0,0,0,0,3 ]
latency = [ 1.038448921,0.731839438,1.029426044,0.650624562,0.935397563,0.685681923,1.102365044,0.640647556,0.715697857,3.162728436,1.076259345,0.665884814,2.294318458,3.050251586,0.939020048,0.575366871,2.278561737,3.485038601,1.057212021,0.607001402 ]
plot(x, queue_size, label="op queue size (ops)", legend=:bottomleft, ylim=(0,Inf), markershape=:auto, title="Throtte NEW, Iteration 1")
t = twinx()
plot!(t, x, latency, label="write latency (secs)", color=:red, legend=:bottomright, ylim=(0,Inf), title="Throtte NEW, Iteration 1", markershape=:auto)
savefig("queue_size_1_NEW_full.pdf")
