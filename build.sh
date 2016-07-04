#!/bin/bash

# ./build.sh [-a architecture] [-m module_version] [-k kernel_version] [-c]
#          module_version (-m): n.m | test 
#          kernel_version (-k): 3.6.11.5                   (ifc, vanilla)
#                               3.6.11.5-rt37              (ifc, PREEMPT-RT)     
#                               2.6.32-573.3.1.el6.i686    (SL6, i686)
#                               2.6.32-573.3.1.el6.x86_64  (SL6, x86_64)
#               configure (-c): execute configure (needed when changing architecture)
#
# Note: Only one architecture (ifc or sl6) can be active ("configured") at any given time
#       Also, configure has to be executed at least once for the given architecture
#
# 16.03.2016 Dragutin Maier-Manojlovic (PSI)
#
BOLD='\033[1m'
RED='\033[31m'
NC='\033[0m'

EXEC_CFG=0
TEST=0

# defaults for arguments
ARG_ARCH='ifc'
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
        echo "Usage: `basename $0` [-a architecture] [-m module_version] [-k kernel_version] [-c] "
        echo " "
        echo "                   module_version (-m): [n.m|test]        (n.m = 2.1, 2.2, etc)"
        echo "                   kernel_version (-k): 3.6.11.5          (ifc, PPC)   "
        echo "                                        3.6.11.5-rt37     (ifc, PPC)   "
        echo "                               2.6.32-573.3.1.el6.i686    (SL6, i686)   "
        echo "                               2.6.32-573.3.1.el6.x86_64  (SL6, x86_64)"
        echo "                        configure (-c): execute configure (needed when changing architecture)"
        echo " "
        echo "Note: Only one architecture (ifc or sl6) can be active ("configured") at any given time"
        echo "      Also, configure has to be executed at least once for the given architecture"
        echo "-------------------------------------------------------------------------------"
        exit 1
      ;;
  esac
done


tARCH=${ARG_KERNVER: -4}

if [ "$tARCH" == "11.5" ] || [ "$tARCH" == "rt37" ]; then
  ARG_ARCH="ifc"
fi
if [ "$tARCH" == "i686" ] || [ "$tARCH" == "6_64" ]; then
  ARG_ARCH="sl6"
fi
#
# =========================================================================================================
#
if [ "$ARG_ARCH" == "ifc" ]; then
    KERNEL_SRC=/opt/eldk-5.2/kernel/gfa-linux-$ARG_KERNVER
    . /opt/eldk-5.2/powerpc-e500v2/environment-setup-ppce500v2-linux-gnuspe
    CROSS_COMPILE=$OECORE_NATIVE_SYSROOT/usr/libexec/ppce500v2-linux-gnuspe/gcc/powerpc-linux-gnuspe/4.6.4/

    if [ $EXEC_CFG == 1 ]; then
        echo -e "-------------------------------------------------"
        echo -e "Cleaning..."
        dye make clean
        echo -e "Cleaning done."
        echo -e "-------------------------------------------------"
        dye ./configure --host=powerpc-linux-gnuspe --with-linux-dir=$KERNEL_SRC \
            --disable-8139too --disable-e1000 --disable-e1000e --disable-r8169 --enable-generic \
            --prefix=/usr/local --enable-hrtimer --enable-debug-if --enable-debug-ring
    fi

    dye make all modules ARCH=powerpc CROSS_COMPILE=$CROSS_COMPILE
    RETVAL=$?
    if [ $RETVAL != 0 ]; then
      echo "make failed"
      exit 1
    fi
fi

if [ "$ARG_ARCH" == "sl6" ]; then
    KERNEL_SRC=/usr/src/kernels/$ARG_KERNVER
     
    if [ $EXEC_CFG == 1 ]; then
        echo -e "-------------------------------------------------"
        echo -e "Cleaning..."
        dye make clean
        echo -e "Cleaning done."
        echo -e "-------------------------------------------------"
        dye ./configure --with-linux-dir=$KERNEL_SRC \
            --disable-8139too --disable-e1000 --disable-e1000e --disable-r8169 --enable-generic \
            --prefix=/usr/local --enable-hrtimer --enable-debug-if --enable-debug-ring
    fi
    
    if [ "tARCH" == "i686" ]; then
        ARCH="i686"
    fi
    if [ "tARCH" == "6_64" ]; then
        ARCH="x86_64"
    fi

    dye make all modules $ARCH
    RETVAL=$?
    if [ $RETVAL != 0 ]; then
      echo "make failed"
      exit 1
    fi
