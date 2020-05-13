=======================
CephFS Exports over NFS
=======================

CephFS namespaces can be exported over NFS protocol using the
`NFS-Ganesha NFS server <https://github.com/nfs-ganesha/nfs-ganesha/wiki>`_.

Requirements
============

-  Latest Ceph file system with mgr and dashboard enabled
-  'nfs-ganesha', 'nfs-ganesha-ceph' and nfs-ganesha-rados-grace packages
   (version 2.7.6-2 and above)

Create NFS Ganesha Cluster
==========================

.. code:: bash

    $ ceph nfs cluster create <type=cephfs> [--size=1] <clusterid>

This creates a common recovery pool for all Ganesha daemons, new user based on
cluster_id and common ganesha config rados object.

Here size denotes the number of ganesha daemons within a cluster and type is
export type. Currently only CephFS is supported.

.. note:: This does not setup ganesha recovery database and start the daemons.
          It needs to be done manually if not using vstart for creating
          clusters. Please refer `ganesha-rados-grace doc
          <https://github.com/nfs-ganesha/nfs-ganesha/blob/next/src/doc/man/ganesha-rados-grace.rst>`_

Create CephFS Export
====================

.. code:: bash

    $ ceph nfs export create <type=cephfs> <fsname> <binding> <clusterid> [--readonly] [--path=/path/in/cephfs]

It creates export rados objects containing the export block. Here binding is
the pseudo root name and type is export type. Currently only CephFS is
supported.

Configuring NFS-Ganesha to export CephFS with vstart
====================================================

.. code:: bash

    $ MDS=1 MON=1 OSD=3 NFS=1 ../src/vstart.sh -n -d

NFS: It denotes the number of NFS-Ganesha clusters to be created.

Mount
=====

After the exports are successfully created and Ganesha daemons are no longer in
grace period. The exports can be mounted by

.. code:: bash

    $ mount -t nfs -o port=<ganesha-port> <ganesha-host-name>:<ganesha-pseudo-path> <mount-point>

.. note:: Only NFS v4.0+ is supported.
