<!--
    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
-->

<!--
    Copyright 2020 Joyent, Inc.
-->

# Manta Minio
This repository is part of the Joyent Manta Project.  For contribution
guidelines, issues and general documentation, visit the
[Manta](https://github.com/joyent/manta) project pages.

## Overview

This is currently a **proof-of-concept**, related to
[RFD 181 Improving Manta Storage Unit Cost (MinIO)](https://github.com/joyent/rfd/tree/master/rfd/0181/)

For now, this repository produces a mantav2-minio image, which can be deployed
using the [`minio-poc` branch of sdc-manta.git](https://github.com/joyent/sdc-manta/tree/minio-poc)

To use:

* Build a new `manta-deployment` image from the sdc-manta.git repository
  on the `minio-poc` branch
* Reprovision your `manta0` instance with that image
* Log in to the manta-deployment zone, and re-run `manta-init`
* Deploy 4 instances of the minio image as a standard `--experimental`
  Manta service named `minio` using `manta-adm`.

The instance currently listens on the external network, `http://<ip>:9000`.

```
[root@headnode (europe) ~]# zlogin min[completed alias: minio.earth.example.com-524cf56e]
                                   524cf56e-d904-41a3-84fb-847e65c3dd08
[Connected to zone '524cf56e-d904-41a3-84fb-847e65c3dd08' pts/6]
Last login: Thu Mar  5 12:54:04 on pts/6
 =  J O Y E N T  =

    mantav2-minio (master-20200305T124954Z-gaa234e6)
    git@github.com:joyent/manta-minio.git
    triton-origin-x86_64-19.4.0@master-20200130T200825Z-gbb45b8d

[root@524cf56e (minio) ~]$ svcs minio
STATE          STIME    FMRI
online         12:53:50 svc:/triton/site/minio:default
```

The minio service is minimally integrated with Manta, listens on the external
network, **only** writes to `/data/minio/data` on a delegated dataset within
the instance.

We require at least 4 instances to be provisioned, and use the SAPI service
metadata parameter `MINIO_INST_COUNT` to declare how many instances should be
part of the initial
[distributed erasure coding set](https://docs.min.io/docs/distributed-minio-quickstart-guide.html).
This currently can be set to 4, 6, 8, 10, 12, 14 or 16. The minio SMF service
will likely drop to maintenance if you use an invalid value.

The number of instances deployed `by manta-adm` must always be a multiple of
the value of `MINIO_INST_COUNT`.

By default, we look for the `MANTA_RACK` SAPI service metadata to determine
rack in which related minio instances are housed. This gets set in
[sdc-manta.git:/lib/deploy.js](https://github.com/joyent/sdc-manta/blob/minio-poc/lib/deploy.js#L1143)
based on the presence of a `manta_rack_<RACK>` nictag.

The `manta_minio_id` value is analogous to Mako's `manta_storage_id`, and is
used to name instances:

        [root@headnode (europe) ~]# manta-adm show -o zonename,minio_id minio
        ZONENAME                             MINIO ID
        07fc71ea-3a50-4a24-8e8a-a87d979e6ad1 2.minio.earth.example.com
        1d2fd3e4-edb7-4ce5-871e-83ed58652338 5.minio.earth.example.com
        2e82bd94-7e13-4041-9e8a-9829c3e4b08b 4.minio.earth.example.com
        306a701b-ccc7-4235-9e8f-07bce42c656a 6.minio.earth.example.com
        47c259eb-7039-4ec5-b307-231e54902e04 1.minio.earth.example.com
        55d2c766-d729-4434-b87a-22b460251920 3.minio.earth.example.com
        [root@headnode (europe) ~]#

If a `MANTA_RACK` value is found, that data is included as a component of the
`manta_minio_id`

At provisioning time, the 'domain' of the instance is set to
`{{MANTA_RACK}}.{{SERVICE_NAME}}` on rack-aware minio setups, or
`{{SERVICE_NAME}}`, and minio is started using the instances it discovers,
using the nameservice aliases corresponding to the `manta_minio_id` values.

## Maintenance

TBD. (yes, don't use this for production data yet)

## Build

### Binaries

```
make all
```

At present, this service uses the
[`illumos_fixes` branch of joyent/minio.git](https://github.com/joyent/minio/tree/illumos_fixes)

### Images
Information on how to building Triton/Manta components to be deployed within
an image please see the [Developer Guide for Building Triton and Manta](https://github.com/joyent/triton/blob/master/docs/developer-guide/building.md#building-a-component).