fi 

#
# =========================================================================================================
#
echo -e "-----------------------------------------------------------------------------"
echo -e
echo -e " Architecture $RED$BOLD$ARG_ARCH$NC, Kernel ver. $RED$BOLD$ARG_KERNVER$NC, Master ver. $RED$BOLD$ARG_MODVER$NC"
echo -e
echo -e "-----------------------------------------------------------------------------"


ROOT_TARGET_DIR=/ioc/modules/ecat2
HOSTNAME=`hostname`

if [ ! -d "$ROOT_TARGET_DIR" ] && [ ! -d "/import$ROOT_TARGET_DIR" ]; then
  echo -e "Directory $BOLD$ROOT_TARGET_DIR$NC does not exist here ($HOSTNAME)."
  exit 1
fi



EC_LIB=lib
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
    echo -e "Installing EtherCAT Master (target $BOLD$ARG_ARCH$NC $BOLD$ARG_KERNVER$NC, version $BOLD$ARG_MODVER$NC) to $RED$BOLD$SERVER$NC"
    USER_AT_SERVER=${CURR_USER}@${SERVER}
    ROOT=${USER_AT_SERVER}:$ROOT_TARGET_DIR
    
    echo "Creating directories..."
    ssh $USER_AT_SERVER "mkdir -p ${ROOT_TARGET_DIR}/${ARG_ARCH}"
    ssh $USER_AT_SERVER "mkdir -p ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}"
    ssh $USER_AT_SERVER "mkdir -p ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}"
    ssh $USER_AT_SERVER "mkdir -p ${ROOT_TARGET_DIR}/bin"
    echo "...done"
    
    echo "Copying kernel modules..."
    scp -r ${CURR_DIR}/master/ec_master.ko              ${ROOT}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_MASTER_LONG}
    scp -r ${CURR_DIR}/devices/ec_generic.ko            ${ROOT}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_ETHERNET_LONG}
    echo "...done"
    echo "Copying libraries..."
    scp -r ${CURR_DIR}/lib/.libs/libethercat.so.1.0.0   ${ROOT}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH1_LONG}
    scp -r ${CURR_DIR}/lib/.libs/libethercat.a          ${ROOT}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH2_LONG}
    echo "...done"
    echo "Copying ec script..."
    scp -r ${CURR_DIR}/ec   ${ROOT}/bin/
    echo "...done"
    
    if [ ${TEST} = 0 ]
    then
        echo "Creating links..."
        ssh $USER_AT_SERVER "ln -f -s ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_MASTER_LONG}      ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_MASTER}"
        ssh $USER_AT_SERVER "ln -f -s ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_ETHERNET_LONG}    ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_ETHERNET}"
        ssh $USER_AT_SERVER "ln -f -s ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH1_LONG}          ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH1}"
        ssh $USER_AT_SERVER "ln -f -s ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH1_LONG}          ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/libethercat.so"
        ssh $USER_AT_SERVER "ln -f -s ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH1_LONG}          ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/libethercat.so.1"
        ssh $USER_AT_SERVER "ln -f -s ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH2_LONG}          ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH2}"
        echo "...done"
    fi
    echo "======================================="
done



cd $CURR_DIR
echo "Installation completed"
echo "-------------------------------------------------------------------------------------------"
echo -e "                  ${BOLD}Hostname${NC}: $HOSTNAME"
echo -e "              ${BOLD}Architecture${NC}: $ARG_ARCH"
echo -e "            ${BOLD}Module version${NC}: ${RED}$ARG_MODVER${NC}"
echo -e "            ${BOLD}Kernel version${NC}: $ARG_KERNVER"
if [ ${TEST} = 0 ]
then
echo "           Kernel module 1: ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_MASTER}"
echo "           Kernel module 2: ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_ETHERNET}"
echo " Userspace dynamic library: ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/libethercat.so"
echo "  Userspace static library: ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH2}"
echo "-------------------------------------------------------------------------------------------"
fi
if [ ${TEST} = 1 ]
then
echo "           Kernel module 1: ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_MASTER_LONG}"
echo "           Kernel module 2: ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_ETHERNET_LONG}"
echo " Userspace dynamic library: ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH1_LONG}"
echo "  Userspace static library: ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH2_LONG}"
echo "-------------------------------------------------------------------------------------------"
fi
