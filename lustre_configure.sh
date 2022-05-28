#!/bin/bash

source `dirname $0`/config.sh

check_pool_exist() {
	POOL_NAME=$1
	echo "Check existence zpool $POOL_NAME"
	res=`$ZFS_PATH/zpool list $POOL_NAME  | awk 'NR>1 {print $9}'`
	if [[ $res == "ONLINE" ]]; then
		echo -e "\t$POOL_NAME already exists and is online."
	fi
}

remove_zpools() {
	echo "- Remove all existing zpools:"
	words=`$ZFS_PATH/zpool import | grep pool: | cut -d ':' -sf2`
	for word in $words; do
		echo "Import zpool '$word' (To destroy it later)"
		err=`$ZFS_PATH/zpool import $word 2>&1 >/dev/null`
		if [[ ! -z $err ]]; then
			echo -e "\t Error: $err"
		fi
	done

	words=`$ZFS_PATH/zpool list | awk 'NR>1 {print $1}'`
	for word in $words; do
		echo "Clear -nFX $word"
		$ZFS_PATH/zpool clear -nFX $word
		echo "Destroy zpool: $word"
		$ZFS_PATH/zpool destroy -f $word
		echo "Clear label: $word"
		$ZFS_PATH/zpool labelclear -f $word
	done
}

set_mgs_mds() {
	$ZFS_PATH/zpool create -f -O canmount=off -o cachefile=none mgs_mds $MGS_DEVICE
	err=`$LUSTRE_PATH/mkfs.lustre --mgs --mdt --mgsnode $MGS_NID --fsname $FSNAME --index $DEFAULT_MGS_INDEX --backfstype=$BACKFSTYPE mgs_mds/mgt_mdt0 2>&1 >/dev/null`
	if [ -z "$err" ] ; then
		mkdir -p /lustre_mgt_mdt0
        echo "****************************** MGS/MDT Successfully set on $HOSTNAME ******************************"
    else
		echo "****************************** ERROR($HOSTNAME): $err ******************************"
	fi
}

set_ost() {
	NODE_INDEX=$1
	POOL_NAME="ost"$NODE_INDEX"pool"
	OST_POOL_NAME=$POOL_NAME"/ost"$NODE_INDEX
	OST_PATH="/data/lustre/ost"$NODE_INDEX

	echo "- Create zpool $POOL_NAME:"
	echo "$ZFS_PATH/zpool create -O canmount=off -o cachefile=none $POOL_NAME $DEVICES_RAID0"
	err=`$ZFS_PATH/zpool create -O canmount=off -o cachefile=none $POOL_NAME $DEVICES_RAID0`
	if [[ ! -z $err ]]; then
		DEVICES_RAID0=""
		for DEV in "${DEVICES[@]}"; do
			if [[ -z  `lsblk -o NAME  | grep $DEV` ]]; then
				DAMAGED_DEV=$DAMAGED_DEV" /dev/$DEV"
			else
				DEVICES_RAID0=$DEVICES_RAID0" /dev/$DEV"
			fi
		done
		echo -e "==> Remove unavailabe devices ($DAMAGED_DEV) from pool"
		echo "$ZFS_PATH/zpool create -O canmount=off -o cachefile=none $POOL_NAME $DEVICES_RAID0"
		$ZFS_PATH/zpool create -O canmount=off -o cachefile=none $POOL_NAME $DEVICES_RAID0 2>&1 >/dev/null
	fi
	echo "- Format zpool $OST_POOL_NAME:"
	res=`$LUSTRE_PATH/mkfs.lustre --ost --mgsnode $MGS_NID --fsname $FSNAME --index $NODE_INDEX --backfstype=$BACKFSTYPE $OST_POOL_NAME 2>&1 >/dev/null`
	echo "$LUSTRE_PATH/mkfs.lustre --ost --mgsnode $MGS_NID --fsname $FSNAME --index $NODE_INDEX --backfstype=$BACKFSTYPE $OST_POOL_NAME 2>&1 >/dev/null"
	echo "- Create ost directory $OST_PATH"
	res="$res"`mkdir -p $OST_PATH 2>&1 >/dev/null`
	if [ -z "$res" ] ; then
        echo "****************************** $HOSTNAME OSTs Successfully set ******************************"
    else
		echo "****************************** ERROR($HOSTNAME): $res ******************************"
	fi
}

