# fastlane/helpers/metadata_helper.rb
# Helper quản lý tải, cập nhật & cấu trúc Metadata đa nền tảng (iOS, macOS, Android/AOS, Windows, Linux)
# Screenshots được gộp trực tiếp vào thư mục metadata: fastlane/metadata/<app_key>/<platform>/screenshots/

require 'fileutils'
begin
  require 'fastlane_core'
  require 'fastlane_core/ui/ui'
rescue LoadError
end

module FastlaneCore
  class UI
    def self.message(msg); puts msg; end
    def self.success(msg); puts msg; end
    def self.important(msg); puts msg; end
    def self.error(msg); puts msg; end
    def self.user_error!(msg); raise msg; end
  end
end unless defined?(FastlaneCore::UI)

UI = FastlaneCore::UI unless defined?(UI)

# Danh sách toàn bộ các nền tảng hỗ trợ
SUPPORTED_METADATA_PLATFORMS = ["ios", "macos", "aos", "windows", "linux"].freeze

# Thư mục gốc chứa toàn bộ metadata tập trung trong repository thanhlv-fastlane
def metadata_root_path
  File.expand_path(File.join(__dir__, "..", "metadata"))
end

# Kiểm tra thư mục metadata có hợp lệ và chứa file metadata thực sự hay không
def has_valid_metadata_dir?(dir)
  return false unless dir && Dir.exist?(dir)

  # Đọc danh sách file bên trong (bỏ qua .gitkeep và .DS_Store)
  files = Dir.glob(File.join(dir, "**/*")).reject { |f| File.directory?(f) || File.basename(f) == ".gitkeep" || File.basename(f) == ".DS_Store" }
  !files.empty?
end

# Kiểm tra xem app có thư mục metadata tập trung trong fastlane/metadata/<app_key>/<platform> hay không
def has_central_metadata?(app_key, platform = nil)
  app_dir = File.join(metadata_root_path, app_key.to_s)
  return false unless Dir.exist?(app_dir)

  if platform && !platform.to_s.empty? && platform.to_s.downcase != "all"
    platform_norm = normalize_platform_name(platform)
    platform_dir = File.join(app_dir, platform_norm)
    has_valid_metadata_dir?(platform_dir)
  else
    Dir.children(app_dir).any? do |entry|
      sub = File.join(app_dir, entry)
      File.directory?(sub) && has_valid_metadata_dir?(sub)
    end
  end
end

# Đảm bảo workspace đã được clone/pull nếu app lưu metadata trực tiếp trong repo mã nguồn
def ensure_app_metadata_workspace!(app_key, app_info = nil, options = {}, platform = nil)
  platform_norm = normalize_platform_name(platform)

  # Nếu app đã có thư mục metadata tập trung hợp lệ tại fastlane/metadata/<app_key>/<platform>, không cần pull workspace
  return if has_central_metadata?(app_key, platform_norm)

  app_info ||= get_app_config(app_key)
  UI.message("📂 Không tìm thấy folder metadata trong #{metadata_root_path}/#{app_key}/#{platform_norm}.")
  UI.message("🔄 Metadata nằm trong repository của app. Đang pull repo về .workspace/#{app_key}...")

  # Kéo repository về .workspace (skip_pub_get để tối ưu tốc độ)
  prepare_app_workspace(app_key, app_info, options.merge(skip_pub_get: true), platform_norm)
end

# Xác định đường dẫn thư mục metadata tách biệt theo từng App và từng Platform:
# Quy tắc đường dẫn:
# 1. Nếu có folder hợp lệ trong fastlane/metadata/<app_key>/<platform>/ thì dùng fastlane/metadata/<app_key>/<platform>/
# 2. Nếu không có folder trong fastlane/metadata/, metadata sẽ ở trong repo với path: .workspace/<app_key>/metadata/<platform>/ (metadata/ios, metadata/macos, metadata/aos, ...)
def resolve_metadata_path(app_key, platform = "ios", options = {})
  if options[:metadata_path] && !options[:metadata_path].to_s.strip.empty?
    return File.expand_path(options[:metadata_path].to_s.strip)
  end

  platform_norm = normalize_platform_name(platform)
  central_app_dir = File.join(metadata_root_path, app_key.to_s)
  central_platform_dir = File.join(central_app_dir, platform_norm)

  # 1. Ưu tiên thư mục metadata tập trung trong thanhlv-fastlane nếu tồn tại VÀ chứa file metadata
  if has_valid_metadata_dir?(central_platform_dir)
    return central_platform_dir
  end

  # 2. Nếu không có folder trong fastlane/metadata/, lấy metadata trong thư mục của repo trong .workspace:
  # Path: metadata/ios, metadata/macos, metadata/aos, metadata/windows, metadata/linux
  workspace_dir = app_workspace_path(app_key)
  repo_metadata_platform_dir = File.join(workspace_dir, "metadata", platform_norm)
  repo_fastlane_metadata_platform_dir = File.join(workspace_dir, "fastlane", "metadata", platform_norm)

  # Platform alias dự phòng
  alt_platform_dir = case platform_norm
                     when "aos" then File.join(workspace_dir, "metadata", "android")
                     when "macos" then File.join(workspace_dir, "metadata", "mac")
                     else nil
                     end

  if has_valid_metadata_dir?(repo_metadata_platform_dir) || Dir.exist?(repo_metadata_platform_dir)
    repo_metadata_platform_dir
  elsif alt_platform_dir && (has_valid_metadata_dir?(alt_platform_dir) || Dir.exist?(alt_platform_dir))
    alt_platform_dir
  elsif has_valid_metadata_dir?(repo_fastlane_metadata_platform_dir) || Dir.exist?(repo_fastlane_metadata_platform_dir)
    repo_fastlane_metadata_platform_dir
  elsif Dir.exist?(workspace_dir)
    # Tạo folder metadata/<platform> ngay trong workspace repo của app (KHÔNG tạo trong fastlane/metadata/)
    FileUtils.mkdir_p(repo_metadata_platform_dir)
    repo_metadata_platform_dir
  else
    repo_metadata_platform_dir
  end
end

# Xác định đường dẫn thư mục screenshots (được gộp trực tiếp vào thư mục metadata của platform):
# Quy tắc đường dẫn: <metadata_path>/screenshots/ (hoặc <metadata_path>/images/ cho AOS)
def resolve_screenshots_path(app_key, platform = "ios", options = {})
  if options[:screenshots_path] && !options[:screenshots_path].to_s.strip.empty?
    return File.expand_path(options[:screenshots_path].to_s.strip)
  end

  platform_norm = normalize_platform_name(platform)
  metadata_dir = resolve_metadata_path(app_key, platform_norm, options)

  screenshots_dir = if platform_norm == "aos" && Dir.exist?(File.join(metadata_dir, "images"))
                      File.join(metadata_dir, "images")
                    else
                      File.join(metadata_dir, "screenshots")
                    end

  FileUtils.mkdir_p(screenshots_dir) unless Dir.exist?(screenshots_dir)
  screenshots_dir
end

# ==============================================================================
# DANH SÁCH 20 NGÔN NGỮ PHỔ BIẾN NHẤT TRÊN APP STORE & GOOGLE PLAY STORE
# ==============================================================================
TOP_20_METADATA_LOCALES = [
  "en-US",   # 1. Tiếng Anh (Hoa Kỳ) - English (US)
  "vi",      # 2. Tiếng Việt - Vietnamese
  "zh-Hans", # 3. Tiếng Trung Giản Thể - Chinese (Simplified)
  "zh-Hant", # 4. Tiếng Trung Phồn Thể - Chinese (Traditional)
  "ja",      # 5. Tiếng Nhật - Japanese
  "ko",      # 6. Tiếng Hàn - Korean
  "fr-FR",   # 7. Tiếng Pháp - French
  "de-DE",   # 8. Tiếng Đức - German
  "es-ES",   # 9. Tiếng Tây Ban Nha - Spanish
  "pt-BR",   # 10. Tiếng Bồ Đào Nha (Brazil) - Portuguese (Brazil)
  "ru",      # 11. Tiếng Nga - Russian
  "it",      # 12. Tiếng Ý - Italian
  "id",      # 13. Tiếng Indonesia - Indonesian
  "th",      # 14. Tiếng Thái - Thai
  "hi",      # 15. Tiếng Hindi (Ấn Độ) - Hindi
  "ar-SA",   # 16. Tiếng Ả Rập - Arabic
  "tr",      # 17. Tiếng Thổ Nhĩ Kỳ - Turkish
  "nl-NL",   # 18. Tiếng Hà Lan - Dutch
  "pl",      # 19. Tiếng Ba Lan - Polish
  "ms"       # 20. Tiếng Mã Lai - Malay
].freeze

# Chuẩn hoá tên thư mục locale theo từng platform (App Store / Deliver vs Google Play / Supply)
def normalize_locale_for_platform(locale, platform)
  norm_p = normalize_platform_name(platform)
  loc_str = locale.to_s.strip

  if norm_p == "aos"
    # Chuẩn locale cho Google Play Store (Supply)
    case loc_str
    when "vi", "vi_VN" then "vi-VN"
    when "zh-Hans", "zh-CN", "zh_CN", "zh" then "zh-CN"
    when "zh-Hant", "zh-TW", "zh_TW", "zh-HK", "zh_HK" then "zh-TW"
    when "ja", "ja_JP" then "ja-JP"
    when "ko", "ko_KR" then "ko-KR"
    when "ru", "ru_RU" then "ru-RU"
    when "it", "it_IT" then "it-IT"
    when "hi", "hi_IN" then "hi-IN"
    when "ar", "ar-SA", "ar_SA" then "ar"
    when "tr", "tr_TR" then "tr-TR"
    when "pl", "pl_PL" then "pl-PL"
    when "en", "en_US" then "en-US"
    when "fr", "fr_FR" then "fr-FR"
    when "de", "de_DE" then "de-DE"
    when "es", "es_ES" then "es-ES"
    when "pt", "pt_BR" then "pt-BR"
    when "nl", "nl_NL" then "nl-NL"
    else loc_str
    end
  else
    # Chuẩn locale cho Apple App Store Connect (Deliver) & Desktop
    case loc_str
    when "vi-VN", "vi_VN" then "vi"
    when "zh-CN", "zh_CN" then "zh-Hans"
    when "zh-TW", "zh_TW", "zh-HK", "zh_HK" then "zh-Hant"
    when "ja-JP", "ja_JP" then "ja"
    when "ko-KR", "ko_KR" then "ko"
    when "ru-RU", "ru_RU" then "ru"
    when "it-IT", "it_IT" then "it"
    when "hi-IN", "hi_IN" then "hi"
    when "ar", "ar_SA" then "ar-SA"
    when "tr-TR", "tr_TR" then "tr"
    when "pl-PL", "pl_PL" then "pl"
    when "en", "en_US" then "en-US"
    when "fr", "fr_FR" then "fr-FR"
    when "de", "de_DE" then "de-DE"
    when "es", "es_ES" then "es-ES"
    when "pt", "pt_BR" then "pt-BR"
    when "nl", "nl_NL" then "nl-NL"
    else loc_str
    end
  end
