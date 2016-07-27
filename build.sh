#!/bin/bash

# ./build.sh [-m module_version] [-k kernel_version] [-c]
#          module_version (-m): n.m | test 
#          kernel_version (-k): 3.6.11.5                   (ifc, vanilla)
#                               3.6.11.5-rt37              (ifc, PREEMPT-RT)     
#                               2.6.32-573.3.1.el6.i686    (SL6, i686)
#                               2.6.32-573.3.1.el6.x86_64  (SL6, x86_64)
#               configure (-c): execute configure (needed when changing architecture)
#
#        Note: Only one architecture (ifc, x86_64, i686, ...) can be active ("configured") at any given time
#              Also, configure has to be executed at least once for the given architecture
#
# 16.03.2016 Dragutin Maier-Manojlovic (PSI)
#
BOLD='\033[1m'
RED='\033[31m'
NC='\033[0m'

set -e

EXEC_CFG=0
TEST=0

# defaults for arguments
ARG_MODVER='test'
ARG_KERNVER='3.6.11.5-rt37'

 
while getopts m:k:c opt; do
  case $opt in
    m)
      # module version
      ARG_MODVER=$OPTARG
      if [ "$ARG_MODVER" == "test" ] || [ "$ARG_MODVER" == "TEST" ]; then
        TEST=1
      fi 
      echo "Module version $ARG_MODVER"
      ;;
    k)
      # kernel version
      ARG_KERNVER=$OPTARG
      echo "Kernel version $ARG_KERNVER"
      ;;
    c)
      # execute configure
      EXEC_CFG=1
      echo "Configure will be executed"
      ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        echo "-------------------------------------------------------------------------------"
        echo "Usage: `basename $0` [-m module_version] [-k kernel_version] [-c] "
        echo " "
        echo "                   module_version (-m): [n.m|test]        (n.m = 2.1, 2.2, etc)"
        echo "                   kernel_version (-k): 3.6.11.5          (ifc, PPC)   "
        echo "                                        3.6.11.5-rt37     (ifc, PPC)   "
        echo "                               2.6.32-573.3.1.el6.i686    (SL6, i686)   "
        echo "                               2.6.32-573.3.1.el6.x86_64  (SL6, x86_64)"
        echo "                        configure (-c): execute configure (needed when changing architecture)"
        echo " "
        echo "Note: Only one architecture (ifc, x86_64, i686, ...) can be active ("configured") at any given time"
        echo "      Also, configure has to be executed at least once for the given architecture"
        echo "-------------------------------------------------------------------------------"
        exit 1
      ;;
  esac
done



#
# =========================================================================================================
#
    
CROSS_COMPILE=""
if [ "$ARG_KERNVER" == "3.6.11.5" ] || [ "$ARG_KERNVER" == "3.6.11.5-rt37" ]; then
    KERNEL_SRC=/opt/eldk-5.2/kernel/gfa-linux-$ARG_KERNVER
    . /opt/eldk-5.2/powerpc-e500v2/environment-setup-ppce500v2-linux-gnuspe
    CROSS_COMPILE=$OECORE_NATIVE_SYSROOT/usr/libexec/ppce500v2-linux-gnuspe/gcc/powerpc-linux-gnuspe/4.6.4/
elif [ "$ARG_KERNVER" == "2.6.32-573.3.1.el6.x86_64" ] || [ "$ARG_KERNVER" == "2.6.32-573.3.1.el6.i686" ]; then
    KERNEL_SRC=/usr/src/kernels/$ARG_KERNVER
else
    echo -e "Compiling for kernel version $RED$BOLD$ARG_KERNVER$NC is not (yet) supported."
    exit 1
fi

