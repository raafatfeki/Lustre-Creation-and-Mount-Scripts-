#!/bin/bash

source `dirname $0`/config.sh

define_vars

FAILED_INSTALL=""

install_remote_node() {
	if [[ -z "$1" ]]; then
		echo "Missing args: Remote Node Name"
		exit
	fi

	REMOTE_NODE=$1
	echo "****************************** $REMOTE_NODE ******************************"
	if [ "$REMOTE_NODE" = "$SOURCE_NODE_NAME" ]; then
		echo "Info: This is the source node (Already installed here)"
		exit
	fi

	echo "Unload lustre, zfs and spl"
	ssh $REMOTE_NODE '/opt/lustre/2.12.2/sbin/lustre_rmmod'
	ssh $REMOTE_NODE 'modprobe -r zfs'
	ssh $REMOTE_NODE 'modprobe -r spl'

	echo "Rsync spl installation"
	rsync -alp /opt/spl $REMOTE_NODE:/opt/

	echo "Rsync zfs installation"
	rsync -alp /opt/zfs $REMOTE_NODE:/opt/
	echo "Rsync /etc/zfs/"
	rsync -alp /etc/zfs $REMOTE_NODE:/etc/

	echo "Rsync lustre installation"
	rsync -alp /opt/lustre $REMOTE_NODE:/opt/
	echo "Rsync linux/lustre headers"
	rsync -alp /usr/include/linux/lustre $REMOTE_NODE:/usr/include/linux/
	echo "Rsync linux/lnet headers"
	rsync -alp /usr/include/linux/lnet $REMOTE_NODE:/usr/include/linux/

	echo "Rsync /sbin/mount.lustre"
	rsync -alp /sbin/mount.lustre $REMOTE_NODE:/sbin/

	echo "Rsync /usr/lib/systemd/system/lnet.service"
	rsync -alp /usr/lib/systemd/system/lnet.service $REMOTE_NODE:/usr/lib/systemd/system/
	echo "Rsync /etc/ha.d Directory"
	rsync -alp /etc/ha.d $REMOTE_NODE:/etc/

	echo "Rsync /etc/lnet.conf"
	rsync -alp /etc/lnet.conf $REMOTE_NODE:/etc/

	echo "Rsync /etc/ldev.conf"
	rsync -alp /etc/ldev.conf $REMOTE_NODE:/etc/

	echo "Rsync /etc/lnet_routes.conf"
	rsync -alp /etc/lnet_routes.conf $REMOTE_NODE:/etc/

	echo "Rsync /etc/udev/rules.d/99-lustre-server.rules"
	rsync -alp /etc/udev/rules.d/99-lustre-server.rules $REMOTE_NODE:/etc/udev/rules.d/

	echo "Rsync /etc/udev/rules.d/99-lustre.rules"
	rsync -alp /etc/udev/rules.d/99-lustre.rules $REMOTE_NODE:/etc/udev/rules.d/

	echo "Add library paths and update it"
	ssh $REMOTE_NODE 'echo "/opt/zfs/0.7.13/usr/lib64/" >> /etc/ld.so.conf.d/lustre.conf'
	ssh $REMOTE_NODE 'ldconfig'

	# Those two files are needed to configure Lnet and infiniBand support for lustre:
	# You probably need to set them when needed.
	# 	/etc/modprobe.d/lustre.conf
	# 	/etc/modprobe.d/ko2iblnd.conf

	echo "Setting lnet (static conf) in /etc/modprobe.d/lustre.conf"
	ssh $REMOTE_NODE 'echo "options lnet networks=tcp1(ib0)" > /etc/modprobe.d/lustre.conf'

	echo "Rsync spl and zfs modules"
	rsync -alp /lib/modules/"$KERNEL_VERSION"-default/extra $REMOTE_NODE:/lib/modules/"$KERNEL_VERSION"-default/
	echo "Rsync lustre modules"
	rsync -alp /lib/modules/"$KERNEL_VERSION"-default/updates/kernel $REMOTE_NODE:/lib/modules/"$KERNEL_VERSION"-default/updates/

	echo "Update modules.dep file etc .."
	ssh -o StrictHostKeyChecking=no $REMOTE_NODE 'depmod -a'

	echo "Load ZFS"
	result=`ssh -o StrictHostKeyChecking=no $REMOTE_NODE 'modprobe zfs' 2>&1`
	if [ ! -z "$result" ] ; then
		echo "ERROR: You have a problem"
		echo "$result"
		FAILED_INSTALL=$FAILED_INSTALL" $REMOTE_NODE"
		return
	fi
	echo "Load LUSTRE"
	result=`ssh -o StrictHostKeyChecking=no $REMOTE_NODE 'modprobe lustre' 2>&1`
	if [ -z "$result" ] ; then
		echo "****************************** $REMOTE_NODE Successfully installed ******************************"
	else
		echo "****************************** ERROR: You have a problem with $REMOTE_NODE ******************************"
		echo "$result"
		FAILED_INSTALL=$FAILED_INSTALL" $REMOTE_NODE"
	fi
}

