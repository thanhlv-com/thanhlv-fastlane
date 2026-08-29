# ==============================================================================
# Makefile - Quản lý Fastlane & Tự động đồng bộ cấu hình GitHub Actions
# Repository: thanhlv-fastlane
# ==============================================================================

.PHONY: help sync-workflows sync check-workflows validate install clean-certs clean-profiles ios-build ios-deploy mac-build mac-deploy aos-build aos-deploy ios-metadata-upload ios-metadata-download ios-metadata-push ios-metadata-pull mac-metadata-upload mac-metadata-download mac-metadata-push mac-metadata-pull aos-metadata-upload aos-metadata-download aos-metadata-push aos-metadata-pull metadata-init metadata-push metadata-pull

# Màu sắc hiển thị terminal
CYAN    := \033[36m
GREEN   := \033[32m
YELLOW  := \033[33m
RED     := \033[31m
RESET   := \033[0m
BOLD    := \033[1m

# Target mặc định
.DEFAULT_GOAL := help

## Hiển thị danh sách các lệnh hỗ trợ
help:
	@echo ""
	@echo "$(BOLD)$(CYAN)====================================================================$(RESET)"
	@echo "$(BOLD)$(CYAN)           THANHLV FASTLANE CI/CD MANAGEMENT TOOLKIT               $(RESET)"
	@echo "$(BOLD)$(CYAN)====================================================================$(RESET)"
	@echo ""
	@echo "$(BOLD)$(YELLOW)🎯 QUẢN LÝ GITHUB ACTIONS WORKFLOWS:$(RESET)"
	@echo "  $(GREEN)make sync-workflows$(RESET) (hoặc $(GREEN)make sync$(RESET))"
	@echo "      Quét fastlane/apps.json (theo ios, macos, aos) và tự động cập nhật"
	@echo "      input 'app' thành type choice kèm options tương ứng trong GitHub Actions."
	@echo ""
	@echo "  $(GREEN)make check-workflows$(RESET) (hoặc $(GREEN)make check$(RESET))"
	@echo "      Kiểm tra cú pháp YAML của toàn bộ các file GitHub Actions Workflows."
	@echo ""
	@echo "$(BOLD)$(YELLOW)📦 QUẢN LÝ DEPENDENCIES & WORKSPACE:$(RESET)"
	@echo "  $(GREEN)make install$(RESET)"
	@echo "      Cài đặt Gemfile dependencies (Fastlane & CocoaPods) qua Bundler."
	@echo ""
	@echo "  $(GREEN)make prepare-workspace APP=<app_key>$(RESET)"
	@echo "      Tải/cập nhật source code cho 1 app cụ thể vào thư mục .workspace."
	@echo ""
	@echo "$(BOLD)$(YELLOW)🔑 QUẢN LÝ CERTIFICATES & PROFILES:$(RESET)"
	@echo "  $(GREEN)make clean-certs$(RESET)    - Dọn dẹp certs & profiles cũ/hết hạn trên máy local"
	@echo "  $(GREEN)make clean-profiles$(RESET) - Dọn dẹp provisioning profiles cũ trên máy local"
	@echo "  $(GREEN)make sync-certs-ios$(RESET)  - Đồng bộ certs qua Match cho iOS"
	@echo "  $(GREEN)make sync-certs-mac$(RESET)  - Đồng bộ certs qua Match cho macOS"
	@echo ""
	@echo "$(BOLD)$(YELLOW)📝 QUẢN LÝ & ĐỒNG BỘ 2 CHIỀU METADATA (PULL & PUSH):$(RESET)"
	@echo "  $(GREEN)make metadata-init APP=OpsFlow_Hub [PLATFORM=all|ios|macos|aos|windows|linux]$(RESET)"
	@echo "      Khởi tạo bộ thư mục metadata mẫu tách biệt theo từng nền tảng."
	@echo "  $(GREEN)make ios-metadata-pull APP=OpsFlow_Hub$(RESET)   - Tải (Pull) metadata iOS từ App Store về local để sửa"
	@echo "  $(GREEN)make ios-metadata-push APP=OpsFlow_Hub$(RESET)   - Đẩy (Push) metadata iOS từ local lên App Store"
	@echo "  $(GREEN)make mac-metadata-pull APP=OpsFlow_Hub$(RESET)   - Tải (Pull) metadata macOS từ Mac App Store về local để sửa"
	@echo "  $(GREEN)make mac-metadata-push APP=OpsFlow_Hub$(RESET)   - Đẩy (Push) metadata macOS từ local lên Mac App Store"
	@echo "  $(GREEN)make aos-metadata-pull APP=OpsFlow_Hub$(RESET)   - Tải (Pull) metadata Android từ Google Play về local"
	@echo "  $(GREEN)make aos-metadata-push APP=OpsFlow_Hub$(RESET)   - Đẩy (Push) metadata Android từ local lên Google Play"
	@echo ""
	@echo "$(BOLD)$(YELLOW)🚀 THỰC THI FASTLANE LOCAL:$(RESET)"
	@echo "  $(GREEN)make ios-build APP=OpsFlow_Hub$(RESET)   - Build iOS IPA"
	@echo "  $(GREEN)make ios-deploy APP=OpsFlow_Hub$(RESET)  - Deploy iOS lên TestFlight"
	@echo "  $(GREEN)make mac-build APP=OpsFlow_Hub$(RESET)   - Build macOS PKG"
	@echo "  $(GREEN)make mac-deploy APP=OpsFlow_Hub$(RESET)  - Deploy macOS lên TestFlight"
	@echo "  $(GREEN)make aos-build APP=OpsFlow_Hub$(RESET)   - Build Android AAB/APK"
	@echo "  $(GREEN)make aos-deploy APP=OpsFlow_Hub$(RESET)  - Deploy Android lên Google Play"
	@echo ""
	@echo "$(BOLD)$(CYAN)====================================================================$(RESET)"
	@echo ""

## Tự động quét fastlane/apps.json và cập nhật input type choice cho GitHub Actions
sync-workflows:
	@echo "$(BOLD)$(CYAN)🚀 Đang quét fastlane/apps.json và cập nhật các file GitHub Actions...$(RESET)"
	@ruby scripts/sync_workflow_apps.rb
	@echo ""
	@echo "$(BOLD)$(GREEN)✨ Đang kiểm tra lại tính hợp lệ của các file YAML sau cập nhật...$(RESET)"
	@$(MAKE) check-workflows

sync: sync-workflows

## Kiểm tra cú pháp YAML của tất cả các file workflow
check-workflows:
	@ruby -ryaml -e 'Dir.glob(".github/workflows/*.yml").each { |f| begin; YAML.load_file(f); puts "  \e[32m✔\e[0m #{f}: Hợp lệ"; rescue => e; puts "  \e[31m✖\e[0m #{f}: Lỗi - #{e.message}"; exit 1; end }'

check: check-workflows
validate: check-workflows

## Cài đặt dependencies Bundler
install:
	@echo "$(CYAN)📦 Đang cài đặt dependencies qua Bundler...$(RESET)"
	@bundle install

## Chuẩn bị source code trong workspace
prepare-workspace:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make prepare-workspace APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane prepare_workspace app:$(APP)

## Dọn dẹp certs local
clean-certs:
	@bundle exec fastlane clean_local_certs

clean-profiles:
	@bundle exec fastlane clean_local_profiles

sync-certs-ios:
	@bundle exec fastlane ios sync_certs readonly:true

sync-certs-mac:
	@bundle exec fastlane mac sync_certs readonly:true

## Build & Deploy shortcuts
ios-build:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make ios-build APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane ios build app:$(APP)

ios-deploy:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make ios-deploy APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane ios deploy app:$(APP) target:$${TARGET:-testflight}

mac-build:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make mac-build APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane mac build app:$(APP)

mac-deploy:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make mac-deploy APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane mac deploy app:$(APP) target:$${TARGET:-testflight}

aos-build:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make aos-build APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane aos build app:$(APP) type:$${TYPE:-appbundle}

aos-deploy:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make aos-deploy APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane aos deploy app:$(APP) track:$${TRACK:-internal}

## Quản lý & Đồng bộ 2 Chiều Metadata (Pull từ Store & Push lên Store)
metadata-init:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make metadata-init APP=OpsFlow_Hub [PLATFORM=all|ios|macos|aos|windows|linux]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane init_metadata app:$(APP) platform:$${PLATFORM:-all}

metadata-push:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make metadata-push APP=OpsFlow_Hub [PLATFORM=ios|macos|aos]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane push_metadata app:$(APP) platform:$${PLATFORM:-ios} version:$${VERSION:-} upload_screenshots:$${SCREENSHOTS:-false} submit_for_review:$${SUBMIT:-false}

metadata-pull:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make metadata-pull APP=OpsFlow_Hub [PLATFORM=ios|macos|aos]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane pull_metadata app:$(APP) platform:$${PLATFORM:-ios} skip_screenshots:$${SKIP_SCREENSHOTS:-false}

# iOS (Apple App Store)
ios-metadata-push:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make ios-metadata-push APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane ios push_metadata app:$(APP) version:$${VERSION:-} upload_screenshots:$${SCREENSHOTS:-false} submit_for_review:$${SUBMIT:-false}

ios-metadata-upload: ios-metadata-push

ios-metadata-pull:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make ios-metadata-pull APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane ios pull_metadata app:$(APP) skip_screenshots:$${SKIP_SCREENSHOTS:-false}

ios-metadata-download: ios-metadata-pull

# macOS (Mac App Store)
mac-metadata-push:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make mac-metadata-push APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane mac push_metadata app:$(APP) version:$${VERSION:-} upload_screenshots:$${SCREENSHOTS:-false} submit_for_review:$${SUBMIT:-false}

mac-metadata-upload: mac-metadata-push

mac-metadata-pull:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make mac-metadata-pull APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane mac pull_metadata app:$(APP) skip_screenshots:$${SKIP_SCREENSHOTS:-false}

mac-metadata-download: mac-metadata-pull

# Android / AOS (Google Play Store)
aos-metadata-push:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make aos-metadata-push APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane aos push_metadata app:$(APP) upload_screenshots:$${SCREENSHOTS:-false}

aos-metadata-upload: aos-metadata-push

aos-metadata-pull:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make aos-metadata-pull APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane aos pull_metadata app:$(APP)

aos-metadata-download: aos-metadata-pull

