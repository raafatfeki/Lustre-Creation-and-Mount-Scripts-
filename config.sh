#!/bin/bash
#

define_vars() {
	################### User Defined  ###################
	LUSTRE_PATH="/opt/lustre/2.12.2/sbin/"
	ZFS_PATH="/opt/zfs/0.7.13/usr/sbin/"
	SPL_PATH="/opt/spl/0.7.13/sbin/"

	MDS_SSH_ADD="crilladm2.pstl.uh.edu"
	MDS_NODE="crilladm2"
	MGS_DEVICE="/dev/nvme0n1p1"
	DEFAULT_MGS_INDEX=0

	FSNAME=lustre
	BACKFSTYPE=zfs
	DEVICES=(sdb2 sdc2)

	MDS_POOL="mgs_mds/mgt_mdt0"
	MDS_SSH_ADD="MDS_URL_FOR_SSH"
	MDS_NODE="MDS_NODE_NAME"
	MDT_MOUNT_PATH="/lustre_mgt_mdt0"
	FSNAME=lustre
	CLIENT_MOUNT="/mnt/lustre/"
	MOUNT_LINK="/lustre"

	KERNEL_VERSION="4.4.79-18.26"
	SOURCE_NODE_NAME="crill"
	LNET_CONF="options lnet networks=tcp1(ib0)" # From /etc/modprobe.d/lustre.conf

	################### Do NOT change  ###################
	export PATH=$PATH:$ZFS_PATH:$LUSTRE_PATH:$SPL_PATH
	if [ "$HOSTNAME" = "$MDS_NODE" ]; then
		MGS_NID=`lctl list_nids`
	else
		MGS_NID=`ssh -o StrictHostKeyChecking=no $MDS_SSH_ADD 'lctl list_nids '`
	fi

	DEVICES_RAID0=""
	for DEV in "${DEVICES[@]}"; do
		DEVICES_RAID0="$DEVICES_RAID0 /dev/$DEV"
	done

	VARS_LIST="ZFS_PATH LUSTRE_PATH SPL_PATH MDS_SSH_ADD MDS_NODE MGS_NID MGS_DEVICE DEFAULT_MGS_INDEX FSNAME BACKFSTYPE DEVICES_RAID0"
}
