#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright 2020 Joyent, Inc.
#

#
# One-time setup of a Triton/Manta minio core zone.
#
# It is expected that this is run via the standard Triton user-script,
# i.e. as part of the "mdata:execute" SMF service. That user-script ensures
# this setup.sh is run once for each (re)provision of the image. However this
# script should also be idempotent.
#

export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: '\
'${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

set -o errexit
set -o pipefail
set -o xtrace

PATH=/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin
ROOT_DIR=/opt/triton/minio

#
CMON_AUTH_DIR=${ROOT_DIR}/keys
CMON_KEY_FILE=${CMON_AUTH_DIR}/prometheus.key.pem
CMON_CERT_FILE=${CMON_AUTH_DIR}/prometheus.cert.pem

#
# Minio data that should be persistent across reprovisions is stored on its
# delegate dataset:
#
#   /data/minio/
#
PERSIST_DIR=/data/minio
DATA_DIR=${PERSIST_DIR}/data

function fatal {
    printf '%s: ERROR: %s\n' "$(basename ${0})" "${*}" >&2
    exit 1
}

#
# We can't use the sapi config file to determine $FLAVOR yet, because this runs
# before the SAPI config gets written on zone setup, so we check for the
# existence of manta_role instead. This is the same method that moray uses for
# determining $FLAVOR.
#
if [[ -n $(mdata-get sdc:tags.manta_role) ]]; then
    export FLAVOR='manta'
else
    export FLAVOR='triton'
fi

# ---- internal routines

# Mount our delegate dataset at /data.
function minio_setup_delegate_dataset {
    local mountpoint

    dataset=zones/$(zonename)/data
    mountpoint=$(zfs get -Ho value mountpoint "${dataset}")
    if [[ "${mountpoint}" != '/data' ]]; then
        zfs set mountpoint=/data "${dataset}"
    fi
}

function minio_setup_minio {
    mkdir -p "${DATA_DIR}"

    /usr/sbin/svccfg import ${ROOT_DIR}/smf/manifests/minio.xml

    #
    # The minio SMF service runs as the 'nobody' user, so the files it
    # accesses must be owned by nobody. Here, we ensure this for the files and
    # directory that will remain static for the lifetime of the zone.
    #
    chown nobody:nobody "${DATA_DIR}"

    #
    # prometheus-configure contains the common setup code that must be run here
    # and also on config-agent updates
    #
    TRACE=1 ${ROOT_DIR}/bin/minio-configure
}

# ---- mainline

minio_setup_delegate_dataset

if [[ "${FLAVOR}" == 'manta' ]]; then

    MANTA_SCRIPTS_DIR=/opt/smartdc/boot/manta-scripts
    source "${MANTA_SCRIPTS_DIR}/util.sh"
    source "${MANTA_SCRIPTS_DIR}/services.sh"

    manta_common_presetup
    manta_add_manifest_dir "${ROOT_DIR}"
    manta_common_setup 'minio' 0

    minio_setup_minio

    manta_common_setup_end

else # "$FLAVOR" == "triton"

    CONFIG_AGENT_LOCAL_MANIFESTS_DIRS=${ROOT_DIR}
    source /opt/smartdc/boot/lib/util.sh
    sdc_common_setup

    minio_setup_minio

    # Log rotation.
    sdc_log_rotation_add config-agent /var/svc/log/*config-agent*.log 1g
    sdc_log_rotation_add registrar /var/svc/log/*registrar*.log 1g
    sdc_log_rotation_add minio /var/svc/log/*minio*.log 1g
    sdc_log_rotation_setup_end

    #
    # Update the global_zones.json the first time.
    #
    # We disable errexit so that failure to update when external services
    # (DNS) are broken does not abort the completion of setup.
    #
    set +o errexit
    ${ROOT_DIR}/bin/update_global_zones.sh \
        >>/var/log/update_global_zones.log 2>&1
    set -o errexit

    sdc_setup_complete
fi

exit 0