if [ $EXEC_CFG == 1 ]; then
    if [ "$ARG_KERNVER" == "3.6.11.5" ] || [ "$ARG_KERNVER" == "3.6.11.5-rt37" ]; then
        HOST="--host=powerpc-linux-gnuspe"
    elif [ "$ARG_KERNVER" == "2.6.32-573.3.1.el6.x86_64" ] || [ "$ARG_KERNVER" == "2.6.32-573.3.1.el6.i686" ]; then
        HOST=""
    fi

    dye ./configure $HOST --with-linux-dir=$KERNEL_SRC \
        --disable-8139too --disable-e1000 --disable-e1000e --disable-r8169 --enable-generic \
        --prefix=/usr/local --enable-hrtimer --enable-debug-if --enable-debug-ring
    dye make clean
fi

MAKEARCH=""
tARCH=${ARG_KERNVER: -4}
if [ "$tARCH" == "i686" ]; then
    MAKEARCH="x86"
elif [ "$tARCH" == "6_64" ]; then
    MAKEARCH="x86_64"
elif [ "$tARCH" == "11.5" ] || [ "$tARCH" == "rt37" ]; then
    MAKEARCH="powerpc"
fi

dye make all modules ARCH=$MAKEARCH CROSS_COMPILE=$CROSS_COMPILE
RETVAL=$?
if [ $RETVAL != 0 ]; then
  echo "make failed"
  exit 1
fi

#
# =========================================================================================================
#
echo -e "-----------------------------------------------------------------------------"
echo -e
echo -e " Kernel ver. $RED$BOLD$ARG_KERNVER$NC, Master ver. $RED$BOLD$ARG_MODVER$NC"
echo -e
echo -e "-----------------------------------------------------------------------------"


ROOT_TARGET_DIR=/ioc/modules/ecat2
HOSTNAME=`hostname`

if [ ! -d "$ROOT_TARGET_DIR" ] && [ ! -d "/import$ROOT_TARGET_DIR" ]; then
  echo -e "Directory $BOLD$ROOT_TARGET_DIR$NC does not exist here ($HOSTNAME)."
  exit 1
fi



DRV_MASTER=ec_master.ko
DRV_ETHERNET=ec_generic.ko
DRV_LIBETH1=libethercat.so.1.0.0
DRV_LIBETH2=libethercat.a
DRV_MASTER_LONG=ec_master-${ARG_MODVER}.ko
DRV_ETHERNET_LONG=ec_generic-${ARG_MODVER}.ko
DRV_LIBETH1_LONG=libethercat-${ARG_MODVER}.so.1.0.0
DRV_LIBETH2_LONG=libethercat-${ARG_MODVER}.a
CURR_DIR=`pwd`
CURR_USER=`whoami`

#------------ SERVERS
server_array=( gfalc sf-lc trfcblc finlc )