end

# Nhận diện locale base key để tra cứu từ điển
def resolve_locale_key(locale)
  loc = locale.to_s.strip.downcase.tr('_', '-')
  case loc
  when /^vi/ then "vi"
  when /^zh-hant|^zh-tw|^zh-hk|^zh-mo/ then "zh-Hant"
  when /^zh-hans|^zh-cn|^zh-sg|^zh/ then "zh-Hans"
  when /^ja/ then "ja"
  when /^ko/ then "ko"
  when /^fr/ then "fr-FR"
  when /^de/ then "de-DE"
  when /^es/ then "es-ES"
  when /^pt/ then "pt-BR"
  when /^ru/ then "ru"
  when /^it/ then "it"
  when /^id/ then "id"
  when /^th/ then "th"
  when /^hi/ then "hi"
  when /^ar/ then "ar-SA"
  when /^tr/ then "tr"
  when /^nl/ then "nl-NL"
  when /^pl/ then "pl"
  when /^ms/ then "ms"
  else "en-US"
  end
end

# Trả về metadata đa ngôn ngữ theo locale chuẩn cho toàn bộ 20 ngôn ngữ
def get_localized_metadata_for(locale, app_name, description = "")
  key = resolve_locale_key(locale)

  templates = {
    "en-US" => {
      ios_subtitle: "#{app_name} - Productivity & Automation",
      ios_features: "Key Features:\n• Optimized workflow management\n• Modern and intuitive user interface\n• Fast, secure, and reliable",
      ios_keywords: "tools, devops, utility, automation, productivity, thanhlv",
      ios_promo: "Experience a modern and efficient toolkit.",
      ios_release_notes: "Feature updates and performance improvements for iOS.",
      macos_subtitle: "#{app_name} for macOS",
      macos_features: "macOS Exclusive Highlights:\n• Native keyboard shortcuts and desktop integration\n• MenuBar and background task support\n• Optimized for Apple Silicon and Intel Macs",
      macos_keywords: "macos, devops, mac app, desktop utility, thanhlv",
      macos_promo: "Optimized desktop experience crafted for macOS.",
      macos_release_notes: "Latest release and enhancements for macOS.",
      aos_short_desc: "#{app_name} - Smart workflow management and utilities",
      aos_features: "Android Features:\n• Flexible task management on the go\n• Full compatibility with modern Android OS\n• Lightweight and battery-optimized\n• Modern Dark Mode support",
      aos_changelog: "Performance improvements and bug fixes.",
      windows_features: "Windows Highlights:\n• Built for Windows 10 and Windows 11\n• Modern Fluent Design UI\n• Native system tray and notification support",
      windows_release_notes: "Official release for Windows desktop.",
      windows_keywords: "windows, desktop, devops, productivity, thanhlv",
      linux_summary: "#{app_name} for Linux Desktop",
      linux_features: "Linux Highlights:\n• Packaged for Flatpak, Snap, and AppImage\n• Desktop environment compatible (GNOME, KDE Plasma, XFCE)\n• Native speed on x86_64 and ARM64 architectures",
      linux_release_notes: "Official release for Linux platforms."
    },
    "vi" => {
      ios_subtitle: "#{app_name} - Tiện ích & Tự động hoá",
      ios_features: "Tính năng chính:\n• Tối ưu hoá quy trình làm việc\n• Giao diện hiện đại, dễ sử dụng\n• Bảo mật và tốc độ cao",
      ios_keywords: "cong cu, devops, tien ich, tu dong hoa, hieu suat, thanhlv",
      ios_promo: "Trải nghiệm bộ công cụ hiện đại và tiện lợi.",
      ios_release_notes: "Cập nhật tính năng và cải thiện hiệu năng cho iOS.",
      macos_subtitle: "#{app_name} cho macOS",
      macos_features: "Đặc quyền trên macOS:\n• Tích hợp mượt mà với bàn phím và phím tắt macOS\n• Quản lý tác vụ nền và thanh MenuBar\n• Hiệu năng tối đa trên Apple Silicon & Intel",
      macos_keywords: "macos, devops, mac app, tien ich, thanhlv",
      macos_promo: "Phiên bản tối ưu hoá dành riêng cho máy Mac.",
      macos_release_notes: "Phát hành bản cập nhật mới nhất trên macOS.",
      aos_short_desc: "#{app_name} - Quản lý quy trình & tiện ích di động thông minh",
      aos_features: "Tính năng trên Android:\n• Quản lý tác vụ linh hoạt mọi lúc mọi nơi\n• Tương thích hoàn hảo với Android 10 trở lên\n• Tiết kiệm pin và tài nguyên hệ thống\n• Hỗ trợ chế độ Dark Mode",
      aos_changelog: "Cải tiến tính năng và sửa lỗi.",
      windows_features: "Tính năng trên Windows:\n• Tương thích Windows 10 & Windows 11\n• Hỗ trợ giao diện Fluent Design hiện đại\n• Tích hợp Windows Notifications và System Tray",
      windows_release_notes: "Bản phát hành chính thức trên Windows.",
      windows_keywords: "windows, desktop, devops, tien ich, thanhlv",
      linux_summary: "#{app_name} cho Linux Desktop",
      linux_features: "Tính năng trên Linux:\n• Đóng gói hỗ trợ Flatpak, Snap và AppImage\n• Tương thích các Desktop Environment (GNOME, KDE Plasma, XFCE)\n• Hiệu năng tối đa trên kiến trúc x86_64 và ARM64",
      linux_release_notes: "Bản phát hành chính thức cho nền tảng Linux."
    },
    "zh-Hans" => {
      ios_subtitle: "#{app_name} - 效率与自动化工具",
      ios_features: "主要功能：\n• 优化工作流程管理\n• 现代化直观用户界面\n• 快速、安全且稳定",
      ios_keywords: "工具, 效率, 自动化, 工作流, 开发, thanhlv",
      ios_promo: "体验现代化、高效率的工具套件。",
      ios_release_notes: "功能更新与 iOS 性能优化。",
      macos_subtitle: "#{app_name} macOS 专用版",
      macos_features: "macOS 专属亮点：\n• 原生键盘快捷键与系统深度集成\n• 状态栏 MenuBar 与后台任务支持\n• 针对 Apple Silicon 和 Intel 深度优化",
      macos_keywords: "macos, mac应用, 效率工具, 自动化, thanhlv",
      macos_promo: "专为 Mac 用户打造的桌面级高效体验。",
      macos_release_notes: "macOS 最新版本更新与稳定性提升。",
      aos_short_desc: "#{app_name} - 智能工作流与移动效率工具",
      aos_features: "Android 特性：\n• 随时随地灵活管理任务\n• 完美兼容现代 Android 系统\n• 轻量低耗，节省电量\n• 支持深色模式 (Dark Mode)",
      aos_changelog: "性能优化与问题修复。",
      windows_features: "Windows 亮点：\n• 完美适配 Windows 10 与 Windows 11\n• 现代化 Fluent Design 界面\n• 原生系统托盘与通知集成",
      windows_release_notes: "Windows 桌面版正式发布。",
      windows_keywords: "windows, 桌面应用, 效率, 自动化, thanhlv",
      linux_summary: "#{app_name} Linux 桌面版",
      linux_features: "Linux 亮点：\n• 支持 Flatpak、Snap 与 AppImage 打包\n• 兼容主流桌面环境 (GNOME, KDE, XFCE)\n• 针对 x86_64 与 ARM64 架构优化",
      linux_release_notes: "Linux 平台官方正式发布。"
    },
    "zh-Hant" => {
      ios_subtitle: "#{app_name} - 效率與自動化工具",
      ios_features: "主要功能：\n• 優化工作流程管理\n• 現代化直觀使用者介面\n• 快速、安全且穩定",
      ios_keywords: "工具, 效率, 自動化, 工作流, 開發, thanhlv",
      ios_promo: "體驗現代化、高效率的工具套件。",
      ios_release_notes: "功能更新與 iOS 效能優化。",
      macos_subtitle: "#{app_name} macOS 專用版",
      macos_features: "macOS 專屬亮點：\n• 原生鍵盤快捷鍵與系統深度整合\n• 狀態列 MenuBar 與背景任務支援\n• 針對 Apple Silicon 與 Intel 深度優化",
      macos_keywords: "macos, mac應用, 效率工具, 自動化, thanhlv",
      macos_promo: "專為 Mac 使用者打造的桌面級高效體驗。",
      macos_release_notes: "macOS 最新版本更新與穩定性提升。",
      aos_short_desc: "#{app_name} - 智慧工作流程與行動效率工具",
      aos_features: "Android 特性：\n• 隨時隨地靈活管理任務\n• 完美相容現代 Android 系統\n• 輕量低耗，節省電力\n• 支援深色模式 (Dark Mode)",
      aos_changelog: "效能優化與問題修正。",
      windows_features: "Windows 亮點：\n• 完美適配 Windows 10 與 Windows 11\n• 現代化 Fluent Design 介面\n• 原生系統匣與通知整合",
      windows_release_notes: "Windows 桌面版正式發布。",
      windows_keywords: "windows, 桌面應用, 效率, 自動化, thanhlv",
      linux_summary: "#{app_name} Linux 桌面版",
      linux_features: "Linux 亮點：\n• 支援 Flatpak、Snap 與 AppImage 打包\n• 相容主流桌面環境 (GNOME, KDE, XFCE)\n• 針對 x86_64 與 ARM64 架構優化",
      linux_release_notes: "Linux 平台官方正式發布。"
    },
    "ja" => {
      ios_subtitle: "#{app_name} - 業務効率化＆自動化",
      ios_features: "主な機能：\n• ワークフロー管理の最適化\n• モダンで直感的な操作画面\n• 高速、安全、高信頼性",
      ios_keywords: "ツール, 効率化, 自動化, ワークフロー, 開発, thanhlv",
      ios_promo: "モダンで快適なツール体験をお届けします。",
      ios_release_notes: "新機能の追加および iOS でのパフォーマンス向上。",
      macos_subtitle: "#{app_name} for macOS",
      macos_features: "macOS 専用機能：\n• ネイティブショートカットとシステム統合\n• メニューバー常駐とバックグラウンド処理\n• Apple Silicon および Intel に最適化",
      macos_keywords: "macos, macアプリ, 効率化ツール, 自動化, thanhlv",
      macos_promo: "Mac 向けに最適化されたデスクトップ体験。",
      macos_release_notes: "macOS 版の最新アップデートと機能改善。",
      aos_short_desc: "#{app_name} - スマートな業務効率化＆ユーティリティ",
      aos_features: "Android 版の特長：\n• いつでもどこでも柔軟なタスク管理\n• 最新の Android OS に完全対応\n• 軽量設計でバッテリー消費を抑制\n• ダークモード対応",
      aos_changelog: "パフォーマンス向上と不具合の修正。",
      windows_features: "Windows 版の特長：\n• Windows 10 / 11 に完全対応\n• モダンな Fluent Design UI\n• タスクトレイ常駐および通知機能",
      windows_release_notes: "Windows デスクトップ版の公式リリース。",
      windows_keywords: "windows, デスクトップ, 業務効率化, ツール, thanhlv",
      linux_summary: "#{app_name} Linux デスクトップ版",
      linux_features: "Linux 版の特長：\n• Flatpak、Snap、AppImage パッケージ対応\n• 主要デスクトップ環境 (GNOME, KDE, XFCE) 対応\n• x86_64 および ARM64 アーキテクチャに最適化",
      linux_release_notes: "Linux プラットフォーム向け公式リリース。"
    },
    "ko" => {
      ios_subtitle: "#{app_name} - 생산성 및 자동화 도구",
      ios_features: "주요 기능:\n• 업무 워크플로우 최적화\n• 직관적이고 현대적인 UI\n• 빠르고 안전한 신뢰성",
      ios_keywords: "도구, 생산성, 자동화, 워크플로우, 유틸리티, thanhlv",
      ios_promo: "더 빠르고 스마트한 업무 환경을 경험하세요.",
      ios_release_notes: "신규 기능 추가 및 iOS 성능 개선.",
      macos_subtitle: "#{app_name} macOS 전용",
      macos_features: "macOS 전용 하이라이트:\n• 네이티브 단축키 및 데스크톱 완벽 연동\n• 메뉴바 및 백그라운드 작업 지원\n• Apple Silicon 및 Intel Mac 최적화",
      macos_keywords: "macos, mac앱, 생산성도구, 자동화, thanhlv",
      macos_promo: "Mac 사용자를 위해 최적화된 데스크톱 앱.",
      macos_release_notes: "macOS 최신 업데이트 및 안정성 강화.",
      aos_short_desc: "#{app_name} - 스마트 워크플로우 및 모바일 생산성",
      aos_features: "Android 주요 기능:\n• 언제 어디서나 유연한 작업 관리\n• 최신 Android OS 완벽 지원\n• 가볍고 배터리 효율적인 최적화\n• 다크 모드 지원",
      aos_changelog: "성능 향상 및 버그 수정.",
      windows_features: "Windows 주요 기능:\n• Windows 10 및 Windows 11 완벽 지원\n• 모던 Fluent Design 인터페이스\n• 시스템 트레이 및 알림 연동",
      windows_release_notes: "Windows 데스크톱 공식 릴리즈.",
      windows_keywords: "windows, 데스크톱, 생산성, 자동화, thanhlv",
      linux_summary: "#{app_name} Linux 데스크톱",
      linux_features: "Linux 주요 기능:\n• Flatpak, Snap, AppImage 패키지 지원\n• 주요 데스크톱 환경 호환 (GNOME, KDE, XFCE)\n• x86_64 및 ARM64 네이티브 성능",
      linux_release_notes: "Linux 플랫폼 공식 릴리즈."
    },
    "fr-FR" => {
      ios_subtitle: "#{app_name} - Productivité & Outils",
      ios_features: "Fonctionnalités clés :\n• Gestion optimisée des flux de travail\n• Interface moderne et intuitive\n• Rapide, sécurisé et fiable",
      ios_keywords: "outils, devops, utilitaire, productivite, automatisation, thanhlv",
      ios_promo: "Découvrez une boîte à outils moderne et efficace.",
      ios_release_notes: "Mises à jour des fonctionnalités et améliorations des performances pour iOS.",
      macos_subtitle: "#{app_name} pour macOS",
      macos_features: "Points forts sur macOS :\n• Raccourcis clavier natifs et intégration macOS\n• Prise en charge de la barre de menus et des tâches de fond\n• Optimisé pour Apple Silicon et Intel",
      macos_keywords: "macos, devops, app mac, utilitaire bureau, thanhlv",
      macos_promo: "Une expérience de bureau optimisée conçue pour Mac.",
      macos_release_notes: "Dernière mise à jour et améliorations pour macOS.",
      aos_short_desc: "#{app_name} - Gestion intelligente et outils de productivité",
      aos_features: "Fonctionnalités Android :\n• Gestion fluide de vos tâches en mobilité\n• Compatibilité totale avec les versions récentes d'Android\n• Léger et optimisé pour la batterie\n• Prise en charge du mode sombre",
      aos_changelog: "Améliorations des performances et corrections de bugs.",
      windows_features: "Points forts sur Windows :\n• Conçu pour Windows 10 et Windows 11\n• Interface moderne Fluent Design\n• Intégration de la barre des tâches et des notifications",
      windows_release_notes: "Version officielle pour Windows.",
      windows_keywords: "windows, bureau, devops, productivite, thanhlv",
      linux_summary: "#{app_name} pour Linux Desktop",
      linux_features: "Points forts sur Linux :\n• Paquets Flatpak, Snap et AppImage\n• Compatible GNOME, KDE Plasma, XFCE\n• Performances natives sur x86_64 et ARM64",
      linux_release_notes: "Version officielle pour Linux."
    },
    "de-DE" => {
      ios_subtitle: "#{app_name} - Produktivität & Tools",
      ios_features: "Hauptmerkmale:\n• Optimiertes Workflow-Management\n• Moderne und intuitive Benutzeroberfläche\n• Schnell, sicher und zuverlässig",
      ios_keywords: "tools, devops, dienstprogramme, automatisierung, produktivitaet, thanhlv",
      ios_promo: "Erleben Sie ein modernes und effizientes Toolkit.",
      ios_release_notes: "Funktionsupdates und Leistungsverbesserungen für iOS.",
      macos_subtitle: "#{app_name} für macOS",
      macos_features: "macOS-Highlights:\n• Native Tastaturkurzbefehle und Desktop-Integration\n• Menüleisten- und Hintergrundaufgaben-Support\n• Optimiert für Apple Silicon und Intel",
      macos_keywords: "macos, devops, mac app, desktop utility, thanhlv",
      macos_promo: "Optimiertes Desktop-Erlebnis für macOS.",
      macos_release_notes: "Neueste Version und Verbesserungen für macOS.",
      aos_short_desc: "#{app_name} - Intelligentes Workflow-Management & Tools",
      aos_features: "Android-Funktionen:\n• Flexibles Aufgabenmanagement für unterwegs\n• Volle Kompatibilität mit modernem Android\n• Ressourcenschonend und akkuoptimiert\n• Unterstützung für Dunkelmodus",
      aos_changelog: "Leistungsverbesserungen und Fehlerbehebungen.",
      windows_features: "Windows-Highlights:\n• Entwickelt für Windows 10 und Windows 11\n• Moderne Fluent Design Benutzeroberfläche\n• System-Tray- und Benachrichtigungsintegration",
      windows_release_notes: "Offizielle Veröffentlichung für Windows.",
      windows_keywords: "windows, desktop, devops, produktivitaet, thanhlv",
      linux_summary: "#{app_name} für Linux Desktop",
      linux_features: "Linux-Highlights:\n• Unterstützung für Flatpak, Snap und AppImage\n• Kompatibel mit GNOME, KDE Plasma, XFCE\n• Native Geschwindigkeit auf x86_64 und ARM64",
      linux_release_notes: "Offizielle Veröffentlichung für Linux."
    },
    "es-ES" => {
      ios_subtitle: "#{app_name} - Productividad y Control",
      ios_features: "Características principales:\n• Gestión de flujos de trabajo optimizada\n• Interfaz de usuario moderna e intuitiva\n• Rápido, seguro y confiable",
      ios_keywords: "herramientas, devops, utilidad, automatizacion, productividad, thanhlv",
      ios_promo: "Descubre un conjunto de herramientas moderno y eficaz.",
      ios_release_notes: "Actualizaciones de funciones y mejoras de rendimiento para iOS.",
      macos_subtitle: "#{app_name} para macOS",
      macos_features: "Destacados en macOS:\n• Atajos de teclado nativos e integración de escritorio\n• Barra de menús y tareas en segundo plano\n• Optimizado para Apple Silicon e Intel",
      macos_keywords: "macos, devops, app mac, utilidad de escritorio, thanhlv",
      macos_promo: "Experiencia de escritorio optimizada diseñada para macOS.",
      macos_release_notes: "Última versión y mejoras para macOS.",
      aos_short_desc: "#{app_name} - Gestión inteligente de flujos de trabajo",
      aos_features: "Funciones en Android:\n• Gestión flexible de tareas en cualquier lugar\n• Compatibilidad total con Android moderno\n• Ligero y optimizado para ahorrar batería\n• Soporte para Modo Oscuro",
      aos_changelog: "Mejoras de rendimiento y corrección de errores.",
      windows_features: "Destacados en Windows:\n• Compatible con Windows 10 y Windows 11\n• Interfaz moderna Fluent Design\n• Integración con bandeja del sistema y notificaciones",
      windows_release_notes: "Lanzamiento oficial para Windows.",
      windows_keywords: "windows, escritorio, devops, productividad, thanhlv",
      linux_summary: "#{app_name} para Linux Desktop",
      linux_features: "Destacados en Linux:\n• Empaquetado en Flatpak, Snap y AppImage\n• Compatible con GNOME, KDE Plasma y XFCE\n• Rendimiento nativo en x86_64 y ARM64",
      linux_release_notes: "Lanzamiento oficial para Linux."
    },
    "pt-BR" => {
      ios_subtitle: "#{app_name} - Produtividade & Automação",
      ios_features: "Principais Recursos:\n• Gestão de fluxo de trabalho otimizada\n• Interface moderna e intuitiva\n• Rápido, seguro e confiável",
      ios_keywords: "ferramentas, devops, utilitarios, automacao, produtividade, thanhlv",
      ios_promo: "Experimente um conjunto de ferramentas moderno e eficiente.",
      ios_release_notes: "Atualizações de recursos e melhorias de desempenho para iOS.",
      macos_subtitle: "#{app_name} para macOS",
      macos_features: "Destaques no macOS:\n• Atalhos nativos de teclado e integração com o sistema\n• Suporte à barra de menus e tarefas em segundo plano\n• Otimizado para Apple Silicon e Intel",
      macos_keywords: "macos, devops, app mac, utilitarios, thanhlv",
      macos_promo: "Experiência de desktop otimizada criada para o macOS.",
      macos_release_notes: "Última versão e aprimoramentos para macOS.",
      aos_short_desc: "#{app_name} - Gestão inteligente de fluxos e tarefas",
      aos_features: "Recursos no Android:\n• Gerenciamento flexível de tarefas onde você estiver\n• Compatibilidade total com versões modernas do Android\n• Leve e econômico em bateria\n• Suporte ao Modo Escuro",
      aos_changelog: "Melhorias de desempenho e correções de bugs.",
      windows_features: "Destaques no Windows:\n• Compatível com Windows 10 e Windows 11\n• Interface moderna Fluent Design\n• Integração com bandeja do sistema e notificações",
      windows_release_notes: "Lançamento oficial para Windows.",
      windows_keywords: "windows, desktop, devops, produtividade, thanhlv",
      linux_summary: "#{app_name} para Linux Desktop",
      linux_features: "Destaques no Linux:\n• Suporte a pacotes Flatpak, Snap e AppImage\n• Compatível com GNOME, KDE Plasma e XFCE\n• Velocidade nativa em x86_64 e ARM64",
      linux_release_notes: "Lançamento oficial para a plataforma Linux."
    },
    "ru" => {
      ios_subtitle: "#{app_name} - Продуктивность и утилиты",
      ios_features: "Ключевые возможности:\n• Оптимизация рабочих процессов\n• Современный и понятный интерфейс\n• Высокая скорость, безопасность и надежность",
      ios_keywords: "инструменты, devops, утилиты, автоматизация, продуктивность, thanhlv",
      ios_promo: "Оцените современный и эффективный набор инструментов.",
      ios_release_notes: "Обновление функций и улучшение производительности для iOS.",
      macos_subtitle: "#{app_name} для macOS",
      macos_features: "Преимущества на macOS:\n• Нативные сочетания клавиш и глубокая интеграция\n• Поддержка MenuBar и фоновых задач\n• Оптимизация для Apple Silicon и Intel",
      macos_keywords: "macos, devops, mac приложение, утилиты, thanhlv",
      macos_promo: "Оптимизированное десктопное приложение для Mac.",
      macos_release_notes: "Последний релиз и улучшения для macOS.",
      aos_short_desc: "#{app_name} - Умное управление процессами и мобильные утилиты",
      aos_features: "Возможности на Android:\n• Удобное управление задачами в любом месте\n• Полная совместимость с современными версиями Android\n• Экономия заряда батареи и ресурсов\n• Поддержка темной темы (Dark Mode)",
      aos_changelog: "Повышение производительности и исправление ошибок.",
      windows_features: "Преимущества на Windows:\n• Создано для Windows 10 и Windows 11\n• Современный интерфейс Fluent Design\n• Интеграция с системным треем и уведомлениями",
      windows_release_notes: "Официальный релиз для Windows.",
      windows_keywords: "windows, десктоп, devops, продуктивность, thanhlv",
      linux_summary: "#{app_name} для Linux Desktop",
      linux_features: "Преимущества на Linux:\n• Поддержка пакетов Flatpak, Snap и AppImage\n• Совместимость с GNOME, KDE Plasma, XFCE\n• Нативная производительность на x86_64 и ARM64",
      linux_release_notes: "Официальный релиз для Linux."
    },
    "it" => {
      ios_subtitle: "#{app_name} - Produttività & Utility",
      ios_features: "Caratteristiche principali:\n• Gestione ottimizzata dei flussi di lavoro\n• Interfaccia moderna e intuitiva\n• Veloce, sicuro e affidabile",
      ios_keywords: "strumenti, devops, utilita, produttivita, automazione, thanhlv",
      ios_promo: "Scopri una suite di strumenti moderna ed efficiente.",
      ios_release_notes: "Aggiornamenti delle funzionalità e miglioramenti delle prestazioni per iOS.",
      macos_subtitle: "#{app_name} per macOS",
      macos_features: "Punti di forza su macOS:\n• Scorciatoie da tastiera native e integrazione desktop\n• Supporto per MenuBar e attività in background\n• Ottimizzato per Apple Silicon e Intel",
      macos_keywords: "macos, devops, app mac, utilita desktop, thanhlv",
      macos_promo: "Esperienza desktop ottimizzata creata per macOS.",
      macos_release_notes: "Ultima versione e miglioramenti per macOS.",
      aos_short_desc: "#{app_name} - Gestione intelligente dei flussi di lavoro",
      aos_features: "Funzionalità Android:\n• Gestione flessibile delle attività ovunque ti trovi\n• Piena compatibilità con Android moderno\n• Leggero e a basso consumo di batteria\n• Supporto per la modalità scura",
      aos_changelog: "Miglioramenti delle prestazioni e correzioni di bug.",
      windows_features: "Punti di forza su Windows:\n• Compatibile con Windows 10 e Windows 11\n• Interfaccia moderna Fluent Design\n• Integrazione con barra delle applicazioni e notifiche",
      windows_release_notes: "Rilascio ufficiale per Windows.",
      windows_keywords: "windows, desktop, devops, produttivita, thanhlv",
      linux_summary: "#{app_name} per Linux Desktop",
      linux_features: "Punti di forza su Linux:\n• Pacchetti Flatpak, Snap e AppImage\n• Compatibile con GNOME, KDE Plasma, XFCE\n• Velocità nativa su architetture x86_64 e ARM64",
      linux_release_notes: "Rilascio ufficiale per Linux."
    },
    "id" => {
      ios_subtitle: "#{app_name} - Produktivitas & Otomasi",
      ios_features: "Fitur Utama:\n• Optimalisasi manajemen alur kerja\n• Tampilan modern dan mudah digunakan\n• Cepat, aman, dan andal",
      ios_keywords: "alat, devops, utilitas, otomatisasi, produktivitas, thanhlv",
      ios_promo: "Nikmati rangkaian alat modern yang efisien.",
      ios_release_notes: "Pembaruan fitur dan peningkatan performa untuk iOS.",
      macos_subtitle: "#{app_name} untuk macOS",
      macos_features: "Keunggulan di macOS:\n• Pintasan keyboard bawaan dan integrasi desktop\n• Dukungan MenuBar dan proses latar belakang\n• Dioptimalkan untuk Apple Silicon dan Intel",
      macos_keywords: "macos, devops, aplikasi mac, utilitas desktop, thanhlv",
      macos_promo: "Pengalaman desktop optimal yang dirancang untuk Mac.",
      macos_release_notes: "Rilis terbaru dan peningkatan untuk macOS.",
      aos_short_desc: "#{app_name} - Manajemen alur kerja pintar & utilitas mobile",
      aos_features: "Fitur di Android:\n• Kelola tugas secara fleksibel kapan saja\n• Kompatibilitas penuh dengan Android modern\n• Ringan dan hemat penggunaan baterai\n• Dukungan Mode Gelap (Dark Mode)",
      aos_changelog: "Peningkatan performa dan perbaikan bug.",
      windows_features: "Keunggulan di Windows:\n• Dibuat untuk Windows 10 dan Windows 11\n• Tampilan modern Fluent Design\n• Integrasi system tray dan notifikasi",
      windows_release_notes: "Rilis resmi untuk Windows desktop.",
      windows_keywords: "windows, desktop, devops, produktivitas, thanhlv",
      linux_summary: "#{app_name} untuk Linux Desktop",
      linux_features: "Keunggulan di Linux:\n• Mendukung Flatpak, Snap, dan AppImage\n• Kompatibel với GNOME, KDE Plasma, XFCE\n• Kecepatan optimal pada arsitektur x86_64 & ARM64",
      linux_release_notes: "Rilis resmi untuk platform Linux."
    },
    "th" => {
      ios_subtitle: "#{app_name} - เพิ่มประสิทธิภาพและระบบอัตโนมัติ",
      ios_features: "คุณสมบัติเด่น:\n• จัดการกระบวนการทำงานอย่างมีประสิทธิภาพ\n• อินเทอร์เฟซทันสมัย ใช้งานง่าย\n• รวดเร็ว ปลอดภัย และเสถียร",
      ios_keywords: "เครื่องมือ, devops, ยูทิลิตี้, อัตโนมัติ, ผลผลิต, thanhlv",
      ios_promo: "สัมผัสประสบการณ์ชุดเครื่องมือที่ทันสมัยและสะดวกสบาย",
      ios_release_notes: "อัปเดตฟีเจอร์ใหม่และปรับปรุงประสิทธิภาพสำหรับ iOS",
      macos_subtitle: "#{app_name} สำหรับ macOS",
      macos_features: "จุดเด่นบน macOS:\n• รองรับปุ่มลัดและผสานการทำงานกับเดสก์ท็อป\n• รองรับ MenuBar และการทำงานเบื้องหลัง\n• ปรับแต่งเพื่อ Apple Silicon และ Intel",
      macos_keywords: "macos, devops, mac app, ยูทิลิตี้, thanhlv",
      macos_promo: "ประสบการณ์เดสก์ท็อปที่ออกแบบมาเพื่อ Mac โดยเฉพาะ",
      macos_release_notes: "เวอร์ชันล่าสุดและการปรับปรุงสำหรับ macOS",
      aos_short_desc: "#{app_name} - การจัดการเวิร์กโฟลว์อัจฉริยะและเครื่องมือพกพา",
      aos_features: "คุณสมบัติบน Android:\n• จัดการงานได้อย่างยืดหยุ่นทุกที่ทุกเวลา\n• รองรับ Android เวอร์ชันใหม่อย่างสมบูรณ์\n• ประหยัดแบตเตอรี่และทรัพยากรเครื่อง\n• รองรับโหมดมืด (Dark Mode)",
      aos_changelog: "ปรับปรุงประสิทธิภาพและแก้ไขข้อผิดพลาด",
      windows_features: "จุดเด่นบน Windows:\n• รองรับ Windows 10 และ Windows 11\n• ดีไซน์ Fluent Design ทันสมัย\n• ผสานกับ System Tray และการแจ้งเตือน",
      windows_release_notes: "เปิดตัวอย่างเป็นทางการสำหรับ Windows",
      windows_keywords: "windows, desktop, devops, เพิ่มประสิทธิภาพ, thanhlv",
      linux_summary: "#{app_name} สำหรับ Linux Desktop",
      linux_features: "จุดเด่นบน Linux:\n• รองรับ Flatpak, Snap และ AppImage\n• ใช้งานได้กับ GNOME, KDE Plasma, XFCE\n• ทำงานได้รวดเร็วบนสถาปัตยกรรม x86_64 และ ARM64",
      linux_release_notes: "เปิดตัวอย่างเป็นทางการสำหรับ Linux"
    },
    "hi" => {
      ios_subtitle: "#{app_name} - उत्पादकता और ऑटोमेशन",
      ios_features: "मुख्य विशेषताएं:\n• अनुकूलित वर्कफ़्लो प्रबंधन\n• आधुनिक और सहज यूज़र इंटरफ़ेस\n• तेज़, सुरक्षित और विश्वसनीय",
      ios_keywords: "टूल्स, devops, यूटिलिटी, ऑटोमेशन, उत्पादकता, thanhlv",
      ios_promo: "आधुनिक और कुशल टूलकिट का अनुभव करें।",
      ios_release_notes: "iOS के लिए नए फ़ीचर्स और परफ़ॉर्मेंस में सुधार।",
      macos_subtitle: "#{app_name} macOS के लिए",
      macos_features: "macOS की मुख्य विशेषताएं:\n• नेटिव कीबोर्ड शॉर्टकट और डेस्कटॉप एकीकरण\n• मेनूबार और बैकग्राउंड टास्क सपोर्ट\n• Apple Silicon और Intel के लिए अनुकूलित",
      macos_keywords: "macos, devops, mac app, डेस्कटॉप यूटिलिटी, thanhlv",
      macos_promo: "Mac के लिए तैयार किया गया बेहतरीन डेस्कटॉप अनुभव।",
      macos_release_notes: "macOS के लिए नवीनतम रिलीज़ और सुधार।",
      aos_short_desc: "#{app_name} - स्मार्ट वर्कफ़्लो और उत्पादकता यूटिलिटी",
      aos_features: "Android विशेषताएं:\n• कहीं भी आसानी से कार्य प्रबंधन करें\n• आधुनिक Android के साथ पूर्ण अनुकूलता\n• हल्का और बैटरी-अनुकूलित\n• डार्क मोड सपोर्ट",
      aos_changelog: "परफ़ॉर्मेंस में सुधार और बग फिक्स।",
      windows_features: "Windows विशेषताएं:\n• Windows 10 और Windows 11 के लिए निर्मित\n• आधुनिक Fluent Design इंटरफ़ेस\n• सिस्टम ट्रे और नोटिफ़िकेशन एकीकरण",
      windows_release_notes: "Windows डेस्कटॉप के लिए आधिकारिक रिलीज़।",
      windows_keywords: "windows, डेस्कटॉप, devops, उत्पादकता, thanhlv",
      linux_summary: "#{app_name} Linux डेस्कटॉप के लिए",
      linux_features: "Linux विशेषताएं:\n• Flatpak, Snap और AppImage पैकेज सपोर्ट\n• प्रमुख डेस्कटॉप वातावरण (GNOME, KDE, XFCE) के अनुकूल\n• x86_64 और ARM64 पर नेटिव गति",
      linux_release_notes: "Linux प्लेटफ़ॉर्म के लिए आधिकारिक रिलीज़।"
    },
    "ar-SA" => {
      ios_subtitle: "#{app_name} - الإنتاجية والأتمتة",
      ios_features: "الميزات الرئيسية:\n• إدارة محسّنة لسير العمل\n• واجهة مستخدم عصرية وسهلة الاستخدام\n• سريع وآمن وموثوق",
      ios_keywords: "أدوات, devops, إنتاجية, أتمتة, سير العمل, thanhlv",
      ios_promo: "استمتع بمجموعة أدوات حديثة وعالية الكفاءة.",
      ios_release_notes: "تحديثات الميزات وتحسينات الأداء لنظام iOS.",
      macos_subtitle: "#{app_name} لنظام macOS",
      macos_features: "أبرز مميزات macOS:\n• اختصارات لوحة المفاتيح وتكامل سطح المكتب\n• دعم شريط القوائم والمهام في الخلفية\n• محسّن لمعالجات Apple Silicon و Intel",
      macos_keywords: "macos, devops, تطبيق ماك, إنتاجية, thanhlv",
      macos_promo: "تجربة سطح مكتب محسّنة ومصممة خصيصاً لأجهزة Mac.",
      macos_release_notes: "أحدث إصدار وتحسينات لنظام macOS.",
      aos_short_desc: "#{app_name} - إدارة سير العمل وأدوات الإنتاجية الذكية",
      aos_features: "ميزات Android:\n• إدارة مهام مرنة في أي وقت وأي مكان\n• توافق تام مع أحدث أنظمة Android\n• استهلاك خفيف ومثالي للبطارية\n• دعم الوضع الداكن (Dark Mode)",
      aos_changelog: "تحسينات في الأداء وإصلاحات للأخطاء.",
      windows_features: "أبرز مميزات Windows:\n• متوافق مع Windows 10 و Windows 11\n• واجهة عصرية بتصميم Fluent Design\n• تكامل مع شريط النظام والإشعارات",
      windows_release_notes: "الإصدار الرسمي لنظام Windows.",
      windows_keywords: "windows, سطح المكتب, devops, إنتاجية, thanhlv",
      linux_summary: "#{app_name} لنظام Linux Desktop",
      linux_features: "أبرز مميزات Linux:\n• دعم حزم Flatpak و Snap و AppImage\n• متوافق مع بيئات سطح المكتب (GNOME, KDE, XFCE)\n• أداء سريع على بنيات x86_64 و ARM64",
      linux_release_notes: "الإصدار الرسمي لمنصة Linux."
    },
    "tr" => {
      ios_subtitle: "#{app_name} - Verimlilik ve Otomasyon",
      ios_features: "Öne Çıkan Özellikler:\n• Optimize edilmiş iş akışı yönetimi\n• Modern ve sezgisel kullanıcı arayüzü\n• Hızlı, güvenli ve kararlı",
      ios_keywords: "araçlar, devops, verimlilik, otomasyon, is akisi, thanhlv",
      ios_promo: "Modern ve verimli bir araç setini deneyimleyin.",
      ios_release_notes: "iOS için yeni özellikler ve performans iyileştirmeleri.",
      macos_subtitle: "#{app_name} macOS için",
      macos_features: "macOS Ayrıcalıkları:\n• Yerel klavye kısayolları ve masaüstü entegrasyonu\n• Menü Çubuğu (MenuBar) ve arka plan görevi desteği\n• Apple Silicon ve Intel işlemciler için optimize",
      macos_keywords: "macos, devops, mac uygulamasi, masaustu araclar, thanhlv",
      macos_promo: "Mac için özel olarak tasarlanmış masaüstü deneyimi.",
      macos_release_notes: "macOS için en son sürüm ve geliştirmeler.",
      aos_short_desc: "#{app_name} - Akıllı iş akışı yönetimi ve mobil araçlar",
      aos_features: "Android Özellikleri:\n• İstediğiniz yerde esnek görev yönetimi\n• Modern Android sürümleriyle tam uyumluluk\n• Hafif ve pil tasarruflu çalışma\n• Karanlık Mod (Dark Mode) desteği",
      aos_changelog: "Performans iyileştirmeleri ve hata düzeltmeleri.",
      windows_features: "Windows Özellikleri:\n• Windows 10 ve Windows 11 için geliştirildi\n• Modern Fluent Design arayüzü\n• Sistem tepsisi ve bildirim entegrasyonu",
      windows_release_notes: "Windows masaüstü için resmi sürüm.",
      windows_keywords: "windows, masaustu, devops, verimlilik, thanhlv",
      linux_summary: "#{app_name} Linux Masaüstü için",
      linux_features: "Linux Özellikleri:\n• Flatpak, Snap ve AppImage paket desteği\n• Masaüstü ortamlarıyla uyumlu (GNOME, KDE Plasma, XFCE)\n• x86_64 ve ARM64 mimarilerinde yerel hız",
      linux_release_notes: "Linux platformu için resmi sürüm."
    },
    "nl-NL" => {
      ios_subtitle: "#{app_name} - Productiviteit & Automatisering",
      ios_features: "Belangrijkste kenmerken:\n• Geoptimaliseerd workflowbeheer\n• Moderne en intuïtieve gebruikersinterface\n• Snel, veilig en betrouwbaar",
      ios_keywords: "tools, devops, hulpprogramma, automatisering, productiviteit, thanhlv",
      ios_promo: "Ervaar een moderne en efficiënte toolkit.",
      ios_release_notes: "Functie-updates en prestatieverbeteringen voor iOS.",
      macos_subtitle: "#{app_name} voor macOS",
      macos_features: "macOS-hoogtepunten:\n• Native sneltoetsen en desktopintegratie\n• Ondersteuning voor menubalk en achtergrondtaken\n• Geoptimaliseerd voor Apple Silicon en Intel",
      macos_keywords: "macos, devops, mac app, desktop utility, thanhlv",
      macos_promo: "Geoptimaliseerde desktopervaring gemaakt voor macOS.",
      macos_release_notes: "Nieuwste release en verbeteringen voor macOS.",
      aos_short_desc: "#{app_name} - Slim workflowbeheer & mobiele tools",
      aos_features: "Android-functies:\n• Flexibel taakbeheer onderweg\n• Volledige compatibiliteit met modern Android\n• Lichtgewicht en batterijbesparend\n• Ondersteuning voor donkere modus",
      aos_changelog: "Prestatieverbeteringen en bugfixes.",
      windows_features: "Windows-hoogtepunten:\n• Gebouwd voor Windows 10 en Windows 11\n• Moderne Fluent Design interface\n• Systeemvak- en meldingenintegratie",
      windows_release_notes: "Officiële release voor Windows desktop.",
      windows_keywords: "windows, desktop, devops, productiviteit, thanhlv",
      linux_summary: "#{app_name} voor Linux Desktop",
      linux_features: "Linux-hoogtepunten:\n• Ondersteuning voor Flatpak, Snap en AppImage\n• Compatibel met GNOME, KDE Plasma, XFCE\n• Native snelheid op x86_64 en ARM64",
      linux_release_notes: "Officiële release voor Linux-platforms."
    },
    "pl" => {
      ios_subtitle: "#{app_name} - Produktywność i Automatyzacja",
      ios_features: "Główne funkcje:\n• Zoptymalizowane zarządzanie przepływem pracy\n• Nowoczesny i intuicyjny interfejs\n• Szybki, bezpieczny i niezawodny",
      ios_keywords: "narzedzia, devops, uzytkowe, automatyzacja, produktywnosc, thanhlv",
      ios_promo: "Poznaj nowoczesny i wydajny zestaw narzędzi.",
      ios_release_notes: "Aktualizacje funkcji i ulepszenia wydajności dla systemu iOS.",
      macos_subtitle: "#{app_name} dla macOS",
      macos_features: "Wyróżniki na macOS:\n• Natywne skróty klawiszowe i integracja z pulpitem\n• Obsługa paska menu (MenuBar) i zadań w tle\n• Zoptymalizowany dla Apple Silicon i Intel",
      macos_keywords: "macos, devops, aplikacja mac, narzedzia, thanhlv",
      macos_promo: "Zoptymalizowana aplikacja desktopowa stworzona dla systemu macOS.",
      macos_release_notes: "Najnowsze wydanie i ulepszenia dla systemu macOS.",
      aos_short_desc: "#{app_name} - Inteligentne zarządzanie pracą i narzędzia",
      aos_features: "Funkcje w systemie Android:\n• Elastyczne zarządzanie zadaniami w podróży\n• Pełna zgodność z nowoczesnymi wersjami Androida\n• Lekka konstrukcja i oszczędność baterii\n• Obsługa trybu ciemnego (Dark Mode)",
      aos_changelog: "Poprawki wydajności i naprawa błędów.",
      windows_features: "Wyróżniki na Windows:\n• Stworzony dla Windows 10 i Windows 11\n• Nowoczesny interfejs Fluent Design\n• Integracja z zasobnikiem systemowym i powiadomieniami",
      windows_release_notes: "Oficjalne wydanie dla systemu Windows.",
      windows_keywords: "windows, pulpit, devops, produktywnosc, thanhlv",
      linux_summary: "#{app_name} dla Linux Desktop",
      linux_features: "Wyróżniki na Linux:\n• Obsługa pakietów Flatpak, Snap i AppImage\n• Zgodność ze środowiskami graficznymi (GNOME, KDE Plasma, XFCE)\n• Natywna wydajność na architekturach x86_64 i ARM64",
      linux_release_notes: "Oficjalne wydanie dla platformy Linux."
    },
    "ms" => {
      ios_subtitle: "#{app_name} - Produktiviti & Automasi",
      ios_features: "Ciri-ciri Utama:\n• Pengurusan aliran kerja yang dioptimumkan\n• Antara muka moden dan intuitif\n• Pantas, selamat dan boleh dipercayai",
      ios_keywords: "alat, devops, utiliti, automasi, produktiviti, thanhlv",
      ios_promo: "Alami set alatan moden dan serba cekap.",
      ios_release_notes: "Kemas kini ciri dan peningkatan prestasi untuk iOS.",
      macos_subtitle: "#{app_name} untuk macOS",
      macos_features: "Sorotan di macOS:\n• Pintasan papan kekunci asli dan integrasi desktop\n• Sokongan MenuBar dan tugas latar belakang\n• Dioptimumkan untuk Apple Silicon dan Intel",
      macos_keywords: "macos, devops, aplikasi mac, utiliti desktop, thanhlv",
      macos_promo: "Pengalaman desktop yang dioptimumkan khas untuk Mac.",
      macos_release_notes: "Keluaran terkini dan penambahbaikan untuk macOS.",
      aos_short_desc: "#{app_name} - Pengurusan aliran kerja pintar & utiliti mudah alih",
      aos_features: "Ciri-ciri pada Android:\n• Pengurusan tugasan fleksibel di mana sahaja\n• Keserasian penuh dengan Android moden\n• Ringan dan jimat bateri\n• Sokongan Mod Gelap (Dark Mode)",
      aos_changelog: "Peningkatan prestasi dan pembaikan pepijat.",
      windows_features: "Sorotan pada Windows:\n• Dibina untuk Windows 10 dan Windows 11\n• Antara muka moden Fluent Design\n• Integrasi dulang sistem dan pemberitahuan",
      windows_release_notes: "Keluaran rasmi untuk desktop Windows.",
      windows_keywords: "windows, desktop, devops, produktiviti, thanhlv",
      linux_summary: "#{app_name} untuk Linux Desktop",
      linux_features: "Sorotan pada Linux:\n• Sokongan pakej Flatpak, Snap dan AppImage\n• Serasi với persekitaran desktop (GNOME, KDE Plasma, XFCE)\n• Kelajuan asli pada seni bina x86_64 dan ARM64",
      linux_release_notes: "Keluaran rasmi untuk platform Linux."
    }
  }

  templates[key] || templates["en-US"]
