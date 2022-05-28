#!/bin/bash

source `dirname $0`/config.sh

define_vars

##############################################################################################
#											MGS/MDS 										 #
##############################################################################################

mount_mgsmds() {
	echo "***************** Mount (MDS/MGS) $MDS_NODE *****************"

	res=`ssh $MDS_SSH_ADD "df | grep $MDS_POOL"`
	if [ ! -z "$res" ] ; then
		echo "MGS/MDS is already mounted"
	else
		echo "Mount MGS and MDS(mdt0) on $MDS_NODE"
		ssh $MDS_SSH_ADD "mount -t $FSNAME $MDS_POOL $MDT_MOUNT_PATH"
	fi

	res=`ssh $MDS_SSH_ADD "df | grep $MDS_POOL"`
	if [ -z "$res" ] ; then
		echo "ERROR: MGS/MDS is not mounted"
		exit
	fi

	echo "Update /proc/fs/lustre/mdt/lustre-MDT0000/identity_upcall to the right path to l_getidentity"
	ssh $MDS_SSH_ADD "echo /opt/lustre/2.12.2/sbin/l_getidentity > /proc/fs/lustre/mdt/lustre-MDT0000/identity_upcall"
}

umount_mgsmds() {
	echo "***************** Unmount $MDS_NODE *****************"

	res=`ssh $MDS_SSH_ADD "df | grep $MDS_POOL"`
	if [ -z "$res" ] ; then
		echo "MGS/MDS is already unmounted"
	else
		echo "Unmount MGS and MDS(mdt0) on $MDS_NODE"
		ssh $MDS_SSH_ADD "umount -t $FSNAME $MDS_POOL"
	fi
}

##############################################################################################
#											OSTs 										     #
##############################################################################################

mount_osts() {
	echo "***************** Mount OSTs *****************"

	INDEX=0
	for SERVER_NAME  in `cat conf/ost_nodes.txt`
	do
		# INDEX=$((10#`echo $SERVER_NAME | cut -d"-" -sf2`))
		let "INDEX=INDEX+1"
		OST_POOL=ost"$INDEX"pool/ost"$INDEX"
		OST_MOUNT=/data/lustre/ost"$INDEX"
		echo "***************** Mount $OST_POOL on $SERVER_NAME *****************"
		ssh $SERVER_NAME "mount -o default,flock -t lustre $OST_POOL $OST_MOUNT"
	done
}

umount_osts() {
	echo "***************** Unmount OSTs *****************"

	INDEX=0
	for SERVER_NAME  in `cat conf/ost_nodes.txt`
	do
		# INDEX=$((10#`echo $SERVER_NAME | cut -d"-" -sf2`))
		let "INDEX=INDEX+1"
		OST_POOL=ost"$INDEX"pool/ost"$INDEX"
		echo "***************** Unmount $OST_POOL on $SERVER_NAME *****************"
		ssh $SERVER_NAME "umount -t lustre $OST_POOL"
	done
}

##############################################################################################
#											Clients										     #
##############################################################################################

mount_clients() {
	echo "***************** Mount Clients *****************"

	FAILED_MOUNT_NODE=""

	for CLIENT_NAME  in `cat conf/client_nodes.txt`
	do
	        echo "***************** Mount client on $CLIENT_NAME *****************"

	        if [ "$HOSTNAME" = "$CLIENT_NAME" ]; then
	        	if test ! -d $CLIENT_MOUNT; then mkdir $CLIENT_MOUNT; fi
				if test ! -L $MOUNT_LINK; then ln -s $CLIENT_MOUNT $MOUNT_LINK; fi
				echo "mount -o rw,flock,user_xattr,lazystatfs -t lustre $MGS_NID:/$FSNAME $CLIENT_MOUNT"
				mount -o rw,flock,user_xattr,lazystatfs -t lustre $MGS_NID:/$FSNAME $CLIENT_MOUNT
				res=`df | grep /mnt/lustre`
				if [ -z "$res" ]; then
			        FAILED_MOUNT_NODE=$FAILED_MOUNT_NODE" crill"
				fi
	    	else
		        ssh $CLIENT_NAME "if test ! -d $CLIENT_MOUNT; then mkdir $CLIENT_MOUNT; fi"
		        ssh $CLIENT_NAME "if test ! -L $MOUNT_LINK; then ln -s $CLIENT_MOUNT $MOUNT_LINK; fi"
		        ssh $CLIENT_NAME "mount -o rw,flock,user_xattr,lazystatfs -t lustre $MGS_NID:/$FSNAME $CLIENT_MOUNT"
		        res=`ssh $CLIENT_NAME 'df | grep /mnt/lustre'`
		        if [ -z "$res" ]; then
	                FAILED_MOUNT_NODE=$FAILED_MOUNT_NODE" $CLIENT_NAME"
		        fi
		    fi
	done

	chmod 777 $CLIENT_MOUNT

	if [ ! -z "$FAILED_MOUNT_NODE" ]; then
	        echo "********************************************************************"
	        echo "Mounting failed in Nodes: $FAILED_MOUNT_NODE "
	fi
}

umount_clients() {
	OPTIONS=""

	if [ ! -z $1 ] && [ "$1" = "-l" ]; then
	    echo "Lazy Unmount "
	    OPTIONS=$1
	fi

	echo "***************** Unmount Clients *****************"
	for CLIENT_NAME  in `cat conf/client_nodes.txt`
	do
		echo "***************** Unmount client on $CLIENT_NAME *****************"
		if [ "$HOSTNAME" = "$CLIENT_NAME" ]; then
			umount $OPTIONS -t lustre $CLIENT_MOUNT
		else
			ssh $CLIENT_NAME "umount $OPTIONS -t lustre $CLIENT_MOUNT"
		fi
	done
}

umount_clients -l
umount_osts
umount_osts
umount_mgsmds
mount_mgsmds
mount_osts
mount_clients

