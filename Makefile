# Makefile — MapLibre Native: Android + iOS one-shot build
# Usage:
#   make all            # build in android -> ios order
#   make android        # only Android
#   make ios            # only iOS (Bazel)
#   make clean          # clean up the output
#   make distclean      # complete cleanup including build cache
#   make doctor         # check environment
#   make submodules     # initialize/update submodules

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

ROOT_DIR         := $(abspath $(CURDIR))
ANDROID_DIR      := $(ROOT_DIR)/platform/android
DIST_DIR         := $(ROOT_DIR)/dist
DIST_ANDROID_DIR := $(DIST_DIR)/android
DIST_IOS_DIR     := $(DIST_DIR)/ios

# -------- ANDROID --------
GRADLEW          := $(ANDROID_DIR)/gradlew
ANDROID_TASK     := assembleRelease
# 필요시 :AAR 모듈 타깃을 지정(예: :sdk:assembleRelease)하세요.
# ANDROID_TASK   := :sdk:assembleRelease

# -------- iOS (Bazel) --------
# 기본 권장: Bazel 빌드 (XCFramework/Framework 산출)
BAZEL            := $(shell command -v bazelisk 2>/dev/null || command -v bazel 2>/dev/null || true)
BAZEL_TARGET     := //platform/ios:MapLibre.dynamic
BAZEL_FLAGS      := --compilation_mode=opt --features=dead_strip,thin_lto --objc_enable_binary_stripping --apple_generate_dsym --output_groups=+dsyms --//:renderer=metal
# 필요시 정적 타깃/xcframework 타깃으로 교체 가능

# 공통
GIT              := $(shell command -v git 2>/dev/null || true)

.DEFAULT_GOAL := all

# ---------------- Targets ----------------

all: submodules doctor android ios
	@echo "==> ALL DONE"
	@echo "Artifacts in: $(DIST_DIR)"

android:
	@echo "==> ANDROID build start"
	@test -x "$(GRADLEW)" || { echo "Missing $(GRADLEW). Open submodule?"; exit 1; }
	cd "$(ANDROID_DIR)"
	"$(GRADLEW)" --version
	"$(GRADLEW)" clean $(ANDROID_TASK)
	mkdir -p "$(DIST_ANDROID_DIR)"
	# AAR/APK 수집
	set +e
	find "$(ANDROID_DIR)" -type f \( -name "*.aar" -o -name "*.apk" \) -print0 | xargs -0 -I{} bash -c 'dst="$(DIST_ANDROID_DIR)/$$(basename "{}")"; cp -f "{}" "$$dst"; echo "  -> $$dst";' || true
	set -e
	@echo "==> ANDROID build done"

ios: prepare_bazel_config
	@echo "==> iOS build start (Bazel)"
	@test -n "$(BAZEL)" || { echo "bazel/bazelisk not found. Install with: brew install bazelisk"; exit 1; }
	cd "$(ROOT_DIR)"
	"$(BAZEL)" build $(BAZEL_FLAGS) $(BAZEL_TARGET)
	mkdir -p "$(DIST_IOS_DIR)"
	# 산출물 수집 (xcframework/zip/dSYM 등)
	set +e
	find "$(ROOT_DIR)/bazel-bin" -type f \( -name "*.xcframework" -o -name "*.zip" -o -name "*.framework" -o -name "*.dSYM" \) -maxdepth 6 -print0 | \
	  xargs -0 -I{} bash -c 'base=$$(basename "{}"); dst="$(DIST_IOS_DIR)/$$base"; cp -R "{}" "$$dst" 2>/dev/null || rsync -a "{}" "$(DIST_IOS_DIR)/"; echo "  -> $(DIST_IOS_DIR)/$$base (or copied directory)";' || true
	set -e
	@echo "==> iOS build done"

prepare_bazel_config:
	@# Bazel 설정 파일이 없으면 예시로 채워 넣음
	if [ ! -f "$(ROOT_DIR)/platform/darwin/bazel/config.bzl" ]; then \
	  cp "$(ROOT_DIR)/platform/darwin/bazel/example_config.bzl" "$(ROOT_DIR)/platform/darwin/bazel/config.bzl"; \
	  echo "Created platform/darwin/bazel/config.bzl from example_config.bzl"; \
	fi

submodules:
	@test -n "$(GIT)" || { echo "git not found"; exit 1; }
	cd "$(ROOT_DIR)"
	"$(GIT)" submodule update --init --recursive

doctor:
	@echo "==> ENV CHECK"
	@echo "ROOT_DIR         = $(ROOT_DIR)"
	@echo "ANDROID_DIR      = $(ANDROID_DIR)"
	@echo "GRADLEW          = $(GRADLEW)"
	@echo "BAZEL            = $(BAZEL)"
	@test -x "$(GRADLEW)" || { echo "[WARN] $(GRADLEW) not executable yet (submodules?)."; }
	@test -n "$(BAZEL)" || { echo "[WARN] bazel/bazelisk not found (brew install bazelisk)."; }

clean:
	@echo "==> CLEAN"
	rm -rf "$(DIST_DIR)"
	# Android clean은 위에서 수행. 추가 캐시 정리 원하면 주석 해제
	# rm -rf "$(ANDROID_DIR)"/**/build

distclean: clean
	@echo "==> DISTCLEAN"
	rm -rf "$(ROOT_DIR)/bazel-bin" "$(ROOT_DIR)/bazel-out" "$(ROOT_DIR)/bazel-testlogs"
