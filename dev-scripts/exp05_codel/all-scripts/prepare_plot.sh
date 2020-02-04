#!/bin/bash

# prepare the pyplot 
sudo apt install python-numpy
sudo apt install python-scipy
sudo apt install python-matplotlib

# Matplotlib chooses Xwindows backend by default. You need to set matplotlib to not use the Xwindows backend.
echo "backend: Agg" > ~/.config/matplotlib/matplotlibrc

# Or when connect to server use ssh -X remoteMachine command to use Xwindows.
#export DISPLAY=mymachine.com:0.0
