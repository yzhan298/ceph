#!/bin/bash

#for qd in 1 4 8 16 32 48 64 80 96 112 128 144 160 256; do
for qd in 1 4 8 16 32 256; do
	./run.sh $qd
done
