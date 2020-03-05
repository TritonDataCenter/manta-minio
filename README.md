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
* Reprovision your `manta0` instance with that image
* Log in to the manta-deployment zone, and re-run `manta-init`
* Deploy an instance of the minio image as a standard `--experimental`
  Manta service named `minio` using `manta-adm`.

The instance currently listens on the external network, http://<ip>:9000.

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
the instance and is **not yet clustered or fault tolerant**. Buyer beware.


## Build

### Binaries

```
make all
```

At present, this uses the
[`illumos_fixes` branch of joyent/minio.git](https://github.com/joyent/minio/tree/illumos_fixes)

We're awaiting [Kody's patch to azure-storage-blob](https://github.com/Azure/azure-storage-blob-go/pull/117)
to integrate before we can get a full clean build.

In the meantime, after
`make all` fails, you can modify the `cache/gopath1.14/pkg/mod/github.com/!azure/azure-storage-blob-go@v0.8.0`
with the following patch:

```
diff --git a/pkg/mod/github.com/!azure/azure-storage-blob-go@v0.8.0/azblob/zc_mmf_unix.go b/pkg/mod/github.com/!azure/azure-storage-blob-go@v0.8.0/azblob/zc_mmf_unix.go
index 3e8c7cba..c2767704 100644
--- a/pkg/mod/github.com/!azure/azure-storage-blob-go@v0.8.0/azblob/zc_mmf_unix.go
+++ b/pkg/mod/github.com/!azure/azure-storage-blob-go@v0.8.0/azblob/zc_mmf_unix.go
@@ -1,25 +1,25 @@
-// +build linux darwin freebsd openbsd netbsd dragonfly
+// +build linux darwin freebsd openbsd netbsd dragonfly solaris

 package azblob

 import (
        "os"
-       "syscall"
+       "golang.org/x/sys/unix"
 )

 type mmf []byte

 func newMMF(file *os.File, writable bool, offset int64, length int) (mmf, error) {
-       prot, flags := syscall.PROT_READ, syscall.MAP_SHARED // Assume read-only
+       prot, flags := unix.PROT_READ, unix.MAP_SHARED // Assume read-only
        if writable {
-               prot, flags = syscall.PROT_READ|syscall.PROT_WRITE, syscall.MAP_SHARED
+               prot, flags = unix.PROT_READ|unix.PROT_WRITE, unix.MAP_SHARED
        }
-       addr, err := syscall.Mmap(int(file.Fd()), offset, length, prot, flags)
+       addr, err := unix.Mmap(int(file.Fd()), offset, length, prot, flags)
        return mmf(addr), err
 }

 func (m *mmf) unmap() {
-       err := syscall.Munmap(*m)
+       err := unix.Munmap(*m)
        *m = nil
        if err != nil {
                panic("if we are unable to unmap the memory-mapped file, there is serious concern for memory corruption")
```

### Images
Information on how to building Triton/Manta components to be deployed within
an image please see the [Developer Guide for Building Triton and Manta](https://github.com/joyent/triton/blob/master/docs/developer-guide/building.md#building-a-component).
