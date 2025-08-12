#!/bin/bash

set -e
set -x

SWAPFILE=~/swapfile

fallocate -l 30G $SWAPFILE
chmod 600 $SWAPFILE
mkswap $SWAPFILE
swapon $SWAPFILE

sudo sysctl vm.swappiness=80