for SERVER in "${server_array[@]}"
do
    echo "======================================="
    echo -e "Installing EtherCAT Master (target $BOLD$ARG_KERNVER$NC, version $BOLD$ARG_MODVER$NC) to $RED$BOLD$SERVER$NC"
    USER_AT_SERVER=${CURR_USER}@${SERVER}
    ROOT=${USER_AT_SERVER}:$ROOT_TARGET_DIR
    
    printf "Creating target directories on remote host..."
    ssh $USER_AT_SERVER "mkdir -p ${ROOT_TARGET_DIR}/master"
    ssh $USER_AT_SERVER "mkdir -p ${ROOT_TARGET_DIR}/master/${ARG_KERNVER}"
    ssh $USER_AT_SERVER "mkdir -p ${ROOT_TARGET_DIR}/master/${ARG_KERNVER}/lib"
    ssh $USER_AT_SERVER "mkdir -p ${ROOT_TARGET_DIR}/master/${ARG_KERNVER}/tool"
    ssh $USER_AT_SERVER "mkdir -p ${ROOT_TARGET_DIR}/bin"
    printf " done.\n"
    
    scp -r ${CURR_DIR}/master/ec_master.ko              ${ROOT}/master/${ARG_KERNVER}/${DRV_MASTER_LONG}
    scp -r ${CURR_DIR}/devices/ec_generic.ko            ${ROOT}/master/${ARG_KERNVER}/${DRV_ETHERNET_LONG}
    
    scp -r ${CURR_DIR}/lib/.libs/libethercat.so.1.0.0   ${ROOT}/master/${ARG_KERNVER}/lib/${DRV_LIBETH1_LONG}
    scp -r ${CURR_DIR}/lib/.libs/libethercat.a          ${ROOT}/master/${ARG_KERNVER}/lib/${DRV_LIBETH2_LONG}
    scp -r ${CURR_DIR}/tool/ethercat                    ${ROOT}/master/${ARG_KERNVER}/tool/ethercat

    scp -r ${CURR_DIR}/ec   ${ROOT}/bin/
    
    TARGET_DIR_MOD="${ROOT_TARGET_DIR}/master/${ARG_KERNVER}"
    TARGET_DIR_LIB="${ROOT_TARGET_DIR}/master/${ARG_KERNVER}/lib"
    
    
    if [ ${TEST} = 0 ]
    then
        printf "Creating links on remote host..."
        ssh $USER_AT_SERVER "ln -f -s ${TARGET_DIR_MOD}/${DRV_MASTER_LONG}    ${TARGET_DIR_MOD}/${DRV_MASTER}"
        ssh $USER_AT_SERVER "ln -f -s ${TARGET_DIR_MOD}/${DRV_ETHERNET_LONG}  ${TARGET_DIR_MOD}/${DRV_ETHERNET}"
        ssh $USER_AT_SERVER "ln -f -s ${TARGET_DIR_LIB}/${DRV_LIBETH1_LONG}   ${TARGET_DIR_LIB}/${DRV_LIBETH1}"
        ssh $USER_AT_SERVER "ln -f -s ${TARGET_DIR_LIB}/${DRV_LIBETH1_LONG}   ${TARGET_DIR_LIB}/libethercat.so"
        ssh $USER_AT_SERVER "ln -f -s ${TARGET_DIR_LIB}/${DRV_LIBETH1_LONG}   ${TARGET_DIR_LIB}/libethercat.so.1"
        ssh $USER_AT_SERVER "ln -f -s ${TARGET_DIR_LIB}/${DRV_LIBETH2_LONG}   ${TARGET_DIR_LIB}/${DRV_LIBETH2}"
        printf " done.\n"
    fi
    echo "======================================="
done



cd $CURR_DIR
echo "Installation completed"
echo "-------------------------------------------------------------------------------------------"
echo -e "                  ${BOLD}Hostname${NC}: $HOSTNAME"
echo -e "            ${BOLD}Master version${NC}: ${RED}$ARG_MODVER${NC}"
echo -e "            ${BOLD}Kernel version${NC}: $ARG_KERNVER"
if [ ${TEST} = 0 ]
then
echo "           Kernel module 1: ${TARGET_DIR_MOD}/${DRV_MASTER}"
echo "           Kernel module 2: ${TARGET_DIR_MOD}/${DRV_ETHERNET}"
echo " Userspace dynamic library: ${TARGET_DIR_LIB}/libethercat.so"
echo "  Userspace static library: ${TARGET_DIR_LIB}/${DRV_LIBETH2}"
echo "             EtherCAT tool: ${TARGET_DIR_MOD}/tool/ethercat"
echo "-------------------------------------------------------------------------------------------"
fi
if [ ${TEST} = 1 ]
then
echo "           Kernel module 1: ${TARGET_DIR_MOD}/${DRV_MASTER_LONG}"
echo "           Kernel module 2: ${TARGET_DIR_MOD}/${DRV_ETHERNET_LONG}"
echo " Userspace dynamic library: ${TARGET_DIR_LIB}/${DRV_LIBETH1_LONG}"
echo "  Userspace static library: ${TARGET_DIR_LIB}/${DRV_LIBETH2_LONG}"
echo "             EtherCAT tool: ${TARGET_DIR_MOD}/tool/ethercat"
echo "-------------------------------------------------------------------------------------------"
fi
