# generated Wed Oct 10 09:30:05 PDT 2018
using Plots
gr()
x = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20
 ]
queue_size = [ 8295,7401,6670,3358,1271,420,38,99,33,86,70,224,37,34,12,60,50,100,26,88 ]
latency = [ 4.230949427,5.927895019,5.453533263,6.505290963,6.150138205,5.854443822,5.528287246,5.650389052,5.497249313,5.082203646,5.000380712,5.122578684,4.965349213,5.041742222,4.959055871,5.211812113,5.739264371,5.363210926,5.550273655,5.22803058 ]
plot(x, queue_size, label="op queue size (ops)", legend=:bottomleft, ylim=(0,Inf), markershape=:auto, title="Throtte NO, Iteration 1")
t = twinx()
plot!(t, x, latency, label="write latency (secs)", color=:red, legend=:bottomright, ylim=(0,Inf), title="Throtte NO, Iteration 1", markershape=:auto)
savefig("queue_size_1_NO_full.pdf")
