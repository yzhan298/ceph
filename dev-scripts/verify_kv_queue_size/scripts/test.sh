#!/bin/bash

iodp=12
sed -i "s/iodepth=.*/iodepth=${iodp}/g" fio_write.fio
