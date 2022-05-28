# Lustre-File-System-Deployement-Scripts

These scripts were implemented to configure a Lustre parallel file system on a cluster:
1. Install Lustre on multiple nodes
2. Configure MGS, MDS and OSTs.
3. Mounting the file system

We assume that Lustre has been installed on at least one node that we name the *Source Node*.
We also assume that all nodes have the same Linux kernel and their names are identifiable by "ssh".
(The scripts will access these nodes through ssh using their names only e.g. ssh Node-001).

## Lustre Remote Install

To deploy the same Lustre installation on multiple nodes, we use the [**lustre_install_from_source.sh**](lustre_install_from_source.sh) script.

Manually set the following variables in the script:
* KERNEL_VERSION
* LNET_CONF
* SOURCE_NODE_NAME

You can either run the script on the source node or the remote nodes.
- On the source node:
```
./lustre_install_from_source.sh
```
	It will install Lustre on all nodes listed in the [conf/remote_nodes_to_install.txt](conf/remote_nodes_to_install.txt)  file which should contain the list of all nodes except the *Source Node*.

```
./lustre_install_from_source.sh remote_node_name
```
	It will install Lustre only on that node

- On the remote node:
You have to use the "local" option to install Lustre on the current node.
```
./lustre_install_from_source.sh local
```

## Lustre Configuration

The main components of a Lustre Parallel file system are:
* Management Server (MGS)
* Metadata Server (MDS)
* Object Storage Server (OSS)
* Lustre Networking (LNet)
* Lustre clients

The [lustre_configure.sh](lustre_configure.sh) script will configure a Lustre file system consisting of a combined MGS/MDT node and multiple OSTs and clients. The storage devices are not external and located within the nodes. Therefore, each node is an OSS of one OST: We used this configuration for sake of simplicity although it is not typical to have one OST per one OSS.

### How to Run
- Manually set the variables defined within the define_vars() function.
- Provide the names of the OSS nodes in the [conf/ost_nodes.txt](conf/ost_nodes.txt) file.
- Configure the MGS/MDS using the --mgs option.
```
./lustre_configure.sh --mgs
```
	- First, the script will configure the node with the name defined by "MDS_NODE" of address "MDS_SSH_ADD" as a combined MGS/MDS node.
	- Then, it will iterate over the list of OSS nodes and configure one OST.
		The OST uses a RAID0 conf of two storage devices.
		***Still more details to add***

- You can configure one specific OST by providing its name as an argument.
```
./lustre_configure.sh oss_node_name
```
