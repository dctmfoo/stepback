SHELL := /bin/zsh
.DEFAULT_GOAL := help

-include Makefile.local

PROJECT := StepBack.xcodeproj
SCHEME := StepBack
MAC_SCHEME := StepBackMac
SIM_DEST ?= platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5
IPAD_DEST ?= platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=26.5
MAC_DEST ?= platform=macOS
PERF_DEST ?= $(SIM_DEST)
PERF_XCODE_FLAGS ?=
TEAM_ID ?=
IPHONE_ID ?=
IPAD_ID ?=
DEVICE_DERIVED_DATA := build/DerivedData-device
BUNDLE_ID := com.nags.stepback

.PHONY: help gen test-core test-app-unit test-focus-iphone test-focus-ipad test-focus-mac test-app test-ipad test-mac test test-perf test-perf-iphone test-perf-ipad build-sim build-sim-ipad build-mac devices install-iphone install-ipad

help: ## Show repeatable project generation, build, and test tasks.
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

gen: ## Regenerate StepBack.xcodeproj from project.yml; never hand-edit the generated project.
	@xcodegen generate

test-core: ## Run the standalone StepBackCore package tests.
	@cd StepBackCore && swift test

test-app-unit: gen ## Run only app unit tests on the standard iPhone simulator; no UI automation.
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$(SIM_DEST)" test \
		-only-testing:StepBackTests

test-focus-iphone: gen ## Run one iPhone UI class/method: make $@ TEST=StepBackUITests/Class/testMethod.
	@test -n "$(TEST)" || { echo "TEST is required (target/class or target/class/method)"; exit 2; }
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$(SIM_DEST)" test \
		-only-testing:"$(TEST)"

test-focus-ipad: gen ## Run one iPad UI class/method: make $@ TEST=StepBackUITests/Class/testMethod.
	@test -n "$(TEST)" || { echo "TEST is required (target/class or target/class/method)"; exit 2; }
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$(IPAD_DEST)" test \
		-only-testing:"$(TEST)"

test-focus-mac: gen ## Owner-explicit local Mac UI fallback; hosted focused workflow is the default.
	@test -n "$(TEST)" || { echo "TEST is required (target/class or target/class/method)"; exit 2; }
	@xcodebuild -project "$(PROJECT)" -scheme "$(MAC_SCHEME)" -destination "$(MAC_DEST)" test \
		-only-testing:"$(TEST)"

test-app: gen ## Final gate: run all app unit/UI tests on iPhone; do not use for diagnosis.
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$(SIM_DEST)" test

test-ipad: gen ## Final gate: run all app unit/UI tests on iPad; do not use for diagnosis.
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$(IPAD_DEST)" test

test-mac: gen ## Owner-explicit local full Mac UI fallback; never use as a diagnostic loop.
	@xcodebuild -project "$(PROJECT)" -scheme "$(MAC_SCHEME)" -destination "$(MAC_DEST)" test

test: test-core test-app ## Run the core and standard app automated test gate.

test-perf: gen ## Run opt-in launch, play-latency, gallery-scroll, and real-clock measurements; override PERF_DEST.
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$(PERF_DEST)" test \
		-only-testing:StepBackTests/PlayerTimingIntegrityTests \
		-only-testing:StepBackUITests/StepBackPerformanceTests \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) STEPBACK_ACCEPTANCE_PERFORMANCE' \
		$(PERF_XCODE_FLAGS)

test-perf-iphone: ## Run acceptance measurements on the paired physical iPhone.
	@test -n "$(IPHONE_ID)" || { printf "Set IPHONE_ID in Makefile.local or the environment (see make devices)\n"; exit 2; }
	@test -n "$(TEAM_ID)" || { printf "Set TEAM_ID in Makefile.local or the environment\n"; exit 2; }
	@$(MAKE) test-perf PERF_DEST="platform=iOS,id=$(IPHONE_ID)" PERF_XCODE_FLAGS="DEVELOPMENT_TEAM=$(TEAM_ID) -allowProvisioningUpdates"

test-perf-ipad: ## Run acceptance measurements on the paired physical iPad.
	@test -n "$(IPAD_ID)" || { printf "Set IPAD_ID in Makefile.local or the environment (see make devices)\n"; exit 2; }
	@test -n "$(TEAM_ID)" || { printf "Set TEAM_ID in Makefile.local or the environment\n"; exit 2; }
	@$(MAKE) test-perf PERF_DEST="platform=iOS,id=$(IPAD_ID)" PERF_XCODE_FLAGS="DEVELOPMENT_TEAM=$(TEAM_ID) -allowProvisioningUpdates"

build-sim: gen ## Build the app for the standard iPhone simulator; override SIM_DEST as needed.
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$(SIM_DEST)" build

build-sim-ipad: gen ## Build the app for the standard iPad simulator; override IPAD_DEST as needed.
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination "$(IPAD_DEST)" build

build-mac: gen ## Build the native macOS app; override MAC_DEST as needed.
	@if [ -n "$(TEAM_ID)" ]; then \
		xcodebuild -project "$(PROJECT)" -scheme "$(MAC_SCHEME)" -destination "$(MAC_DEST)" build DEVELOPMENT_TEAM="$(TEAM_ID)" CODE_SIGN_STYLE=Automatic; \
	else \
		xcodebuild -project "$(PROJECT)" -scheme "$(MAC_SCHEME)" -destination "$(MAC_DEST)" build CODE_SIGNING_ALLOWED=NO; \
	fi

devices: ## List paired physical devices and their identifiers for install targets.
	@xcrun devicectl list devices

install-iphone: gen ## Build, install, and launch a signed Debug app on the paired iPhone; override IPHONE_ID as needed.
	@$(MAKE) _install-device DEVICE_ID="$(IPHONE_ID)" DEVICE_LABEL=iPhone

install-ipad: gen ## Build, install, and launch a signed Debug app on the paired iPad; override IPAD_ID as needed.
	@$(MAKE) _install-device DEVICE_ID="$(IPAD_ID)" DEVICE_LABEL=iPad

_install-device:
	@if [ -z "$(DEVICE_ID)" ]; then printf "Set DEVICE_ID=<paired device identifier> (see make devices)\n"; exit 2; fi
	@if [ -z "$(TEAM_ID)" ]; then printf "Set TEAM_ID in Makefile.local or the environment\n"; exit 2; fi
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug -destination "platform=iOS,id=$(DEVICE_ID)" -derivedDataPath "$(DEVICE_DERIVED_DATA)" build DEVELOPMENT_TEAM="$(TEAM_ID)" -allowProvisioningUpdates
	@xcrun devicectl device install app --device "$(DEVICE_ID)" "$(DEVICE_DERIVED_DATA)/Build/Products/Debug-iphoneos/StepBack.app"
	@xcrun devicectl device process launch --device "$(DEVICE_ID)" --terminate-existing "$(BUNDLE_ID)" >/dev/null
	@printf "Installed and launched $(BUNDLE_ID) on the $(DEVICE_LABEL) ($(DEVICE_ID)). Existing app data was preserved.\n"
