#!/bin/bash

#install all deps for runing my experiments

./prepare_fio.sh
./prepare_git.sh
../../install-deps.sh

sudo apt-get install cscope


./prepare_plot.sh