end

# ==============================================================================
# KHỞI TẠO TEMPLATE METADATA VÀ SCREENSHOTS GỘP CHUNG THEO TỪNG NỀN TẢNG
# ==============================================================================

# Khởi tạo template cho iOS (Apple App Store)
def init_ios_metadata_template(target_dir, app_name, description, locales = TOP_20_METADATA_LOCALES)
  FileUtils.mkdir_p(target_dir)

  locales.each do |raw_locale|
    locale = normalize_locale_for_platform(raw_locale, "ios")
    locale_dir = File.join(target_dir, locale)
    FileUtils.mkdir_p(locale_dir)

    meta = get_localized_metadata_for(locale, app_name, description)
    files = {
      "name.txt" => app_name.slice(0, 30),
      "subtitle.txt" => meta[:ios_subtitle].slice(0, 30),
      "description.txt" => "#{description}\n\n#{meta[:ios_features]}",
      "keywords.txt" => meta[:ios_keywords].slice(0, 100),
      "promotional_text.txt" => meta[:ios_promo].slice(0, 170),
      "release_notes.txt" => meta[:ios_release_notes],
      "support_url.txt" => "https://facebook.com/lethanh9398",
      "marketing_url.txt" => "https://facebook.com/lethanh9398",
      "privacy_url.txt" => "https://static-cdn.thanhlv.com/html/app/privacy.html"
    }

    files.each do |filename, content|
      file_path = File.join(locale_dir, filename)
      File.write(file_path, content) unless File.exist?(file_path)
    end
  end

  general_files = {
    "copyright.txt" => "2026 thanhlv.com. All rights reserved.",
    "primary_category.txt" => "UTILITIES",
    "secondary_category.txt" => "DEVELOPER_TOOLS"
  }
  general_files.each do |filename, content|
    file_path = File.join(target_dir, filename)
    File.write(file_path, content) unless File.exist?(file_path)
  end

  review_dir = File.join(target_dir, "review_information")
  FileUtils.mkdir_p(review_dir)
  review_files = {
    "first_name.txt" => "Thanh",
    "last_name.txt" => "Le",
    "phone_number.txt" => "+84966211618",
    "email_address.txt" => "contact@thanhlv.com",
    "notes.txt" => "No special login required. iOS app is ready for full testing."
  }
  review_files.each do |filename, content|
    file_path = File.join(review_dir, filename)
    File.write(file_path, content) unless File.exist?(file_path)
  end

  # Thư mục Screenshots gộp trong thư mục metadata của iOS
  screenshots_dir = File.join(target_dir, "screenshots")
  FileUtils.mkdir_p(screenshots_dir)
  FileUtils.touch(File.join(screenshots_dir, ".gitkeep"))
