#!/bin/sh
#
# Author: Dragutin Maier-Manojlovic dragutin.maier-manojlovic@psi.ch
#

# EtherCAT Ethernet device/port- eth0 or eth1
ETHERCAT_PORT=eth1


KERNEL_VERS=0
EC_VERS=0
if [ $# = 1 ]; then
	kdir=3.6.11.5-rt37
elif [ $# = 2 ]
then
	KERNEL_VERS=1
  echo -n
elif [ $# = 3 ]
then
	KERNEL_VERS=1
	EC_VERS=1
  echo -n
else
	echo "Usage: `basename $0` start [KERNEL_VERSION] [EC_VERSION] "
	echo "Usage: `basename $0` stop "
	echo "                     KERNEL_VERSION   3.6.11.5 or 3.6.11.5-rt37 (default)"
	echo "                     EC_VERSION       [a.b.c|test] (example: 2.1.4)"
	exit 1
fi

if [ $KERNEL_VERS = 1 ]; then
	kdir=${2}; kdir=${kdir%/};
fi
DRV_MASTER=${kdir}/ec_master.ko
DRV_ETH=${kdir}/ec_generic.ko

if [ $EC_VERS = 1 ]; then
	DRV_MASTER=${kdir}/ec_master-${3}.ko
	DRV_ETH=${kdir}/ec_generic-${3}.ko
fi

EC_VERS=$DRV_MASTER

EC_DEVS_CANDIDATES="eth0 eth1"
EC_DEVS=$(echo $EC_DEVS_CANDIDATES | sed "s/$(awk 'BEGIN {RS=" "; FS="[=:]"} /ip=/ {print $7}' /proc/cmdline)//")
cnt=0
for dev in $EC_DEVS
do eval MASTER$((cnt++))_DEVICE=$(/sbin/ifconfig $dev | awk '/HWaddr/ {print $5}')
done
unset cnt dev


 

case "${1}" in

start)
   echo -n "Starting EtherCAT master: "
   echo $EC_VERS

	insmod /ifc-exchange/ethercat/${DRV_MASTER} main_devices=$MASTER0_DEVICE backup_devices=""
	insmod /ifc-exchange/ethercat/${DRV_ETH}
	lsmod

#   exit_success
   ;;

stop)
    echo -n "Shutting down EtherCAT master"
    echo -n

	rmmod ec_generic.ko
	rmmod ec_master.ko
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


