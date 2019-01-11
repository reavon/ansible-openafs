#!/bin/bash

set -x
set -e

CELL=example.com
REALM=EXAMPLE.COM
HOST=afs03.example.com
PART=d

function _vos_create {
    local server="$1"
    local part="$2"
    local name="$3"
    local rc=

    set +e
    /usr/sbin/vos create -server "$server" -part "$part" -name "$name" -verbose \
        >/tmp/vos.stdout 2>/tmp/vos.stderr
    rc=$?
    set -e
    cat /tmp/vos.stdout
    cat /tmp/vos.stderr
    if [ $rc -ne 0 ]; then
        if grep -q "Volume $name already exists" /tmp/vos.stderr; then
            rc=0
        fi
        # todo: retry on enoquorum ?
    fi
    if [ $rc -ne 0 ]; then
        echo "ERROR: vos create failed"
        exit 1
    fi
}

function _vos_addsite {
    local server="$1"
    local part="$2"
    local name="$3"
    local rc=

    set +e
    /usr/sbin/vos addsite -server "$server" -part "$part" -id "$name" -verbose \
        >/tmp/vos.stdout 2>/tmp/vos.stderr
    rc=$?
    set -e
    cat /tmp/vos.stdout
    cat /tmp/vos.stderr
    if [ $rc -ne 0 ]; then
        if grep -q "RO already exists on partition" /tmp/vos.stderr; then
            rc=0
        fi
        # todo: retry on enoquorum ?
    fi
    if [ $rc -ne 0 ]; then
        echo "ERROR: vos addsite failed"
        exit 1
    fi
}

function _vos_release {
    local name=$1
    /usr/sbin/vos release -id "$name" -verbose
}

function _fs_mkmount {
    local dir=$1
    local vol=$2
    local cell=$3
    local rw=$4
    local rc=
 return
    set +e
    /usr/bin/fs mkmount $rw -dir "$dir" -vol "$vol" -cell "$cell"
        >/tmp/fs.stdout 2>/tmp/fs.stderr
    rc=$?
    set -e
    cat /tmp/fs.stdout
    cat /tmp/fs.stderr
    if [ $rc -ne 0 ]; then
        if grep -q "File exists" /tmp/fs.stderr; then
            rc=0
        fi
    fi
    if [ $rc -ne 0 ]; then
        echo "ERROR: fs mkmount failed"
        exit 1
    fi
}

function _fs_setacl {
    local dir=$1
    local group=$2
    local rights=$3
    /usr/bin/fs setacl -dir "$dir" -acl "$group" "$rights"
}

function _fs_checkvolumes {
    /usr/bin/fs checkvolume
}

kinit -k -t admin.admin.keytab admin/admin@$REALM
aklog -d -c $CELL

_vos_create $HOST $PART root.cell

_fs_mkmount /afs/.:mount/$CELL:root.afs/$CELL root.cell $CELL
_fs_mkmount /afs/.:mount/$CELL:root.afs/.$CELL root.cell $CELL -rw

_fs_setacl /afs/.:mount/$CELL:root.afs/. system:anyuser read
_fs_setacl /afs/.:mount/$CELL:root.afs/$CELL/. system:anyuser read

_vos_addsite $HOST $PART root.afs
_vos_addsite $HOST $PART root.cell

_vos_release root.afs
_vos_release root.cell

_fs_checkvolumes