end

# Khởi tạo template cho macOS (Mac App Store)
def init_macos_metadata_template(target_dir, app_name, description, locales = TOP_20_METADATA_LOCALES)
  FileUtils.mkdir_p(target_dir)

  locales.each do |raw_locale|
    locale = normalize_locale_for_platform(raw_locale, "macos")
    locale_dir = File.join(target_dir, locale)
    FileUtils.mkdir_p(locale_dir)

    meta = get_localized_metadata_for(locale, app_name, description)
    files = {
      "name.txt" => app_name.slice(0, 30),
      "subtitle.txt" => meta[:macos_subtitle].slice(0, 30),
      "description.txt" => "#{description}\n\n#{meta[:macos_features]}",
      "keywords.txt" => meta[:macos_keywords].slice(0, 100),
      "promotional_text.txt" => meta[:macos_promo].slice(0, 170),
      "release_notes.txt" => meta[:macos_release_notes],
      "support_url.txt" => "https://facebook.com/lethanh9398",
      "marketing_url.txt" => "https://facebook.com/lethanh9398",
      "privacy_url.txt" => "https://static-cdn.thanhlv.com/html/app/privacy.html"
    }

    files.each do |filename, content|
      file_path = File.join(locale_dir, filename)
      File.write(file_path, content) unless File.exist?(file_path)
    end
  end

  general_files = {
    "copyright.txt" => "2026 thanhlv.com. All rights reserved.",
    "primary_category.txt" => "UTILITIES",
    "secondary_category.txt" => "DEVELOPER_TOOLS"
  }
  general_files.each do |filename, content|
    file_path = File.join(target_dir, filename)
    File.write(file_path, content) unless File.exist?(file_path)
  end

  review_dir = File.join(target_dir, "review_information")
  FileUtils.mkdir_p(review_dir)
  review_files = {
    "first_name.txt" => "Thanh",
    "last_name.txt" => "Le",
    "phone_number.txt" => "+84966211618",
    "email_address.txt" => "contact@thanhlv.com",
    "notes.txt" => "macOS standalone application. No demo account needed."
  }
  review_files.each do |filename, content|
    file_path = File.join(review_dir, filename)
    File.write(file_path, content) unless File.exist?(file_path)
  end

  # Thư mục Screenshots gộp trong thư mục metadata của macOS
  screenshots_dir = File.join(target_dir, "screenshots")
  FileUtils.mkdir_p(screenshots_dir)
  FileUtils.touch(File.join(screenshots_dir, ".gitkeep"))
