#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright 2020 Joyent, Inc.
#

export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: '\
'${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

set -o errexit
set -o pipefail
set -o xtrace

# XXX timf this is just a placeholder for now. Perhaps it's not needed?

ROOT_DIR=/opt/triton/minio
CONF_DIR=${ROOT_DIR}/etc
CONFIG_JSON=${CONF_DIR}/config.json

#
# If the instance is deployed as a Manta zone, config-agent will take care of
# any setup, so we can exit early here.
#
if [[ $(json 'is_manta_service' < "${CONFIG_JSON}") == 'true' ]]; then
    exit 0
fi

exit 0
