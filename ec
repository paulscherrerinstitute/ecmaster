#!/bin/sh
#
# 14.04.2016 Dragutin Maier-Manojlovic (PSI)
#

# EtherCAT Ethernet device/port- eth0 or eth1
ETHERCAT_PORT=eth1


BOLD='\033[1m'
RED='\033[31m'
NC='\033[0m'

EXEC_CFG=0
TEST=0

# defaults for arguments
ARG_ARCH='ifc'
ARG_MODVER=''
ARG_KERNVER='3.6.11.5-rt37'

OPTIND=2
while getopts m:k: opt; do
  case $opt in
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
    \?)
        echo "Invalid option: -$OPTARG" >&2
        echo "-------------------------------------------------------------------------------"
        echo "Usage: `basename $0` start [-m module_version] [-k kernel_version]  "
        echo "Usage: `basename $0` stop "
        echo "module_version (-m): n.m | test" 
        echo "kernel_version (-k): 3.6.11.5          (ifc, PPC)"
        echo "                     3.6.11.5-rt37     (ifc, PPC)     <-- default for architecture ifc"
        echo "                     2.6.32-573.3.1    (SL6, x86_64)  <-- default for architecture sl6"
        exit 1
        echo "-------------------------------------------------------------------------------"
        exit 1
      ;;
  esac
done

#
# =========================================================================================================
#
KMOD_BASEDIR='/ioc/modules/ecat2'
if [ "$ARG_ARCH" == "ifc" ]; then
    KMOD_DIR=$KMOD_BASEDIR/ifc/$ARG_KERNVER
fi

if [ "$ARG_ARCH" == "sl6" ]; then
    KMOD_DIR=$KMOD_BASEDIR/sl6/$ARG_KERNVER
fi

if [ "$ARG_MODVER" != "" ]; then
    ARG_MODVER="-$ARG_MODVER"
fi

DRV_MASTER=$KMOD_DIR/ec_master$ARG_MODVER.ko
DRV_ETH=$KMOD_DIR/ec_generic$ARG_MODVER.ko

#
# =========================================================================================================
#

EC_DEVS_CANDIDATES="eth0 eth1"
EC_DEVS=$(echo $EC_DEVS_CANDIDATES | sed "s/$(awk 'BEGIN {RS=" "; FS="[=:]"} /ip=/ {print $7}' /proc/cmdline)//")
cnt=0
for dev in $EC_DEVS
    do eval MASTER$((cnt++))_DEVICE=$(/sbin/ifconfig $dev | awk '/HWaddr/ {print $5}')
    done
unset cnt dev

case "${1}" in

start)
   RES="$(lsmod | grep ec_master)"


    if [ "$RES" == "" ]; then

        echo -n "Starting EtherCAT master: "
        echo $ARG_MODVER
        echo -n
    
        echo -e "Loading module $DRV_MASTER"
        insmod $DRV_MASTER main_devices=$MASTER0_DEVICE backup_devices=""
        echo -e "Loading module $DRV_ETH"
        insmod $DRV_ETH
    fi
    echo -e "Done.\n"

    echo "Currently loaded EtherCAT modules:"
    RES="$(lsmod | grep ec_)"
    echo -e "$RES\n"

    #echo -e "\n"
    
    ethercat version

#   exit_success
   ;;

stop)
    echo -e "Shutting down EtherCAT master:\n"

    RES="$(lsmod | grep ec_generic)"
    if [ "$RES" != "" ]; then
        echo -e "Step 1 from 2: Unloading ec_generic.ko"
        rmmod ec_generic.ko
    fi

    RES="$(lsmod | grep ec_master)"
    if [ "$RES" != "" ]; then
        echo -e "Step 2 from 2: Unloading ec_master.ko"
    	rmmod ec_master.ko
	fi

	echo -e "Done.\n"
	lsmod
	

#    exit_success
    ;;

restart)
    $0 stop || exit 1
    sleep 1
    $0 start
    ;;

*)
    echo "USAGE: $0 {start|stop|restart}"
    ;;

esac






