install_local_node() {
	if [ "$HOSTNAME" = "$SOURCE_NODE_NAME" ]; then
		echo "Warning: This is the source node (Already installed here)"
		exit
	fi
	echo "****************************** $HOSTNAME ******************************"
	
	echo "Unload lustre, zfs and spl"
	/opt/lustre/2.12.2/sbin/lustre_rmmod
	modprobe -r zfs
	modprobe -r spl
	
	echo "Rsync spl installation"
	rsync -alp $SOURCE_NODE_NAME:/opt/spl /opt/

	echo "Rsync zfs installation"
	rsync -alp $SOURCE_NODE_NAME:/opt/zfs /opt/
	echo "Rsync /etc/zfs/"
	rsync -alp $SOURCE_NODE_NAME:/etc/zfs /etc/

	echo "Rsync lustre installation"
	rsync -alp $SOURCE_NODE_NAME:/opt/lustre /opt/
	echo "Rsync linux/lustre headers"
	rsync -alp $SOURCE_NODE_NAME:/usr/include/linux/lustre /usr/include/linux/
	echo "Rsync linux/lnet headers"
	rsync -alp $SOURCE_NODE_NAME:/usr/include/linux/lnet /usr/include/linux/

	echo "Rsync /sbin/mount.lustre"
	rsync -alp $SOURCE_NODE_NAME:/sbin/mount.lustre /sbin/


	echo "Rsync /usr/lib/systemd/system/lnet.service"
	rsync -alp $SOURCE_NODE_NAME:/usr/lib/systemd/system/lnet.service /usr/lib/systemd/system/
	echo "Rsync /etc/ha.d Directory"
	rsync -alp $SOURCE_NODE_NAME:/etc/ha.d /etc/

	echo "Rsync /etc/lnet.conf"
	rsync -alp $SOURCE_NODE_NAME:/etc/lnet.conf /etc/

	echo "Rsync /etc/ldev.conf"
	rsync -alp $SOURCE_NODE_NAME:/etc/ldev.conf /etc/

	echo "Rsync /etc/lnet_routes.conf"
	rsync -alp $SOURCE_NODE_NAME:/etc/lnet_routes.conf /etc/

	echo "Rsync /etc/udev/rules.d/99-lustre-server.rules"
	rsync -alp $SOURCE_NODE_NAME:/etc/udev/rules.d/99-lustre-server.rules /etc/udev/rules.d/

	echo "Rsync /etc/udev/rules.d/99-lustre.rules"
	rsync -alp $SOURCE_NODE_NAME:/etc/udev/rules.d/99-lustre.rules /etc/udev/rules.d/

	echo "Add library paths and update it"
	echo "/opt/zfs/0.7.13/usr/lib64/" >> /etc/ld.so.conf.d/lustre.conf
	ldconfig

	echo "Setting lnet (static conf) in /etc/modprobe.d/lustre.conf"
	echo "options lnet networks=tcp1(ib0)" > /etc/modprobe.d/lustre.conf

	echo "Rsync spl and zfs modules"
	rsync -alp $SOURCE_NODE_NAME:/lib/modules/"$KERNEL_VERSION"-default/extra /lib/modules/"$KERNEL_VERSION"-default/
	echo "Rsync lustre modules"
	rsync -alp $SOURCE_NODE_NAME:/lib/modules/"$KERNEL_VERSION"-default/updates/kernel /lib/modules/"$KERNEL_VERSION"-default/updates/

	echo "Update modules.dep file etc .."
	depmod -a

	echo "Load ZFS"
	result=`modprobe zfs 2>&1`
	if [ ! -z "$result" ] ; then
		echo "ERROR: You have a problem"
		echo "$result"
		return
	fi

	echo "Load LUSTRE"
	result=`modprobe lustre 2>&1`
	if [ -z "$result" ] ; then
		echo "****************************** $HOSTNAME Successfully installed ******************************"
	else
		echo "****************************** ERROR: You have a problem with $HOSTNAME ******************************"
		echo "$result"
	fi
}

install_all() {
	for HOST  in `cat conf/remote_nodes_to_install.txt`
	do
		install_remote_node $HOST
	done

	if [ ! -z "$FAILED_INSTALL" ] ; then
		echo "************************************************************"
		echo "Installation failed in : $FAILED_INSTALL"
	else
		echo "Lustre Successfully Installed in All Nodes"
		echo "************************************************************"
	fi
}

if [[ "$1" == "local" ]]; then
	echo -e "\t Install on local node $HOSTNAME from $SOURCE_NODE_NAME"
	install_local_node
elif [ "$HOSTNAME" = "$SOURCE_NODE_NAME" ]; then
	if [[ -z "$1" ]]; then
		echo -e "\t Install All Nodes in conf/remote_nodes_to_install.txt from $SOURCE_NODE_NAME"
		install_all
	else
		echo "Install on remote node $1 from $SOURCE_NODE_NAME"
		install_remote_node $1
	fi        
else
	echo "Error: You must run script from the source node: $SOURCE_NODE_NAME or you can install it in local node: ./install_all.sh local"
fi
