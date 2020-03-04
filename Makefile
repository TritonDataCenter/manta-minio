#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright 2020 Joyent, Inc.
#

NAME = minio

GO_PREBUILT_VERSION = 1.14
GO_GOOS = solaris
# XXX timf not sure if we need node yet
NODE_PREBUILT_VERSION = v8.17.0
ifeq ($(shell uname -s),SunOS)
    NODE_PREBUILT_TAG=zone64
    NODE_PREBUILT_IMAGE=5417ab20-3156-11ea-8b19-2b66f5e7a439
endif

ENGBLD_USE_BUILDIMAGE = true
ENGBLD_REQUIRE := $(shell git submodule update --init deps/eng)
include ./deps/eng/tools/mk/Makefile.defs
TOP ?= $(error Unable to access eng.git submodule Makefiles.)

include ./deps/eng/tools/mk/Makefile.smf.defs
ifeq ($(shell uname -s),SunOS)
    include ./deps/eng/tools/mk/Makefile.go_prebuilt.defs
    include ./deps/eng/tools/mk/Makefile.node_prebuilt.defs
    include ./deps/eng/tools/mk/Makefile.agent_prebuilt.defs
endif

# triton-origin-x86_64-19.4.0
BASE_IMAGE_UUID = 59ba2e5e-976f-4e09-8aac-a4a7ef0395f5
BUILDIMAGE_NAME = mantav2-$(NAME)
BUILDIMAGE_PKGSRC = 
BUILDIMAGE_DESC = Triton/Manta Minio
AGENTS = amon config registrar

RELEASE_TARBALL := $(NAME)-pkg-$(STAMP).tar.gz
RELSTAGEDIR := /tmp/$(NAME)-$(STAMP)

SMF_MANIFESTS = smf/manifests/minio.xml

ESLINT_FILES := $(JS_FILES)
BASH_FILES := $(wildcard boot/*.sh) $(TOP)/bin/minio-configure


MINIO_IMPORT = github.com/minio/minio
MINIO_GO_DIR = $(GO_GOPATH)/src/$(MINIO_IMPORT)
MINIO_EXEC = $(MINIO_GO_DIR)/minio

#
# Repo-specific targets
#
.PHONY: all
all: $(MINIO_EXEC) $(STAMP_CERTGEN) sdc-scripts manta-scripts

#
# Link the "minio" submodule into the correct place within our
# project-local GOPATH, then build the binary.
#
$(MINIO_EXEC): deps/minio/.git $(STAMP_GO_TOOLCHAIN)
	$(GO) version
	mkdir -p $(dir $(MINIO_GO_DIR))
	rm -f $(MINIO_GO_DIR)
	ln -s $(TOP)/deps/minio $(MINIO_GO_DIR)
	(cd $(MINIO_GO_DIR) && env -i $(GO_ENV) GO111MODULE=on make -f $(TOP)/Makefile.minio build)

sdc-scripts: deps/sdc-scripts/.git
manta-scripts: deps/manta-scripts/.git

.PHONY: clean
clean::
	rm -rf $(MINIO_EXEC)

.PHONY: release
release: all docs $(SMF_MANIFESTS)
	@echo "Building $(RELEASE_TARBALL)"
	@mkdir -p $(RELSTAGEDIR)/root/opt/triton/$(NAME)
	cp -r \
		$(TOP)/bin \
		$(TOP)/etc \
		$(TOP)/smf \
		$(TOP)/sapi_manifests \
		$(RELSTAGEDIR)/root/opt/triton/$(NAME)/
	# our minio build
	@mkdir -p $(RELSTAGEDIR)/root/opt/triton/$(NAME)/minio
	cp -r \
		$(MINIO_GO_DIR)/minio \
		$(RELSTAGEDIR)/root/opt/triton/$(NAME)/minio/
	# zone boot
	mkdir -p $(RELSTAGEDIR)/root/opt/smartdc/boot
	cp -r $(TOP)/deps/sdc-scripts/{etc,lib,sbin,smf} \
		$(RELSTAGEDIR)/root/opt/smartdc/boot/
	cp -r $(TOP)/boot/* \
		$(RELSTAGEDIR)/root/opt/smartdc/boot/
	mkdir -p $(RELSTAGEDIR)/root/opt/smartdc/boot/manta-scripts
	cp -r $(TOP)/deps/manta-scripts/*.sh \
		$(RELSTAGEDIR)/root/opt/smartdc/boot/manta-scripts
	# tar it up
	(cd $(RELSTAGEDIR) && $(TAR) -I pigz -cf $(TOP)/$(RELEASE_TARBALL) root)
	@rm -rf $(RELSTAGEDIR)

.PHONY: publish
publish: release
	mkdir -p $(ENGBLD_BITS_DIR)/$(NAME)
	cp $(TOP)/$(RELEASE_TARBALL) \
		$(ENGBLD_BITS_DIR)/$(NAME)/$(RELEASE_TARBALL)

include ./deps/eng/tools/mk/Makefile.deps
ifeq ($(shell uname -s),SunOS)
    include ./deps/eng/tools/mk/Makefile.go_prebuilt.targ
    include ./deps/eng/tools/mk/Makefile.node_prebuilt.targ
    include ./deps/eng/tools/mk/Makefile.agent_prebuilt.targ
endif
include ./deps/eng/tools/mk/Makefile.smf.targ
include ./deps/eng/tools/mk/Makefile.targ
