#!/bin/bash

# ./build.sh -a architecture [-m module_version] [-k kernel_version] [-c]
#            architecture (-a): ifc | sl6
#          module_version (-m): n.m | test 
#          kernel_version (-k): 3.6.11.5          (ifc, PPC)
#                               3.6.11.5-rt37     (ifc, PPC)     <-- default for architecture ifc
#                               2.6.32-573.3.1    (SL6, x86_64)  <-- default for architecture sl6
#               configure: (-c) execute configure (needed when changing architecture)
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

 
while getopts a:m:k:c opt; do
  case $opt in
    a)
      # architecture
      if [ ! $OPTARG == 'ifc' ] && [ ! $OPTARG == 'sl6' ] 
      then
        echo "ERROR: Architecture $OPTARG is not (yet) supported!" >&2
        exit 1
      fi
      ARG_ARCH=$OPTARG
      echo "Architecture $ARG_ARCH"
      ;;
    m)
      # module version
      ARG_MODVER=$OPTARG
      if [ $ARG_MODVER == 'test' ] || [ $ARG_MODVER == 'TEST' ]; then
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
        echo "Usage: `basename $0` -a Arch [-v module_Version] [-k Kernel_version] [-c] "
        echo "                     architecture: [ifc|sl6]                      "
        echo "                   module_version: [n.m|test]                     "
        echo "                   kernel_version: 3.6.11.5          (ifc, PPC)   "
        echo "                                   3.6.11.5-rt37     (ifc, PPC)   "
        echo "                                   2.6.32-573.3.1    (SL6, x86_64)"
        echo "                        configure: execute configure (needed when changing architecture)"
        echo "-------------------------------------------------------------------------------"
        exit 1
      ;;
  esac
done

#
# =========================================================================================================
#
if [ $ARG_ARCH == 'ifc' ]; then
    KERNEL_SRC=/opt/eldk-5.2/kernel/gfa-linux-$ARG_KERNVER
    . /opt/eldk-5.2/powerpc-e500v2/environment-setup-ppce500v2-linux-gnuspe
    CROSS_COMPILE=$OECORE_NATIVE_SYSROOT/usr/libexec/ppce500v2-linux-gnuspe/gcc/powerpc-linux-gnuspe/4.6.4/

    if [ $EXEC_CFG == 1 ]; then
        dye make clean
        dye ./configure --host=powerpc-linux-gnuspe --with-linux-dir=$KERNEL_SRC \
            --disable-8139too --disable-e1000 --disable-e1000e --disable-r8169 --enable-generic \
            --prefix=/usr/local --enable-hrtimer --enable-debug-if --enable-debug-ring
    fi

    dye make all modules ARCH=powerpc CROSS_COMPILE=$CROSS_COMPILE
    RETVAL=$?
    if [ ! $RETVAL == 0 ]; then
      echo "make failed"
      exit 1
    fi
fi

if [ $ARG_ARCH == 'sl6' ]; then
    KERNEL_SRC=/usr/src/kernels/$ARG_KERNVER.el6.x86_64
     
    if [ $EXEC_CFG == 1 ]; then
        dye make clean
        dye ./configure --with-linux-dir=$KERNEL_SRC \
            --disable-8139too --disable-e1000 --disable-e1000e --disable-r8169 --enable-generic \
            --prefix=/usr/local --enable-hrtimer --enable-debug-if --enable-debug-ring
    fi
    
    dye make all modules ARCH=x86_64
    RETVAL=$?
    if [ ! $RETVAL == 0 ]; then
      echo "make failed"
      exit 1
    fi
fi 

#
# =========================================================================================================
#

ROOT_TARGET_DIR=/ioc/modules/ecat2
HOSTNAME=`hostname`

if [ ! -d "$ROOT_TARGET_DIR" ]; then
  echo "Directory ${BOLD}$ROOT_TARGET_DIR#{NC} does not exist here ($HOSTNAME)."
fi


echo "copying..."

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

cd $ROOT_TARGET_DIR

if [ ! -d $ARG_ARCH ]; then
    mkdir $ARG_ARCH
fi 
if [ ! -d $ARG_ARCH/${ARG_KERNVER} ]; then
    mkdir $ARG_ARCH/${ARG_KERNVER}
fi 
if [ ! -d $ARG_ARCH/${EC_LIB} ]; then
    mkdir $ARG_ARCH/${EC_LIB}
fi 

cp ${CURR_DIR}/master/ec_master.ko ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_MASTER_LONG}
cp ${CURR_DIR}/devices/ec_generic.ko ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_ETHERNET_LONG}
cp ${CURR_DIR}/lib/.libs/libethercat.so.1.0.0 ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH1_LONG}
cp ${CURR_DIR}/lib/.libs/libethercat.a ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH2_LONG}

cd $ARG_ARCH/$ARG_KERNVER

if [ ${TEST} = 0 ]
then
	ln -f -s ${DRV_MASTER_LONG} ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_MASTER}
	ln -f -s ${DRV_ETHERNET_LONG} ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_ETHERNET}
	cd ../$EC_LIB
	ln -f -s ${DRV_LIBETH1_LONG} ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH1}
	ln -f -s ${DRV_LIBETH1_LONG} ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/libethercat.so
	ln -f -s ${DRV_LIBETH1_LONG} ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/libethercat.so.1

	ln -f -s ${DRV_LIBETH2_LONG} ${ROOT_TARGET_DIR}/${ARG_ARCH}/${EC_LIB}/${DRV_LIBETH2}
fi

cd $CURR_DIR
echo "copy completed"
echo "-------------------------------------------------------------------------------------------"
echo -e "                  ${BOLD}Hostname${NC}: $HOSTNAME"
echo -e "              ${BOLD}Architecture${NC}: $ARG_ARCH"
echo -e "            ${BOLD}Module version${NC}: ${RED}$ARG_MODVER${NC}"
echo -e "            ${BOLD}Kernel version${NC}: $ARG_KERNVER"
if [ ${TEST} = 0 ]
then
echo "           Kernel module 1: ${DRV_MASTER_LONG} ${ROOT_TARGET_DIR}/${ARG_ARCH}/${ARG_KERNVER}/${DRV_MASTER}"
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
