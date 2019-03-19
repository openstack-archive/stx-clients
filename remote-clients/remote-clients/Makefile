#
# SPDX-License-Identifier: Apache-2.0
#
# Copyright (C) 2019 Intel Corporation
#

NAME ?= remote-clients
VERSION ?= 2.0.6
REMOTE_CLIENT_DIR ?= /usr/share/remote-clients
SDK_DEPLOY_DIR ?= /opt/deploy/cgcs_sdk

all:
	mv $(NAME) wrs-$(NAME)-$(VERSION)
	find $(REMOTE_CLIENT_DIR) -name "*.tgz" -exec cp '{}' wrs-$(NAME)-$(VERSION)/ \;
	sed -i 's/xxxVERSIONxxx/$(VERSION)/g' wrs-$(NAME)-$(VERSION)/README
	tar czf wrs-$(NAME)-$(VERSION).tgz wrs-$(NAME)-$(VERSION)

install:
	install -D -m 644 wrs-$(NAME)-$(VERSION).tgz $(SDK_DEPLOY_DIR)/wrs-$(NAME)-$(VERSION).tgz
