#
# source this file into your shell to set up the environment.
# For example:
# $ . /home/yzhan298/ceph/build/vstart_environment.sh
#
export PYTHONPATH=/home/yzhan298/ceph/src/pybind:/home/yzhan298/ceph/build/lib/cython_modules/lib.2:/home/yzhan298/ceph/src/python-common:$PYTHONPATH
export LD_LIBRARY_PATH=/home/yzhan298/ceph/build/lib:$LD_LIBRARY_PATH
alias cephfs-shell=/home/yzhan298/ceph/src/tools/cephfs/cephfs-shell
