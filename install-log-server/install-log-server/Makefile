#
# SPDX-License-Identifier: Apache-2.0
#
# Copyright (C) 2019 Intel Corporation
#

NAME ?= install-log-server
VERSION ?= 1.1.2
SDK_DEPLOY_DIR ?= /opt/deploy/cgcs_sdk

all:
	mv $(NAME) wrs-$(NAME)-$(VERSION)
	tar czf wrs-$(NAME)-$(VERSION).tgz wrs-$(NAME)-$(VERSION)

install:
	install -D -m 644 wrs-$(NAME)-$(VERSION).tgz $(SDK_DEPLOY_DIR)/wrs-$(NAME)-$(VERSION).tgz
