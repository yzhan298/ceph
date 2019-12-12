#!/bin/bash

# prepare fio
sudo apt-get update
sudo apt-get install librbd-dev
cd ~
git clone https://github.com/axboe/fio.git
cd fio
./configure
make -j $(nproc)
sudo make install
fio --enghelp