end

# Khởi tạo template cho Android / AOS (Google Play Store - Chuẩn Fastlane Supply)
def init_aos_metadata_template(target_dir, app_name, description, locales = TOP_20_METADATA_LOCALES)
  FileUtils.mkdir_p(target_dir)

  locales.each do |raw_locale|
    play_locale = normalize_locale_for_platform(raw_locale, "aos")
    locale_dir = File.join(target_dir, play_locale)
    changelogs_dir = File.join(locale_dir, "changelogs")
    FileUtils.mkdir_p(changelogs_dir)

    meta = get_localized_metadata_for(play_locale, app_name, description)
    files = {
      "title.txt" => app_name.slice(0, 30),
      "short_description.txt" => meta[:aos_short_desc].slice(0, 80),
      "full_description.txt" => "#{description}\n\n#{meta[:aos_features]}".slice(0, 4000),
      "video.txt" => ""
    }

    files.each do |filename, content|
      file_path = File.join(locale_dir, filename)
      File.write(file_path, content) unless File.exist?(file_path)
    end

    default_changelog = File.join(changelogs_dir, "default.txt")
    unless File.exist?(default_changelog)
      File.write(default_changelog, meta[:aos_changelog].slice(0, 500))
    end
  end

  general_files = {
    "contact_email.txt" => "contact@thanhlv.com",
    "contact_website.txt" => "https://thanhlv.com",
    "contact_phone.txt" => "+84966211618",
    "privacy_policy.txt" => "https://static-cdn.thanhlv.com/html/app/privacy.html"
  }
  general_files.each do |filename, content|
    file_path = File.join(target_dir, filename)
    File.write(file_path, content) unless File.exist?(file_path)
  end

  # Khởi tạo thư mục ảnh Google Play gộp trong metadata của AOS
  images_dir = File.join(target_dir, "images")
  FileUtils.mkdir_p(File.join(images_dir, "phoneScreenshots"))
  FileUtils.mkdir_p(File.join(images_dir, "sevenInchScreenshots"))
  FileUtils.mkdir_p(File.join(images_dir, "tenInchScreenshots"))
  FileUtils.touch(File.join(images_dir, "phoneScreenshots", ".gitkeep"))

  screenshots_dir = File.join(target_dir, "screenshots")
  FileUtils.mkdir_p(screenshots_dir)
  FileUtils.touch(File.join(screenshots_dir, ".gitkeep"))
