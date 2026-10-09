TEAM_ID ?=
CONFIGURATION ?= Debug
PROJECT := native/ConsumeCreate.xcodeproj
SCHEME := ConsumeCreate
BUILD_DIR := native/build
APP := $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/consume-create.app

ifeq ($(TEAM_ID),)
SIGNING_ARGS :=
else
SIGNING_ARGS := DEVELOPMENT_TEAM=$(TEAM_ID) CONSUME_CREATE_GROUP=$(TEAM_ID).com.consumecreate.shared
endif

.PHONY: build run package test

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(BUILD_DIR) $(SIGNING_ARGS) build

run: build
	open -n "$(APP)"

package:
	TEAM_ID="$(TEAM_ID)" scripts/package.sh

test:
	swiftc native/Shared/Usage.swift native/Tests/UsageTests.swift -o /tmp/consume-create-usage-tests
	/tmp/consume-create-usage-tests
