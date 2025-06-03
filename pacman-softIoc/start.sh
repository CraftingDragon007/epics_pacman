#!/bin/bash -e
# This script is used to start the pong epics soft ioc
export EPICS_DB_INCLUDE_PATH=$EPICS_BASE/dbd:$(pwd)
export PONG_PATH=$(pwd)
export EPICS_DRIVER_PATH=$PONG_PATH/O.$EPICS_HOST_ARCH:$EPICS_BASE/lib/$EPICS_HOST_ARCH
export EPICS_PATH=$EPICS_BASE
export LD_LIBRARY_PATH=$EPICS_BASE/lib/$EPICS_HOST_ARCH
export EPICS_CA_SERVER_PORT=5064

strace -o trace.txt softIoc -D $EPICS_BASE/dbd/softIoc.dbd -v $PONG_PATH/startup.script