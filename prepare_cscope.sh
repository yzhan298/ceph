!#/bin/bash

# if you'd like to change the default editor(vi) to something else(eg. vim):
#export CSCOPE_EDITOR=`which vim`

find . -name "*.c" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.hpp" > cscope.files

cscope -q -R -b -i cscope.files

# start the cscope browser:
# cscope -d
