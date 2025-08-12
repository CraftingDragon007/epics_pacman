#!/bin/bash -e
# This script is used to start the pacman epics soft ioc
export EPICS_DB_INCLUDE_PATH=$EPICS_BASE/dbd:$(pwd)
export PACMAN_PATH=$(pwd)
export EPICS_DRIVER_PATH=$PACMAN_PATH/O.$EPICS_HOST_ARCH:$EPICS_BASE/lib/$EPICS_HOST_ARCH
export EPICS_PATH=$EPICS_BASE
export LD_LIBRARY_PATH=$EPICS_BASE/lib/$EPICS_HOST_ARCH
export EPICS_CA_SERVER_PORT=5064

softIoc -D $EPICS_BASE/dbd/softIoc.dbd -v $PACMAN_PATH/startup.script