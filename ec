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
ARG_ARCH="ifc"
ARG_MODVER=""
ARG_ETH=""
ARG_KERNVER="$(uname -r)"

if [ "$ARG_KERNVER" == "3.6.11.5-rt37" ] || [ "$ARG_KERNVER" == "3.6.11.5" ]; then
    ARG_ARCH="ifc"
fi

if [ "$ARG_KERNVER" == "2.6.32-573.3.1.el6.i686" ] || [ "$ARG_KERNVER" == "2.6.32-573.3.1.el6.x86_64" ]; then
    ARG_ARCH="sl6"
fi


OPTIND=2
while getopts m:e: opt; do
  case $opt in
    m)
      # module version
      ARG_MODVER=$OPTARG
      echo "Module version $ARG_MODVER"
      ;;
    e)
      # eth port nr
      ARG_ETH=$OPTARG
      echo "Ethernet port nr. $ARG_ETH"
      ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        echo "-------------------------------------------------------------------------------"
        echo "Usage: `basename $0` start [-m module_version] [-e ethernet_port_nr]  "
        echo "Usage: `basename $0` stop                 "
        echo "Usage: `basename $0` restart              "
        echo "module_version (-m): n.m | test           " 
        echo "ethernet_port_nr (-e): 0, 1, 2,...        " 
        echo "-------------------------------------------------------------------------------"
        exit 1
      ;;
  esac
done

#
# =========================================================================================================
#
KMOD_BASEDIR='/ioc/modules/ecat2'
KMOD_DIR=$KMOD_BASEDIR/$ARG_ARCH/$ARG_KERNVER

if [ "$ARG_MODVER" != "" ]; then
    ARG_MODVER="-$ARG_MODVER"
fi

DRV_MASTER=$KMOD_DIR/ec_master$ARG_MODVER.ko
DRV_ETH=$KMOD_DIR/ec_generic$ARG_MODVER.ko

#
# =========================================================================================================
#

if [ "$ARG_ARCH" == "ifc" ]; then
    if [ "$ARG_ETH" != "" ]; then
        EC_DEVS="eth$ARG_ETH"
    else
        EC_DEVS_CANDIDATES="eth0 eth1"
        EC_DEVS=$(echo $EC_DEVS_CANDIDATES | sed "s/$(awk 'BEGIN {RS=" "; FS="[=:]"} /ip=/ {print $7}' /proc/cmdline)//")
    fi
    cnt=0
    for dev in $EC_DEVS
        do eval MASTER$((cnt++))_DEVICE=$(/sbin/ifconfig $dev | awk '/HWaddr/ {print $5}')
        done
    unset cnt dev
else
    EC_DEVS="eth1"
    if [ "$ARG_ETH" != "" ]; then
    	EC_DEVS="eth$ARG_ETH"
    fi
    cnt=0
    for dev in $EC_DEVS
        do eval MASTER$((cnt++))_DEVICE=$(/sbin/ifconfig $dev | awk '/HWaddr/ {print $5}')
        done
    unset cnt dev
    
fi

echo -e "Starting EtherCAT master on interface $BOLD$EC_DEVS$NC MAC $BOLD$MASTER0_DEVICE$NC"


case "${1}" in

start)
    RES="$(cat /proc/modules | grep -w ec_master)"
    if [ "$RES" == "" ]; then

		echo " "
        if [ ! -f $DRV_MASTER ]; then
            echo -e "File $BOLD$DRV_MASTER$NC does not exist or not accessible. Check driver installation."
            exit 1
        fi
        if [ ! -f $DRV_ETH ]; then
            echo -e "File $BOLD$DRV_ETH$NC does not exist or not accessible. Check driver installation."
            exit 1
        fi
            echo -e "Loading module $BOLD$DRV_MASTER $ARG_MODVER$NC"
            sudo insmod $DRV_MASTER main_devices=$MASTER0_DEVICE backup_devices=""
            if [ $? != 0 ]; then
              echo -e "$REDLoading kernel module $BOLD$DRV_MASTER$NC$RED failed.$NC"
              exit 1
            fi
          
        RES="$(cat /proc/modules | grep -w ec_generic)"
        if [ "$RES" == "" ]; then
    
            echo -e "Loading module $BOLD$DRV_ETH$NC"
            sudo insmod $DRV_ETH
            if [ $? != 0 ]; then
              echo -e "$REDLoading kernel module $BOLD$DRV_ETH$NC$RED failed.$NC"
              exit 1
            fi
        fi

        echo -e "Done.\n"
    else
        echo -e "EtherCAT kernel modules already loaded."
    fi

    if [ -f /usr/local/bin/ethercat ]; then
        /usr/local/bin/ethercat version
    fi
    
#   exit_success
   ;;

stop)
    echo -e "Shutting down EtherCAT master:\n"

    RES="$(cat /proc/modules | grep -w ec_generic)"
    if [ "$RES" != "" ]; then
        echo -e "Step 1 from 2: Unloading kernel module ${BOLD}ec_generic.ko$NC"
        sudo rmmod ec_generic.ko
    else
        echo -e "Step 1 from 2: Kernel module ${BOLD}ec_generic.ko$NC already unloaded."
    fi

    RES="$(cat /proc/modules | grep -w ec_master)"
    if [ "$RES" != "" ]; then
        echo -e "Step 2 from 2: Unloading kernel module ${BOLD}ec_master.ko$NC"
    	sudo rmmod ec_master.ko
    else
        echo -e "Step 2 from 2: Kernel module ${BOLD}ec_master.ko$NC already unloaded."
    fi

	echo -e "Done.\n"
	#lsmod
	

#    exit_success
    ;;

restart)
    $0 stop || exit 1
    sleep 1
    $0 start
    ;;

*)
        echo "-------------------------------------------------------------------------------"
        echo "Usage: `basename $0` start [-m module_version] [-k kernel_version]  "
        echo "Usage: `basename $0` stop "
        echo "Usage: `basename $0` restart "
        echo "module_version (-m): n.m | test" 
        echo "ethernet_port_nr (-e): 0, 1, 2,..."
        exit 1
    ;;

esac






