end

# Khởi tạo template cho Windows (Microsoft Store / MSIX / Winget)
def init_windows_metadata_template(target_dir, app_name, description, locales = TOP_20_METADATA_LOCALES)
  FileUtils.mkdir_p(target_dir)

  locales.each do |raw_locale|
    locale = normalize_locale_for_platform(raw_locale, "windows")
    locale_dir = File.join(target_dir, locale)
    FileUtils.mkdir_p(locale_dir)

    meta = get_localized_metadata_for(locale, app_name, description)
    files = {
      "display_name.txt" => app_name,
      "publisher_display_name.txt" => "thanhlv.com",
      "description.txt" => "#{description}\n\n#{meta[:windows_features]}",
      "release_notes.txt" => meta[:windows_release_notes],
      "support_url.txt" => "https://facebook.com/lethanh9398",
      "privacy_url.txt" => "https://static-cdn.thanhlv.com/html/app/privacy.html",
      "keywords.txt" => meta[:windows_keywords]
    }

    files.each do |filename, content|
      file_path = File.join(locale_dir, filename)
      File.write(file_path, content) unless File.exist?(file_path)
    end
  end

  general_files = {
    "package_family_name.txt" => "",
    "store_product_id.txt" => "",
    "min_os_version.txt" => "10.0.17763.0"
  }
  general_files.each do |filename, content|
    file_path = File.join(target_dir, filename)
    File.write(file_path, content) unless File.exist?(file_path)
  end

  # Thư mục Screenshots gộp trong metadata Windows
  screenshots_dir = File.join(target_dir, "screenshots")
  FileUtils.mkdir_p(screenshots_dir)
  FileUtils.touch(File.join(screenshots_dir, ".gitkeep"))
