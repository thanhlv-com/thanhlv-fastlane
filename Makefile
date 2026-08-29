# ==============================================================================
# Makefile - Bộ Công Cụ Quản Lý Fastlane & CI/CD Đa Nền Tảng (iOS, macOS, AOS)
# Repository: thanhlv-fastlane
# ==============================================================================

.PHONY: help \
        sync-workflows sync check-workflows check validate check-apps check-syntax check-all \
        install prepare-workspace clean-workspace \
        clean-certs clean-profiles push-api-key sync-certs-ios sync-certs-mac register-app-ios register-app-mac \
        ios-build ios-deploy mac-build mac-deploy aos-build aos-deploy windows-build linux-build \
        metadata-init metadata-pull metadata-push \
        ios-metadata-pull ios-metadata-push ios-metadata-download ios-metadata-upload \
        mac-metadata-pull mac-metadata-push mac-metadata-download mac-metadata-upload \
        aos-metadata-pull aos-metadata-push aos-metadata-download aos-metadata-upload \
        windows-metadata-push windows-metadata-upload linux-metadata-push linux-metadata-upload

# Màu sắc hiển thị terminal
CYAN    := \033[36m
GREEN   := \033[32m
YELLOW  := \033[33m
RED     := \033[31m
BLUE    := \033[34m
MAGENTA := \033[35m
RESET   := \033[0m
BOLD    := \033[1m

# Target mặc định
.DEFAULT_GOAL := help

## Hiển thị toàn bộ danh sách lệnh được hỗ trợ
help:
	@echo ""
	@echo "$(BOLD)$(CYAN)====================================================================$(RESET)"
	@echo "$(BOLD)$(CYAN)           THANHLV FASTLANE CI/CD MANAGEMENT TOOLKIT               $(RESET)"
	@echo "$(BOLD)$(CYAN)====================================================================$(RESET)"
	@echo ""
	@echo "$(BOLD)$(YELLOW)🎯 1. QUẢN LÝ GITHUB ACTIONS WORKFLOWS:$(RESET)"
	@echo "  $(GREEN)make sync-workflows$(RESET) (hoặc $(GREEN)make sync$(RESET))"
	@echo "      Quét fastlane/apps.json (theo ios, macos, aos) và tự động đồng bộ"
	@echo "      danh sách app vào input 'app' dạng dropdown choice trên GitHub Actions."
	@echo "  $(GREEN)make check-workflows$(RESET) (hoặc $(GREEN)make check$(RESET))"
	@echo "      Kiểm tra tính hợp lệ cú pháp YAML của tất cả workflows trong .github/workflows."
	@echo "  $(GREEN)make check-apps$(RESET)"
	@echo "      Kiểm tra cú pháp và cấu trúc file cấu hình fastlane/apps.json."
	@echo "  $(GREEN)make check-all$(RESET)"
	@echo "      Kiểm tra toàn diện: Cú pháp Ruby + YAML Workflows + JSON Apps."
	@echo ""
	@echo "$(BOLD)$(YELLOW)📦 2. QUẢN LÝ DEPENDENCIES & WORKSPACE:$(RESET)"
	@echo "  $(GREEN)make install$(RESET)"
	@echo "      Cài đặt các Gem dependencies (Fastlane & CocoaPods) qua Bundler."
	@echo "  $(GREEN)make prepare-workspace APP=<app_key> [REF=main] [FORCE=true]$(RESET)"
	@echo "      Tải/cập nhật source code cho 1 app cụ thể vào thư mục .workspace."
	@echo "  $(GREEN)make clean-workspace [APP=<app_key>]$(RESET)"
	@echo "      Dọn dẹp thư mục .workspace (của 1 app hoặc toàn bộ)."
	@echo ""
	@echo "$(BOLD)$(YELLOW)🔑 3. QUẢN LÝ CERTIFICATES & CODE SIGNING:$(RESET)"
	@echo "  $(GREEN)make sync-certs-ios [APP=OpsFlow_Hub] [TYPE=appstore]$(RESET)"
	@echo "      Đồng bộ Certificates & Profiles qua Match cho iOS (mặc định readonly)."
	@echo "  $(GREEN)make sync-certs-mac [APP=OpsFlow_Hub] [TYPE=appstore]$(RESET)"
	@echo "      Đồng bộ Certificates & Profiles qua Match cho macOS (mặc định readonly)."
	@echo "  $(GREEN)make clean-certs$(RESET)"
	@echo "      Dọn dẹp Certificate & Provisioning Profile cũ/hết hạn trên máy local."
	@echo "  $(GREEN)make clean-profiles$(RESET)"
	@echo "      Dọn dẹp Provisioning Profiles trên máy local."
	@echo "  $(GREEN)make push-api-key FILE=<path_to_p8> [KEY_ID=...] [ISSUER_ID=...]$(RESET)"
	@echo "      Mã hoá và push App Store Connect API Key lên Match Git repo."
	@echo "  $(GREEN)make register-app-ios APP=<app_key>$(RESET)"
	@echo "      Đăng ký Bundle Identifier & tạo App trên App Store Connect cho iOS."
	@echo "  $(GREEN)make register-app-mac APP=<app_key>$(RESET)"
	@echo "      Đăng ký Bundle Identifier & tạo App trên App Store Connect cho macOS."
	@echo ""
	@echo "$(BOLD)$(YELLOW)📝 4. ĐỒNG BỘ 2 CHIỀU METADATA & SCREENSHOTS (PULL & PUSH):$(RESET)"
	@echo "  $(GREEN)make metadata-init APP=<app_key> [PLATFORM=all|ios|macos|aos|windows|linux]$(RESET)"
	@echo "      Khởi tạo bộ thư mục metadata & screenshots mẫu chuẩn hoá cho app."
	@echo "  $(GREEN)make ios-metadata-pull APP=<app_key> [SKIP_SCREENSHOTS=false]$(RESET)"
	@echo "      Tải (Pull) Metadata & Screenshots từ App Store về local để chỉnh sửa."
	@echo "  $(GREEN)make ios-metadata-push APP=<app_key> [VERSION=1.0.0] [SCREENSHOTS=false] [SUBMIT=false]$(RESET)"
	@echo "      Đẩy (Push) Metadata & Screenshots từ local lên App Store Connect."
	@echo "  $(GREEN)make mac-metadata-pull APP=<app_key> [SKIP_SCREENSHOTS=false]$(RESET)"
	@echo "      Tải (Pull) Metadata & Screenshots từ Mac App Store về local để chỉnh sửa."
	@echo "  $(GREEN)make mac-metadata-push APP=<app_key> [VERSION=1.0.0] [SCREENSHOTS=false] [SUBMIT=false]$(RESET)"
	@echo "      Đẩy (Push) Metadata & Screenshots từ local lên Mac App Store."
	@echo "  $(GREEN)make aos-metadata-pull APP=<app_key>$(RESET)"
	@echo "      Tải (Pull) Metadata & Changelogs từ Google Play về local."
	@echo "  $(GREEN)make aos-metadata-push APP=<app_key> [SCREENSHOTS=false]$(RESET)"
	@echo "      Đẩy (Push) Metadata & Changelogs từ local lên Google Play Console."
	@echo ""
	@echo "$(BOLD)$(YELLOW)🚀 5. BUILD & PHÁT HÀNH LOCAL:$(RESET)"
	@echo "  $(GREEN)make ios-build APP=<app_key> [FLAVOR=...] [EXPORT_METHOD=app-store]$(RESET)"
	@echo "      Build iOS IPA trong thư mục .workspace."
	@echo "  $(GREEN)make ios-deploy APP=<app_key> [TARGET=testflight|appstore] [UPLOAD_METADATA=false]$(RESET)"
	@echo "      Build & Deploy iOS lên TestFlight hoặc App Store."
	@echo "  $(GREEN)make mac-build APP=<app_key> [FLAVOR=...]$(RESET)"
	@echo "      Build macOS PKG trong thư mục .workspace."
	@echo "  $(GREEN)make mac-deploy APP=<app_key> [TARGET=testflight|appstore] [UPLOAD_METADATA=false]$(RESET)"
	@echo "      Build & Deploy macOS lên TestFlight hoặc Mac App Store."
	@echo "  $(GREEN)make aos-build APP=<app_key> [TYPE=appbundle|apk]$(RESET)"
	@echo "      Build Android App Bundle (.aab) hoặc APK trong .workspace."
	@echo "  $(GREEN)make aos-deploy APP=<app_key> [TRACK=internal|alpha|beta|production]$(RESET)"
	@echo "      Build Android AAB & Deploy lên Google Play Console."
	@echo ""
	@echo "$(BOLD)$(CYAN)====================================================================$(RESET)"
	@echo ""

# ==============================================================================
# 1. QUẢN LÝ GITHUB ACTIONS WORKFLOWS & KIỂM TRA HỆ THỐNG
# ==============================================================================

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

## Kiểm tra tính hợp lệ của file fastlane/apps.json
check-apps:
	@ruby -rjson -e 'begin; data = JSON.parse(File.read("fastlane/apps.json")); puts "  \e[32m✔\e[0m fastlane/apps.json: Hợp lệ (#{data.keys.size} apps: #{data.keys.join(", ")})"; rescue => e; puts "  \e[31m✖\e[0m fastlane/apps.json lỗi: #{e.message}"; exit 1; end'

## Kiểm tra cú pháp Ruby của toàn bộ codebase Fastlane
check-syntax:
	@echo "$(CYAN)🔍 Đang kiểm tra cú pháp Ruby của Fastlane...$(RESET)"
	@ruby -c fastlane/Fastfile fastlane/Appfile fastlane/Matchfile fastlane/helpers/*.rb fastlane/lanes/*.rb scripts/*.rb

## Kiểm tra toàn diện hệ thống
check-all: check-syntax check-apps check-workflows
	@echo "$(BOLD)$(GREEN)🎉 Toàn bộ cú pháp Ruby, JSON và GitHub Actions YAML đều đạt chuẩn!$(RESET)"

# ==============================================================================
# 2. QUẢN LÝ DEPENDENCIES & WORKSPACE
# ==============================================================================

## Cài đặt dependencies Bundler
install:
	@echo "$(CYAN)📦 Đang cài đặt dependencies qua Bundler...$(RESET)"
	@bundle install

## Chuẩn bị source code trong workspace
prepare-workspace:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make prepare-workspace APP=OpsFlow_Hub [REF=main] [FORCE=true]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane prepare_workspace app:$(APP) ref:$${REF:-} force:$${FORCE:-false}

## Dọn dẹp thư mục .workspace
clean-workspace:
	@if [ -n "$(APP)" ]; then \
		echo "$(YELLOW)🧹 Đang dọn dẹp workspace cho app: $(APP)...$(RESET)"; \
		rm -rf .workspace/$(APP); \
	else \
		echo "$(YELLOW)🧹 Đang dọn dẹp toàn bộ thư mục .workspace...$(RESET)"; \
		rm -rf .workspace; \
	fi
	@echo "$(GREEN)✔ Hoàn tất dọn dẹp workspace.$(RESET)"

# ==============================================================================
# 3. QUẢN LÝ CERTIFICATES & CODE SIGNING
# ==============================================================================

## Dọn dẹp certs local
clean-certs:
	@bundle exec fastlane clean_local_certs

## Dọn dẹp provisioning profiles local
clean-profiles:
	@bundle exec fastlane clean_local_profiles

## Push App Store Connect API Key lên Match Git repo
push-api-key:
	@bundle exec fastlane push_api_key filepath:$${FILE:-} key_id:$${KEY_ID:-} issuer_id:$${ISSUER_ID:-}

## Đồng bộ certs qua Match cho iOS
sync-certs-ios:
	@bundle exec fastlane ios sync_certs app:$${APP:-} type:$${TYPE:-appstore} readonly:$${READONLY:-true}

## Đồng bộ certs qua Match cho macOS
sync-certs-mac:
	@bundle exec fastlane mac sync_certs app:$${APP:-} type:$${TYPE:-appstore} readonly:$${READONLY:-true}

## Đăng ký Bundle ID trên Apple Developer Portal cho iOS
register-app-ios:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make register-app-ios APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane ios register_app app:$(APP)

## Đăng ký Bundle ID trên Apple Developer Portal cho macOS
register-app-mac:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make register-app-mac APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane mac register_app app:$(APP)

# ==============================================================================
# 4. BUILD & DEPLOY CÁC NỀN TẢNG
# ==============================================================================

# iOS
ios-build:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make ios-build APP=OpsFlow_Hub [FLAVOR=...] [EXPORT_METHOD=app-store]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane ios build app:$(APP) flavor:$${FLAVOR:-} export_method:$${EXPORT_METHOD:-app-store}

ios-deploy:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make ios-deploy APP=OpsFlow_Hub [TARGET=testflight|appstore] [UPLOAD_METADATA=false]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane ios deploy app:$(APP) target:$${TARGET:-testflight} upload_metadata:$${UPLOAD_METADATA:-false} upload_screenshots:$${SCREENSHOTS:-false}

# macOS
mac-build:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make mac-build APP=OpsFlow_Hub [FLAVOR=...]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane mac build app:$(APP) flavor:$${FLAVOR:-}

mac-deploy:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make mac-deploy APP=OpsFlow_Hub [TARGET=testflight|appstore] [UPLOAD_METADATA=false]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane mac deploy app:$(APP) target:$${TARGET:-testflight} upload_metadata:$${UPLOAD_METADATA:-false} upload_screenshots:$${SCREENSHOTS:-false}

# Android / AOS
aos-build:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make aos-build APP=OpsFlow_Hub [TYPE=appbundle|apk]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane aos build app:$(APP) type:$${TYPE:-appbundle}

aos-deploy:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make aos-deploy APP=OpsFlow_Hub [TRACK=internal|alpha|beta|production]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane aos deploy app:$(APP) track:$${TRACK:-internal}

# Windows & Linux (Desktop Placeholders / Offline Builds)
windows-build:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make windows-build APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane windows build app:$(APP)

linux-build:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make linux-build APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane linux build app:$(APP)

# ==============================================================================
# 5. QUẢN LÝ & ĐỒNG BỘ 2 CHIỀU METADATA (PULL & PUSH)
# ==============================================================================

## Khởi tạo thư mục và các file Metadata template mẫu
metadata-init:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make metadata-init APP=OpsFlow_Hub [PLATFORM=all|ios|macos|aos|windows|linux]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane init_metadata app:$(APP) platform:$${PLATFORM:-all}

## Đẩy (Push) Metadata tổng quát
metadata-push:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make metadata-push APP=OpsFlow_Hub [PLATFORM=ios|macos|aos|windows|linux]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane push_metadata app:$(APP) platform:$${PLATFORM:-ios} version:$${VERSION:-} upload_screenshots:$${SCREENSHOTS:-false} submit_for_review:$${SUBMIT:-false}

## Tải (Pull) Metadata tổng quát
metadata-pull:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make metadata-pull APP=OpsFlow_Hub [PLATFORM=ios|macos|aos]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane pull_metadata app:$(APP) platform:$${PLATFORM:-ios} skip_screenshots:$${SKIP_SCREENSHOTS:-false}

# --- iOS (Apple App Store) ---
ios-metadata-push:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make ios-metadata-push APP=OpsFlow_Hub [VERSION=1.0.0] [SCREENSHOTS=false] [SUBMIT=false]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane ios push_metadata app:$(APP) version:$${VERSION:-} upload_screenshots:$${SCREENSHOTS:-false} submit_for_review:$${SUBMIT:-false}

ios-metadata-upload: ios-metadata-push

ios-metadata-pull:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make ios-metadata-pull APP=OpsFlow_Hub [SKIP_SCREENSHOTS=false]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane ios pull_metadata app:$(APP) skip_screenshots:$${SKIP_SCREENSHOTS:-false}

ios-metadata-download: ios-metadata-pull

# --- macOS (Mac App Store) ---
mac-metadata-push:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make mac-metadata-push APP=OpsFlow_Hub [VERSION=1.0.0] [SCREENSHOTS=false] [SUBMIT=false]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane mac push_metadata app:$(APP) version:$${VERSION:-} upload_screenshots:$${SCREENSHOTS:-false} submit_for_review:$${SUBMIT:-false}

mac-metadata-upload: mac-metadata-push

mac-metadata-pull:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make mac-metadata-pull APP=OpsFlow_Hub [SKIP_SCREENSHOTS=false]$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane mac pull_metadata app:$(APP) skip_screenshots:$${SKIP_SCREENSHOTS:-false}

mac-metadata-download: mac-metadata-pull

# --- Android / AOS (Google Play Store) ---
aos-metadata-push:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make aos-metadata-push APP=OpsFlow_Hub [SCREENSHOTS=false]$(RESET)"; \
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

# --- Windows (Microsoft Store / MSIX) ---
windows-metadata-push:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make windows-metadata-push APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane windows upload_metadata app:$(APP)

windows-metadata-upload: windows-metadata-push

# --- Linux (AppStream / Flatpak / Snapcraft) ---
linux-metadata-push:
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)❌ Vui lòng chỉ định app: make linux-metadata-push APP=OpsFlow_Hub$(RESET)"; \
		exit 1; \
	fi
	@bundle exec fastlane linux upload_metadata app:$(APP)

linux-metadata-upload: linux-metadata-push
