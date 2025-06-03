include /ioc/tools/driver.makefile
EPICS_VERSIONS=7.0.7
ARCH_FILTER=RHEL7-x86_64
BUILDCLASSES += Linux


TOP = ../..

#include $(TOP)/configure/CONFIG
#----------------------------------------
#  ADD MACRO DEFINITIONS AFTER THIS LINE
#  include $(TOP)/common/src/BUILDVERSION
#  include $(TOP)/common/src/CONFIG_SNC
#
#  SRC_DIRS += $(TOP)/Common/src/
#
#
#
#  LIBRARY_IOC  += camcontrol
#  DBD  += camcontrol.dbd
#  DB += camcontrol.db
#  DB += inhibit_TOMCAT.template
#
#pacman_ioc_SRCS += pacman_ioc.st
#pacman_ioc_LIBS += seq pv
pacman_ioc_LIBS += $(EPICS_BASE_IOC_LIBS)
#
#  #----------------------------------------
SOFTIOCWIN_DESC = pacman game
SOFTIOCWIN_COMMENT = pacman

#----------------------------------------
#include $(TOP)/common/src/BUILDFILES

#nclude $(TOP)/configure/RULES
#----------------------------------------
#  ADD RULES AFTER THIS LINE
#  include $(TOP)/common/src/RULES_SNC
#  include $(TOP)/common/src/BUILDVERSIONRULES
#