end

# Khởi tạo template cho Linux (AppStream / Flatpak / Snapcraft / AppImage)
def init_linux_metadata_template(target_dir, app_name, description, locales = TOP_20_METADATA_LOCALES)
  FileUtils.mkdir_p(target_dir)

  locales.each do |raw_locale|
    locale = normalize_locale_for_platform(raw_locale, "linux")
    locale_dir = File.join(target_dir, locale)
    FileUtils.mkdir_p(locale_dir)

    meta = get_localized_metadata_for(locale, app_name, description)
    files = {
      "name.txt" => app_name,
      "summary.txt" => meta[:linux_summary],
      "description.txt" => "#{description}\n\n#{meta[:linux_features]}",
      "release_notes.txt" => meta[:linux_release_notes]
    }

    files.each do |filename, content|
      file_path = File.join(locale_dir, filename)
      File.write(file_path, content) unless File.exist?(file_path)
    end
  end

  general_files = {
    "project_license.txt" => "MIT",
    "developer_name.txt" => "Thanh Le",
    "url_homepage.txt" => "https://thanhlv.com",
    "url_help.txt" => "https://facebook.com/lethanh9398",
    "url_bugtracker.txt" => "https://github.com/thanhlv-com"
  }
  general_files.each do |filename, content|
    file_path = File.join(target_dir, filename)
    File.write(file_path, content) unless File.exist?(file_path)
  end

  # Thư mục Screenshots gộp trong metadata Linux
  screenshots_dir = File.join(target_dir, "screenshots")
  FileUtils.mkdir_p(screenshots_dir)
  FileUtils.touch(File.join(screenshots_dir, ".gitkeep"))
end

# Hàm tổng khởi tạo template cho 1 app theo nền tảng cụ thể hoặc tất cả nền tảng
def init_app_metadata_template(app_key, app_info = {}, platform = "all", locales = TOP_20_METADATA_LOCALES, options = {})
  app_name = app_info["app_name"] || app_key.to_s.tr("_", " ")
  description = app_info["description"] || "Ứng dụng #{app_name} được phát triển bởi thanhlv.com"

  selected_locales = if options[:locales] && !options[:locales].to_s.strip.empty?
                       options[:locales].is_a?(Array) ? options[:locales] : options[:locales].to_s.split(",").map(&:strip)
                     elsif locales.is_a?(String)
                       locales.split(",").map(&:strip)
                     else
                       locales
                     end
  selected_locales = TOP_20_METADATA_LOCALES if selected_locales.nil? || selected_locales.empty?

  target_platforms = if platform.nil? || platform.to_s.downcase == "all"
                       SUPPORTED_METADATA_PLATFORMS
                     else
                       [normalize_platform_name(platform)]
                     end

  target_platforms.each do |p|
    platform_norm = normalize_platform_name(p)
    target_dir = resolve_metadata_path(app_key, platform_norm, options)
    FileUtils.mkdir_p(target_dir)

    case platform_norm
    when "ios"
      init_ios_metadata_template(target_dir, app_name, description, selected_locales)
    when "macos"
      init_macos_metadata_template(target_dir, app_name, description, selected_locales)
    when "aos"
      init_aos_metadata_template(target_dir, app_name, description, selected_locales)
    when "windows"
      init_windows_metadata_template(target_dir, app_name, description, selected_locales)
    when "linux"
      init_linux_metadata_template(target_dir, app_name, description, selected_locales)
    end

    UI.success("✨ Đã tạo cấu trúc Metadata & Screenshots cho [#{platform_norm.upcase}] (#{selected_locales.count} ngôn ngữ) tại: #{target_dir}")
  end

  resolve_metadata_path(app_key, target_platforms.first, options)
end

# ==============================================================================
# HÀM TẢI SCREENSHOTS TRỰC TIẾP TỪ APP STORE CONNECT (SPACESHIP CONNECT API)
# ==============================================================================

def download_app_store_screenshots_direct(app, version, screenshots_dir, platform_code)
  require 'open-uri'
  require 'fileutils'

  FileUtils.mkdir_p(screenshots_dir)
  candidate_versions = []
  candidate_versions << version if version
  candidate_versions << (app.get_edit_app_store_version(platform: platform_code) rescue nil)
  candidate_versions << (app.get_live_app_store_version(platform: platform_code) rescue nil)
  candidate_versions << (app.get_latest_app_store_version(platform: platform_code) rescue nil)
  (app.get_app_store_versions(platform: platform_code) rescue []).each { |v| candidate_versions << v }
  candidate_versions = candidate_versions.compact.uniq

  downloaded_count = 0

  candidate_versions.each do |v|
    v_name = v.version_string rescue "current"
    localizations = v.get_app_store_version_localizations rescue []
    next if localizations.nil? || localizations.empty?

    localizations.each do |loc|
      locale = loc.locale
      screenshot_sets = loc.get_app_screenshot_sets rescue []
      next if screenshot_sets.nil? || screenshot_sets.empty?

      screenshot_sets.each do |set|
        display_type = set.screenshot_display_type || "SCREENSHOT"
        screenshots = set.app_screenshots || (set.get_app_screenshots rescue [])
        next if screenshots.nil? || screenshots.empty?

        locale_folder = if set.respond_to?(:apple_tv?) && set.apple_tv?
                          File.join(screenshots_dir, "appleTV", locale)
                        elsif set.respond_to?(:imessage?) && set.imessage?
                          File.join(screenshots_dir, "iMessage", locale)
                        else
                          File.join(screenshots_dir, locale)
                        end
        FileUtils.mkdir_p(locale_folder)

        screenshots.each_with_index do |shot, idx|
          raw_ext = File.extname(shot.file_name.to_s).delete(".").downcase
          ext = raw_ext.empty? ? "png" : raw_ext
          file_name = "#{idx + 1}_#{display_type}_#{idx + 1}.#{ext}"
          target_file = File.join(locale_folder, file_name)

          url = shot.image_asset_url(type: ext) || shot.image_asset_url(type: "png")
          if url.nil? || url.empty?
            UI.important("⚠️ Không lấy được link tải cho screenshot: #{shot.file_name}")
            next
          end

          UI.message("  📸 [#{locale}] Đang tải ảnh #{display_type} (Version #{v_name})...")
          begin
            image_data = URI.open(url, "rb").read
            File.binwrite(target_file, image_data)
            downloaded_count += 1
            UI.success("  ✔ Đã lưu: #{file_name} -> #{locale_folder}/")
          rescue => err
            UI.error("  ❌ Không thể tải file #{file_name}: #{err.message}")
          end
        end
      end
    end

    # Nếu đã tải được ảnh từ version ưu tiên thì không cần tải trùng từ version khác
    break if downloaded_count > 0
  end

  if downloaded_count > 0
    UI.success("🎉 Đã tải về thành công #{downloaded_count} ảnh Screenshots từ App Store Connect!")
  else
    UI.important("ℹ️ Không tìm thấy ảnh Screenshot nào trên App Store Connect cho nền tảng này.")
  end