FAILING_NODES=""

echo "Get list of OST servers from ost_nodes.txt"
mapfile -t ORIGINAL_SERVER_LIST < conf/ost_nodes.txt

echo "Indexing Servers"
declare -A SERVER_INDEX_MAP=()
NB_SERVERS=0
for SERVER_NAME in "${ORIGINAL_SERVER_LIST[@]}"; do
	let "NB_SERVERS=NB_SERVERS+1"
	SERVER_INDEX_MAP[$SERVER_NAME]=$NB_SERVERS
	echo -e "\t$SERVER_NAME ${SERVER_INDEX_MAP[$SERVER_NAME]}"
done

echo "Define Initial Variables"
define_vars
for var in $VARS_LIST; do
	echo -e "\t$var=${!var}"
done

SERVER_LIST=$@
if [[ " ${SERVER_LIST[@]} " =~ "--mgs" ]]; then
    SERVER_LIST=("${SERVER_LIST[@]/"--mgs"}")
    read -p "Enable MGS Configuration on $MDS_NODE, Y/N? " -n 1 -r
    echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo "Create, configure and format zpool (MGS/MDS) on local node $MDS_NODE"
	    if [ "$MDS_NODE" = "$HOSTNAME" ]; then
	    	remove_zpools
	    	set_mgs_mds
	    else
	    	ssh -o StrictHostKeyChecking=no $MDS_SSH_ADD "$(typeset -f define_vars remove_zpools set_mgs_mds); define_vars; remove_zpools; set_mgs_mds"
	    fi
	fi
fi

if [[ -z $SERVER_LIST  ]]; then
    SERVER_LIST=${ORIGINAL_SERVER_LIST[@]}
fi

read -p "Create OST on: $SERVER_LIST, Y/N? " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
	for SERVER_NAME  in $SERVER_LIST
	do
		if [ "$SERVER_NAME" = "$MDS_NODE" ]; then
			echo "You cannot configure ost on MGS node $MDS_NODE. If you want to configure the MGS use option \"--mgs\"."
			continue
		fi

		if [[ -z ${SERVER_INDEX_MAP[$SERVER_NAME]} ]]; then
			echo "$SERVER_NAME MUST be added to the OST list at the end of ost_nodes.txt"
			read -p "Append $SERVER_NAME to ost_nodes.txt file?, Y/N? " -n 1 -r
			echo
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				echo $SERVER_NAME >> ost_nodes.txt
				let "NB_SERVERS=NB_SERVERS+1"
				SERVER_INDEX_MAP[$SERVER_NAME]=$NB_SERVERS
			fi
		fi

		echo "Create, configure and format zpool (OST) on node $SERVER_NAME"
		if [ "$SERVER_NAME" = "$HOSTNAME" ]; then
			remove_zpools
			res=`set_ost  ${SERVER_INDEX_MAP[$SERVER_NAME]}`
		else
	    	res=`ssh -o StrictHostKeyChecking=no $SERVER_NAME "$(typeset -f define_vars remove_zpools set_ost); define_vars; remove_zpools; set_ost ${SERVER_INDEX_MAP[$SERVER_NAME]}"`
		fi
		echo -e "$res"
		IF_FAILED=`echo -e "$res" | awk 'NR==10 {print $4}'`
		if [[ $IF_FAILED != "Successfully" ]]; then
			FAILING_NODES="$FAILING_NODES $SERVER_NAME"
		fi
	done
fi

if [[ ! -z $FAILING_NODES ]]; then
	echo "************************************************************"
	echo "Nodes $FAILING_NODES  failed."
	echo "************************************************************"
fi
