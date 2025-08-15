TOP = .

EPICS_BASE = /usr/lib/epics

include $(EPICS_BASE)/configure/CONFIG
#----------------------------------------
#  ADD MACRO DEFINITIONS AFTER THIS LINE

LIBRARY_IOC  += pacman
DBD  += pacman.dbd
DB += pacman.db
DB += pacman_game_parameter.template


pacman_SRCS += pacman_registerRecordDeviceDriver.cpp
pacman_SRCS += pacman.st
pacman_DBD += base.dbd
pacman_LIBS += seq pv png z
pacman_LIBS += $(EPICS_BASE_IOC_LIBS)

LIBRARY_IOC  += ghosts_pacman
DBD  += ghosts_pacman.dbd
DB += pacman_ghost_parameter.template


ghosts_pacman_SRCS += ghosts_pacman_registerRecordDeviceDriver.cpp
ghosts_pacman_SRCS += ghosts_pacman.st
ghosts_pacman_DBD += base.dbd
ghosts_pacman_LIBS += seq pv png z
ghosts_pacman_LIBS += $(EPICS_BASE_IOC_LIBS)


LIBRARY_IOC += game_engine_pacman
DBD += game_engine_pacman.dbd

game_engine_pacman_SRCS += game_engine_pacman_registerRecordDeviceDriver.cpp
game_engine_pacman_SRCS += game_engine_pacman.st
game_engine_pacman_DBD += base.dbd
game_engine_pacman_LIBS += seq pv png z
game_engine_pacman_LIBS += $(EPICS_BASE_IOC_LIBS)


png_DIR = /usr/lib
z_DIR = /usr/lib


#----------------------------------------

include $(EPICS_BASE)/configure/RULES
#----------------------------------------
#  ADD RULES AFTER THIS LINE
include $(EPICS_BASE)/configure/RULES_SNCSEQ