end

# ==============================================================================
# THAO TÁC DOWNLOAD / UPLOAD METADATA ĐA NỀN TẢNG
# ==============================================================================

# Tải metadata và screenshots từ Store về thư mục local
def download_app_metadata_from_store(app_key, platform = "ios", options = {})
  app_info = get_app_config(app_key)

  if platform.to_s.downcase == "all"
    supported_platforms = app_info["platforms"] || SUPPORTED_METADATA_PLATFORMS
    supported_platforms.each do |p|
      download_app_metadata_from_store(app_key, p, options)
    end
    return
  end

  platform_norm = normalize_platform_name(platform)
  validate_platform_support!(app_key, app_info, platform_norm)

  # Nếu không có folder trong fastlane/metadata/<app_key>, kéo repo về .workspace trước
  ensure_app_metadata_workspace!(app_key, app_info, options, platform_norm)

  metadata_dir = resolve_metadata_path(app_key, platform_norm, options)
  screenshots_dir = resolve_screenshots_path(app_key, platform_norm, options)
  # Mặc định kéo (pull) toàn bộ cả text metadata và ảnh screenshots
  skip_screenshots = options[:skip_screenshots] == true || options[:skip_screenshots] == "true" || options[:screenshots] == false || options[:screenshots] == "false"

  UI.message("🌐 ========================================================")
  UI.message("🌐 Đang tải Metadata & Screenshots từ Store về máy local:")
  UI.message("🌐 App: #{app_info['app_name']} (#{app_key})")
  UI.message("🌐 Platform: #{platform_norm.upcase}")
  UI.message("🌐 Metadata Path: #{metadata_dir}")
  UI.message("🌐 Screenshots Path: #{screenshots_dir}")
  UI.message("🌐 Tải Screenshots kèm theo: #{!skip_screenshots}")
  UI.message("🌐 ========================================================")

  case platform_norm
  when "ios", "macos"
    bundle_id = resolve_bundle_id(app_info, platform_norm, options)
    api_key = get_api_key
    deliver_platform = (platform_norm == "macos") ? "osx" : "ios"

    begin
      require 'deliver'
      require 'deliver/setup'
      require 'deliver/options'
      require 'deliver/download_screenshots'
      require 'spaceship/connect_api'

      # Cấu hình Token API Key cho Spaceship Connect API
      if api_key
        if api_key.is_a?(Hash)
          begin
            Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(**api_key)
          rescue
            Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(api_key) rescue nil
          end
        elsif defined?(Spaceship::ConnectAPI::Token) && api_key.is_a?(Spaceship::ConnectAPI::Token)
          Spaceship::ConnectAPI.token = api_key
        end
      end

      UI.message("🔍 Đang tìm ứng dụng #{bundle_id} trên App Store Connect...")
      app = Spaceship::ConnectAPI::App.find(bundle_id)
      unless app
        UI.user_error!("❌ Không tìm thấy ứng dụng với Bundle ID '#{bundle_id}' trên App Store Connect!")
      end

      Deliver.cache ||= {}
      Deliver.cache[:app] = app

      platform_code = Spaceship::ConnectAPI::Platform.map(deliver_platform)
      version = if options[:version] && !options[:version].to_s.strip.empty?
                  app.get_app_store_versions(platform: platform_code, filter: { versionString: options[:version].to_s.strip }).first rescue nil
                end
      version ||= app.get_edit_app_store_version(platform: platform_code) ||
                  app.get_latest_app_store_version(platform: platform_code) rescue nil

      UI.message("📥 Đang trích xuất Metadata từ App Store Connect...")
      FileUtils.mkdir_p(metadata_dir)
      setup = Deliver::Setup.new
      setup.generate_metadata_files(app, version, metadata_dir, { use_live_version: (options[:use_live_version] == true) })

      unless skip_screenshots
        UI.message("📥 Đang tải Screenshots từ App Store Connect về #{screenshots_dir}...")
        download_app_store_screenshots_direct(app, version, screenshots_dir, platform_code)
      end
    rescue => e
      UI.error("⚠️ Lỗi khi pull metadata: #{e.message}")
      raise e
    end
  when "aos"
    package_name = resolve_bundle_id(app_info, "aos", options)
    json_key = ENV["SUPPLY_JSON_KEY"] || ENV["GOOGLE_PLAY_KEY_FILE"] || options[:json_key]
    json_key_data = ENV["SUPPLY_JSON_KEY_DATA"] || options[:json_key_data]

    supply_args = {
      package_name: package_name,
      metadata_path: metadata_dir,
      skip_upload_aab: true,
      skip_upload_apk: true,
      skip_upload_images: skip_screenshots,
      skip_upload_screenshots: skip_screenshots
    }
    supply_args[:json_key] = json_key if json_key && !json_key.empty?
    supply_args[:json_key_data] = json_key_data if json_key_data && !json_key_data.empty?

    sh("bundle exec fastlane supply init --package_name #{package_name} --metadata_path #{metadata_dir}") rescue nil
  when "windows", "linux"
    UI.important("ℹ️ Nền tảng #{platform_norm.upcase} hiện quản lý metadata offline tại: #{metadata_dir}")
  else
    UI.user_error!("Chưa hỗ trợ tải metadata tự động cho platform: #{platform_norm}")
  end

  UI.success("🎉 Hoàn tất tải Metadata cho #{app_key} [#{platform_norm.upcase}] về: #{metadata_dir}")
end

# Cập nhật metadata và screenshots từ local lên Store
def upload_app_metadata_to_store(app_key, platform = "ios", options = {})
  app_info = get_app_config(app_key)

  if platform.to_s.downcase == "all"
    supported_platforms = app_info["platforms"] || SUPPORTED_METADATA_PLATFORMS
    supported_platforms.each do |p|
      upload_app_metadata_to_store(app_key, p, options)
    end
    return
  end

  platform_norm = normalize_platform_name(platform)
  validate_platform_support!(app_key, app_info, platform_norm)

  # Nếu không có folder trong fastlane/metadata/<app_key>, kéo repo về .workspace trước
  ensure_app_metadata_workspace!(app_key, app_info, options, platform_norm)

  metadata_dir = resolve_metadata_path(app_key, platform_norm, options)
  screenshots_dir = resolve_screenshots_path(app_key, platform_norm, options)

  # Tự động tạo template chuẩn nếu thư mục metadata chưa tồn tại hoặc rỗng
  if !has_valid_metadata_dir?(metadata_dir)
    UI.important("⚠️ Thư mục metadata '#{metadata_dir}' chưa có dữ liệu. Đang khởi tạo template mẫu [#{platform_norm.upcase}]...")
    init_app_metadata_template(app_key, app_info, platform_norm, TOP_20_METADATA_LOCALES, options)
  end

  skip_screenshots = if options[:screenshots] == true || options[:screenshots] == "true" || options[:upload_screenshots] == true || options[:upload_screenshots] == "true"
                       false
                     elsif options[:skip_screenshots] == false || options[:skip_screenshots] == "false"
                       false
                     else
                       true
                     end

  app_version = options[:version] || options[:app_version] || app_info["version"]

  UI.message("🚀 ========================================================")
  UI.message("🚀 Đang cập nhật Metadata lên Store:")
  UI.message("🚀 App: #{app_info['app_name']} (#{app_key})")
  UI.message("🚀 Platform: #{platform_norm.upcase}")
  UI.message("🚀 Version: #{app_version || 'Mặc định'}")
  UI.message("🚀 Metadata Path: #{metadata_dir}")
  UI.message("🚀 Screenshots Path: #{screenshots_dir}")
  UI.message("🚀 Upload Screenshots: #{!skip_screenshots}")
  UI.message("🚀 ========================================================")

  case platform_norm
  when "ios", "macos"
    bundle_id = resolve_bundle_id(app_info, platform_norm, options)
    api_key = get_api_key
    deliver_platform = (platform_norm == "macos") ? "osx" : "ios"

    deliver_params = {
      api_key: api_key,
      app_identifier: bundle_id,
      platform: deliver_platform,
      metadata_path: metadata_dir,
      screenshots_path: screenshots_dir,
      ignore_language_directory_validation: true,
      skip_binary_upload: true,
      skip_metadata: false,
      skip_screenshots: skip_screenshots,
      skip_app_version_update: options[:skip_version_update] == true || options[:skip_version_update] == "true",
      force: true,
      submit_for_review: options[:submit_for_review] == true || options[:submit_for_review] == "true",
      automatic_release: options[:automatic_release] == true || options[:automatic_release] == "true",
      phased_release: options[:phased_release] == true || options[:phased_release] == "true",
      overwrite_screenshots: options[:overwrite_screenshots] == true || options[:overwrite_screenshots] == "true",
      reject_if_possible: options[:reject_if_possible] == true || options[:reject_if_possible] == "true",
      run_precheck_before_submit: false
    }
    deliver_params[:app_version] = app_version if app_version && !app_version.to_s.strip.empty?

    upload_to_app_store(deliver_params)

  when "aos"
    package_name = resolve_bundle_id(app_info, "aos", options)
    json_key = ENV["SUPPLY_JSON_KEY"] || ENV["GOOGLE_PLAY_KEY_FILE"] || options[:json_key]
    json_key_data = ENV["SUPPLY_JSON_KEY_DATA"] || options[:json_key_data]

    supply_args = {
      package_name: package_name,
      metadata_path: metadata_dir,
      skip_upload_aab: true,
      skip_upload_apk: true,
      skip_upload_images: skip_screenshots,
      skip_upload_screenshots: skip_screenshots,
      skip_upload_changelogs: false,
      check_superseded_tracks: true
    }
    supply_args[:json_key] = json_key if json_key && !json_key.empty?
    supply_args[:json_key_data] = json_key_data if json_key_data && !json_key_data.empty?

    upload_to_play_store(supply_args)

  when "windows", "linux"
    UI.success("📄 Đã xác thực và chuẩn bị đầy đủ bộ metadata offline cho [#{platform_norm.upcase}] tại: #{metadata_dir}")
  else
    UI.user_error!("Chưa hỗ trợ upload metadata cho platform: #{platform_norm}")
  end

  UI.success("🎉 Cập nhật thành công Metadata của #{app_key} lên Store [#{platform_norm.upcase}]!")
end
