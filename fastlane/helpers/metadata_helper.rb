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
# KHỞI TẠO TEMPLATE METADATA VÀ SCREENSHOTS GỘP CHUNG THEO TỪNG NỀN TẢNG
# ==============================================================================

# Khởi tạo template cho iOS (Apple App Store)
def init_ios_metadata_template(target_dir, app_name, description, locales = ["en-US", "vi"])
  FileUtils.mkdir_p(target_dir)

  locales.each do |locale|
    locale_dir = File.join(target_dir, locale)
    FileUtils.mkdir_p(locale_dir)

    is_vi = locale.downcase.start_with?("vi")
    files = {
      "name.txt" => is_vi ? app_name : app_name,
      "subtitle.txt" => is_vi ? "#{app_name} - Tiện ích & Tự động hoá" : "#{app_name} - Productivity & Automation",
      "description.txt" => is_vi ?
        "#{description}\n\nTính năng chính:\n• Tối ưu hoá quy trình làm việc\n• Giao diện hiện đại, dễ sử dụng\n• Bảo mật và tốc độ cao" :
        "#{description}\n\nKey Features:\n• Optimized workflow management\n• Modern and intuitive user interface\n• Fast, secure, and reliable",
      "keywords.txt" => is_vi ? "cong cu, devops, tien ich, tu dong hoa, thanhlv" : "tools, devops, utility, automation, thanhlv",
      "promotional_text.txt" => is_vi ? "Trải nghiệm bộ công cụ hiện đại và tiện lợi." : "Experience a modern and efficient toolkit.",
      "release_notes.txt" => is_vi ? "Cập nhật tính năng và cải thiện hiệu năng cho iOS." : "Feature updates and performance improvements for iOS.",
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
def init_macos_metadata_template(target_dir, app_name, description, locales = ["en-US", "vi"])
  FileUtils.mkdir_p(target_dir)

  locales.each do |locale|
    locale_dir = File.join(target_dir, locale)
    FileUtils.mkdir_p(locale_dir)

    is_vi = locale.downcase.start_with?("vi")
    files = {
      "name.txt" => app_name,
      "subtitle.txt" => is_vi ? "#{app_name} cho macOS" : "#{app_name} for macOS",
      "description.txt" => is_vi ?
        "#{description}\n\nĐặc quyền trên macOS:\n• Tích hợp mượt mà với bàn phím và phím tắt macOS\n• Quản lý tác vụ nền và thanh MenuBar\n• Hiệu năng tối đa trên Apple Silicon & Intel" :
        "#{description}\n\nmacOS Exclusive Highlights:\n• Native keyboard shortcuts and desktop integration\n• MenuBar and background task support\n• Optimized for Apple Silicon and Intel Macs",
      "keywords.txt" => is_vi ? "macos, devops, mac app, tien ich, thanhlv" : "macos, devops, mac app, desktop utility, thanhlv",
      "promotional_text.txt" => is_vi ? "Phiên bản tối ưu hoá dành riêng cho máy Mac." : "Optimized desktop experience crafted for macOS.",
      "release_notes.txt" => is_vi ? "Phát hành bản cập nhật mới nhất trên macOS." : "Latest release and enhancements for macOS.",
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
def init_aos_metadata_template(target_dir, app_name, description, locales = ["en-US", "vi"])
  FileUtils.mkdir_p(target_dir)

  locales.each do |locale|
    play_locale = locale == "vi" ? "vi-VN" : locale
    locale_dir = File.join(target_dir, play_locale)
    changelogs_dir = File.join(locale_dir, "changelogs")
    FileUtils.mkdir_p(changelogs_dir)

    is_vi = play_locale.downcase.start_with?("vi")
    files = {
      "title.txt" => app_name.slice(0, 30),
      "short_description.txt" => (is_vi ? "#{app_name} - Quản lý quy trình & tiện ích di động thông minh" : "#{app_name} - Smart workflow management and utilities").slice(0, 80),
      "full_description.txt" => is_vi ?
        "#{description}\n\nTính năng trên Android:\n• Quản lý tác vụ linh hoạt mọi lúc mọi nơi\n• Tương thích hoàn hảo với Android 10 trở lên\n• Tiết kiệm pin và tài nguyên hệ thống\n• Hỗ trợ chế độ Dark Mode" :
        "#{description}\n\nAndroid Features:\n• Flexible task management on the go\n• Full compatibility with modern Android OS\n• Lightweight and battery-optimized\n• Modern Dark Mode support",
      "video.txt" => ""
    }

    files.each do |filename, content|
      file_path = File.join(locale_dir, filename)
      File.write(file_path, content) unless File.exist?(file_path)
    end

    default_changelog = File.join(changelogs_dir, "default.txt")
    unless File.exist?(default_changelog)
      File.write(default_changelog, is_vi ? "Cải tiến tính năng và sửa lỗi." : "Performance improvements and bug fixes.")
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
def init_windows_metadata_template(target_dir, app_name, description, locales = ["en-US", "vi"])
  FileUtils.mkdir_p(target_dir)

  locales.each do |locale|
    locale_dir = File.join(target_dir, locale)
    FileUtils.mkdir_p(locale_dir)

    is_vi = locale.downcase.start_with?("vi")
    files = {
      "display_name.txt" => app_name,
      "publisher_display_name.txt" => "thanhlv.com",
      "description.txt" => is_vi ?
        "#{description}\n\nTính năng trên Windows:\n• Tương thích Windows 10 & Windows 11\n• Hỗ trợ giao diện Fluent Design hiện đại\n• Tích hợp Windows Notifications và System Tray" :
        "#{description}\n\nWindows Highlights:\n• Built for Windows 10 and Windows 11\n• Modern Fluent Design UI\n• Native system tray and notification support",
      "release_notes.txt" => is_vi ? "Bản phát hành chính thức trên Windows." : "Official release for Windows desktop.",
      "support_url.txt" => "https://facebook.com/lethanh9398",
      "privacy_url.txt" => "https://static-cdn.thanhlv.com/html/app/privacy.html",
      "keywords.txt" => "windows, desktop, devops, productivity, thanhlv"
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
def init_linux_metadata_template(target_dir, app_name, description, locales = ["en-US", "vi"])
  FileUtils.mkdir_p(target_dir)

  locales.each do |locale|
    locale_dir = File.join(target_dir, locale)
    FileUtils.mkdir_p(locale_dir)

    is_vi = locale.downcase.start_with?("vi")
    files = {
      "name.txt" => app_name,
      "summary.txt" => is_vi ? "#{app_name} cho Linux Desktop" : "#{app_name} for Linux Desktop",
      "description.txt" => is_vi ?
        "#{description}\n\nTính năng trên Linux:\n• Đóng gói hỗ trợ Flatpak, Snap và AppImage\n• Tương thích các Desktop Environment (GNOME, KDE Plasma, XFCE)\n• Hiệu năng tối đa trên kiến trúc x86_64 và ARM64" :
        "#{description}\n\nLinux Highlights:\n• Packaged for Flatpak, Snap, and AppImage\n• Desktop environment compatible (GNOME, KDE Plasma, XFCE)\n• Native speed on x86_64 and ARM64 architectures",
      "release_notes.txt" => is_vi ? "Bản phát hành chính thức cho nền tảng Linux." : "Official release for Linux platforms."
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
def init_app_metadata_template(app_key, app_info = {}, platform = "all", locales = ["en-US", "vi"], options = {})
  app_name = app_info["app_name"] || app_key.to_s.tr("_", " ")
  description = app_info["description"] || "Ứng dụng #{app_name} được phát triển bởi thanhlv.com"

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
      init_ios_metadata_template(target_dir, app_name, description, locales)
    when "macos"
      init_macos_metadata_template(target_dir, app_name, description, locales)
    when "aos"
      init_aos_metadata_template(target_dir, app_name, description, locales)
    when "windows"
      init_windows_metadata_template(target_dir, app_name, description, locales)
    when "linux"
      init_linux_metadata_template(target_dir, app_name, description, locales)
    end

    UI.success("✨ Đã tạo cấu trúc Metadata & Screenshots cho [#{platform_norm.upcase}] tại: #{target_dir}")
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
    init_app_metadata_template(app_key, app_info, platform_norm, ["en-US", "vi"], options)
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
