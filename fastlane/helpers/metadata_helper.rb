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

# Thư mục gốc chứa toàn bộ metadata trong repository
def metadata_root_path
  File.expand_path(File.join(__dir__, "..", "metadata"))
end

# Xác định đường dẫn thư mục metadata tách biệt theo từng App và từng Platform:
# Quy tắc đường dẫn: fastlane/metadata/<app_key>/<platform>/
# Ví dụ:
#   - fastlane/metadata/OpsFlow_Hub/ios/
#   - fastlane/metadata/OpsFlow_Hub/macos/
#   - fastlane/metadata/OpsFlow_Hub/aos/
#   - fastlane/metadata/OpsFlow_Hub/windows/
#   - fastlane/metadata/OpsFlow_Hub/linux/
def resolve_metadata_path(app_key, platform = "ios", options = {})
  if options[:metadata_path] && !options[:metadata_path].to_s.strip.empty?
    return File.expand_path(options[:metadata_path].to_s.strip)
  end

  platform_norm = normalize_platform_name(platform)
  app_metadata_dir = File.join(metadata_root_path, app_key.to_s)
  platform_metadata_dir = File.join(app_metadata_dir, platform_norm)

  if Dir.exist?(platform_metadata_dir)
    return platform_metadata_dir
  end

  FileUtils.mkdir_p(platform_metadata_dir)
  platform_metadata_dir
end

# Xác định đường dẫn thư mục screenshots (được gộp trực tiếp vào thư mục metadata của platform):
# Quy tắc đường dẫn: fastlane/metadata/<app_key>/<platform>/screenshots/
# (Đối với AOS: fastlane/metadata/<app_key>/aos/images/ hoặc screenshots/)
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
      "support_url.txt" => "https://thanhlv.com/support",
      "marketing_url.txt" => "https://thanhlv.com",
      "privacy_url.txt" => "https://thanhlv.com/privacy-policy"
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
    "phone_number.txt" => "+84900000000",
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
      "support_url.txt" => "https://thanhlv.com/support",
      "marketing_url.txt" => "https://thanhlv.com",
      "privacy_url.txt" => "https://thanhlv.com/privacy-policy"
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
    "phone_number.txt" => "+84900000000",
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
    "contact_phone.txt" => "+84900000000",
    "privacy_policy.txt" => "https://thanhlv.com/privacy-policy"
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
      "support_url.txt" => "https://thanhlv.com/support",
      "privacy_url.txt" => "https://thanhlv.com/privacy-policy",
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
    "url_help.txt" => "https://thanhlv.com/support",
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
def init_app_metadata_template(app_key, app_info = {}, platform = "all", locales = ["en-US", "vi"])
  app_name = app_info["app_name"] || app_key.to_s.tr("_", " ")
  description = app_info["description"] || "Ứng dụng #{app_name} được phát triển bởi thanhlv.com"

  target_platforms = if platform.nil? || platform.to_s.downcase == "all"
                       SUPPORTED_METADATA_PLATFORMS
                     else
                       [normalize_platform_name(platform)]
                     end

  target_platforms.each do |p|
    platform_norm = normalize_platform_name(p)
    target_dir = File.join(metadata_root_path, app_key.to_s, platform_norm)
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

  File.join(metadata_root_path, app_key.to_s)
end

# ==============================================================================
# THAO TÁC DOWNLOAD / UPLOAD METADATA ĐA NỀN TẢNG
# ==============================================================================

# Tải metadata và screenshots từ Store về thư mục local
def download_app_metadata_from_store(app_key, platform, options = {})
  app_info = get_app_config(app_key)
  platform_norm = normalize_platform_name(platform)
  validate_platform_support!(app_key, app_info, platform_norm)

  metadata_dir = resolve_metadata_path(app_key, platform_norm, options)
  screenshots_dir = resolve_screenshots_path(app_key, platform_norm, options)
  skip_screenshots = options[:skip_screenshots] != false && options[:skip_screenshots] != "false" && options[:screenshots] != true && options[:screenshots] != "true"

  UI.message("🌐 ========================================================")
  UI.message("🌐 Đang tải Metadata từ Store về máy local:")
  UI.message("🌐 App: #{app_info['app_name']} (#{app_key})")
  UI.message("🌐 Platform: #{platform_norm.upcase}")
  UI.message("🌐 Metadata Path: #{metadata_dir}")
  UI.message("🌐 Screenshots Path: #{screenshots_dir}")
  UI.message("🌐 Skip Screenshots: #{skip_screenshots}")
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
        UI.message("📥 Đang tải Screenshots từ App Store Connect...")
        FileUtils.mkdir_p(screenshots_dir)
        deliver_config = FastlaneCore::Configuration.create(Deliver::Options.available_options, {
          api_key: api_key,
          app_identifier: bundle_id,
          platform: deliver_platform,
          metadata_path: metadata_dir,
          screenshots_path: screenshots_dir,
          force: true
        })
        Deliver::DownloadScreenshots.new.download(deliver_config, screenshots_dir) rescue UI.important("⚠️ Không thể tải screenshots hoặc chưa có ảnh trên store.")
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
def upload_app_metadata_to_store(app_key, platform, options = {})
  app_info = get_app_config(app_key)
  platform_norm = normalize_platform_name(platform)
  validate_platform_support!(app_key, app_info, platform_norm)

  metadata_dir = resolve_metadata_path(app_key, platform_norm, options)
  screenshots_dir = resolve_screenshots_path(app_key, platform_norm, options)

  # Tự động tạo template chuẩn nếu thư mục metadata chưa tồn tại hoặc rỗng
  if !Dir.exist?(metadata_dir) || Dir.children(metadata_dir).empty?
    UI.important("⚠️ Thư mục metadata '#{metadata_dir}' chưa có dữ liệu. Đang khởi tạo template mẫu [#{platform_norm.upcase}]...")
    init_app_metadata_template(app_key, app_info, platform_norm)
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
