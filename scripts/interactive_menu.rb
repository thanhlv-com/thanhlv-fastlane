#!/usr/bin/env ruby
# frozen_string_literal: true

# scripts/interactive_menu.rb
# Giao diện dòng lệnh tương tác (Interactive CLI) tự động quét Apps & tham số

require 'json'
require 'fileutils'

# Định nghĩa mã màu ANSI cho Terminal
module Colors
  CYAN    = "\e[36m"
  GREEN   = "\e[32m"
  YELLOW  = "\e[33m"
  RED     = "\e[31m"
  BLUE    = "\e[34m"
  MAGENTA = "\e[35m"
  RESET   = "\e[0m"
  BOLD    = "\e[1m"
  DIM     = "\e[2m"
end

class InteractiveMenu
  include Colors

  APPS_FILE = File.expand_path(File.join(__dir__, '..', 'fastlane', 'apps.json'))

  def initialize
    @apps = load_apps
  end

  def run
    loop do
      clear_screen
      print_header

      puts "#{BOLD}👉 Chọn thao tác bạn muốn thực hiện:#{RESET}"
      puts "  #{GREEN}1)#{RESET} 🚀 Deploy App (iOS TestFlight/AppStore, macOS, Android Play Store)"
      puts "  #{GREEN}2)#{RESET} 🔨 Build App (iOS IPA, macOS PKG, Android AAB/APK)"
      puts "  #{GREEN}3)#{RESET} 📥 Pull Metadata & Screenshots (Từ Store về Local để sửa)"
      puts "  #{GREEN}4)#{RESET} 📤 Push Metadata & Screenshots (Từ Local lên Store)"
      puts "  #{GREEN}5)#{RESET} 📝 Khởi tạo thư mục Metadata template mẫu (Init)"
      puts "  #{GREEN}6)#{RESET} 🔑 Đồng bộ Certificates & Profiles (Match)"
      puts "  #{GREEN}7)#{RESET} 📦 Quản lý Workspace (Clone / Update source code)"
      puts "  #{GREEN}8)#{RESET} 🎯 Đồng bộ GitHub Actions Workflows (Sync Choices)"
      puts "  #{GREEN}9)#{RESET} 🔍 Kiểm tra toàn diện hệ thống (Check All)"
      puts "  #{RED}0)#{RESET} ❌ Thoát"
      puts ""

      choice = prompt_input("Nhập lựa chọn của bạn [0-9]", "0")

      case choice
      when "1" then handle_deploy
      when "2" then handle_build
      when "3" then handle_metadata_pull
      when "4" then handle_metadata_push
      when "5" then handle_metadata_init
      when "6" then handle_sync_certs
      when "7" then handle_prepare_workspace
      when "8" then execute_command("make sync-workflows")
      when "9" then execute_command("make check-all")
      when "0", "q", "exit"
        puts "\n#{GREEN}Tạm biệt! Hẹn gặp lại bạn. 👋#{RESET}\n"
        exit 0
      else
        puts "#{RED}⚠️ Lựa chọn không hợp lệ, vui lòng thử lại!#{RESET}"
        sleep 1
      end
    end
  end

  private

  def load_apps
    unless File.exist?(APPS_FILE)
      puts "#{RED}❌ Không tìm thấy file: #{APPS_FILE}#{RESET}"
      exit 1
    end
    JSON.parse(File.read(APPS_FILE))
  rescue => e
    puts "#{RED}❌ Lỗi đọc file fastlane/apps.json: #{e.message}#{RESET}"
    exit 1
  end

  def clear_screen
    print "\e[H\e[2J"
  end

  def print_header
    puts "#{BOLD}#{CYAN}====================================================================#{RESET}"
    puts "#{BOLD}#{CYAN}         THANHLV FASTLANE INTERACTIVE ASSISTANT (CLI MENU)          #{RESET}"
    puts "#{BOLD}#{CYAN}====================================================================#{RESET}"
    puts "#{DIM}  💡 Tự động quét cấu hình từ fastlane/apps.json (#{@apps.keys.size} apps đang có)#{RESET}"
    puts ""
  end

  # ============================================================================
  # HELPERS FOR PROMPTS
  # ============================================================================

  def prompt_input(label, default = nil)
    if default && !default.to_s.empty?
      print "#{BOLD}#{label}#{RESET} #{DIM}[#{default}]#{RESET}: "
    else
      print "#{BOLD}#{label}#{RESET}: "
    end
    input = gets&.strip
    (input.nil? || input.empty?) ? default : input
  end

  def prompt_choice(title, options_list, default_idx = 0)
    puts "\n#{BOLD}#{YELLOW}📋 #{title}:#{RESET}"
    options_list.each_with_index do |opt, idx|
      default_marker = (idx == default_idx) ? " #{CYAN}(Mặc định)#{RESET}" : ""
      puts "  #{GREEN}#{idx + 1})#{RESET} #{opt[:label]}#{default_marker}"
    end
    puts ""

    loop do
      ans = prompt_input("Chọn số [1-#{options_list.size}]", (default_idx + 1).to_s)
      idx = ans.to_i - 1
      if idx >= 0 && idx < options_list.size
        return options_list[idx][:value]
      end
      puts "#{RED}⚠️ Số bạn chọn không hợp lệ, vui lòng chọn lại!#{RESET}"
    end
  end

  def prompt_confirm(question, default_yes = true)
    hint = default_yes ? "[Y/n]" : "[y/N]"
    print "#{BOLD}#{question}#{RESET} #{DIM}#{hint}#{RESET}: "
    input = gets&.strip.to_s.downcase
    return default_yes if input.empty?
    input == "y" || input == "yes"
  end

  # Lọc danh sách app theo platform hỗ trợ
  def select_app(platform = nil, allow_all = false)
    filtered = @apps.select do |_, info|
      if platform.nil? || platform == "all"
        true
      else
        platforms = (info["platforms"] || []).map(&:downcase)
        platforms.empty? || platforms.include?(platform.to_s.downcase)
      end
    end

    if filtered.empty?
      puts "#{RED}⚠️ Không tìm thấy app nào hỗ trợ nền tảng '#{platform}' trong apps.json!#{RESET}"
      prompt_input("Nhấn Enter để quay lại...")
      return nil
    end

    options = []
    if allow_all && filtered.size > 1
      options << { label: "🌐 Tất cả các Apps (#{filtered.size} apps)", value: "all" }
    end

    filtered.each do |key, info|
      name = info["app_name"] || key
      platforms = (info["platforms"] || []).join(", ")
      id = info["bundle_id"] || info["package_name"] || ""
      label = "#{BOLD}#{name}#{RESET} #{DIM}(#{key})#{RESET} - #{id} #{CYAN}[#{platforms}]#{RESET}"
      options << { label: label, value: key }
    end

    prompt_choice("Chọn Ứng Dụng (App)", options)
  end

  # Xác nhận và chạy lệnh Terminal
  def execute_command(cmd)
    puts "\n#{BOLD}#{CYAN}--------------------------------------------------------------------#{RESET}"
    puts "#{BOLD}⚡ Lệnh sẽ thực thi:#{RESET}"
    puts "   #{BOLD}#{GREEN}#{cmd}#{RESET}"
    puts "#{BOLD}#{CYAN}--------------------------------------------------------------------#{RESET}\n"

    if prompt_confirm("Bạn có muốn thực thi lệnh trên ngay không?", true)
      puts "\n#{CYAN}🚀 Đang thực thi: #{cmd} ...#{RESET}\n"
      system(cmd)
      status = $?.exitstatus
      if status == 0
        puts "\n#{BOLD}#{GREEN}🎉 Hoàn tất thực thi thành công!#{RESET}\n"
      else
        puts "\n#{BOLD}#{RED}❌ Lệnh kết thúc với mã lỗi #{status}.#{RESET}\n"
      end
    else
      puts "\n#{YELLOW}Đã huỷ thực thi lệnh.#{RESET}\n"
    end

    prompt_input("Nhấn Enter để tiếp tục...")
  end

  # ============================================================================
  # 1. DEPLOY APP
  # ============================================================================

  def handle_deploy
    platform = prompt_choice("Chọn Nền Tảng Deploy", [
      { label: "🍎 iOS (TestFlight / Apple App Store)", value: "ios" },
      { label: "💻 macOS (TestFlight / Mac App Store)", value: "macos" },
      { label: "🤖 Android / AOS (Google Play Console)", value: "aos" }
    ])

    app_key = select_app(platform)
    return unless app_key

    case platform
    when "ios", "macos"
      target = prompt_choice("Chọn Mục Tiêu Phát Hành", [
        { label: "✈️ TestFlight (Beta Testing)", value: "testflight" },
        { label: "🏪 App Store (Production Release)", value: "appstore" }
      ])

      upload_meta = prompt_confirm("Có muốn tự động cập nhật Metadata kèm theo bản build không?", false)
      upload_shots = upload_meta ? prompt_confirm("Có muốn upload ảnh Screenshots kèm theo không?", false) : false
      obfuscate = prompt_confirm("Bật làm rối mã nguồn (--obfuscate)?", true)

      cmd = "make #{platform == 'ios' ? 'ios-deploy' : 'mac-deploy'} APP=#{app_key} TARGET=#{target}"
      cmd += " UPLOAD_METADATA=true" if upload_meta
      cmd += " SCREENSHOTS=true" if upload_shots
      cmd += " OBFUSCATE=#{obfuscate}"

    when "aos"
      track = prompt_choice("Chọn Track Google Play", [
        { label: "🧪 internal (Nội bộ)", value: "internal" },
        { label: "🔬 alpha (Alpha testing)", value: "alpha" },
        { label: "🔭 beta (Beta testing)", value: "beta" },
        { label: "🚀 production (Chính thức)", value: "production" }
      ])
      obfuscate = prompt_confirm("Bật làm rối mã nguồn (--obfuscate)?", true)
      cmd = "make aos-deploy APP=#{app_key} TRACK=#{track} OBFUSCATE=#{obfuscate}"
    end

    execute_command(cmd)
  end

  # ============================================================================
  # 2. BUILD APP
  # ============================================================================

  def handle_build
    platform = prompt_choice("Chọn Nền Tảng Build", [
      { label: "🍎 iOS (Build .ipa)", value: "ios" },
      { label: "💻 macOS (Build .pkg)", value: "macos" },
      { label: "🤖 Android / AOS (Build .aab / .apk)", value: "aos" }
    ])

    app_key = select_app(platform)
    return unless app_key

    obfuscate = prompt_confirm("Bật làm rối mã nguồn (--obfuscate)?", true)

    case platform
    when "ios"
      export_method = prompt_choice("Chọn Export Method", [
        { label: "App Store (Distribution)", value: "app-store" },
        { label: "Development (Internal / Debug)", value: "development" },
        { label: "Ad-hoc", value: "ad-hoc" },
        { label: "Enterprise", value: "enterprise" }
      ])
      cmd = "make ios-build APP=#{app_key} EXPORT_METHOD=#{export_method} OBFUSCATE=#{obfuscate}"
    when "macos"
      cmd = "make mac-build APP=#{app_key} OBFUSCATE=#{obfuscate}"
    when "aos"
      b_type = prompt_choice("Chọn Định Dạng Build", [
        { label: "App Bundle (.aab) - Chuẩn Google Play", value: "appbundle" },
        { label: "APK (.apk) - Cài trực tiếp trên thiết bị", value: "apk" }
      ])
      cmd = "make aos-build APP=#{app_key} TYPE=#{b_type} OBFUSCATE=#{obfuscate}"
    end

    execute_command(cmd)
  end

  # ============================================================================
  # 3. PULL METADATA
  # ============================================================================

  def handle_metadata_pull
    platform = prompt_choice("Chọn Nền Tảng Cần Pull Metadata", [
      { label: "🍎 iOS (Apple App Store)", value: "ios" },
      { label: "💻 macOS (Mac App Store)", value: "macos" },
      { label: "🤖 Android / AOS (Google Play Store)", value: "aos" }
    ])

    app_key = select_app(platform)
    return unless app_key

    pull_shots = prompt_confirm("Có muốn tải kèm cả ảnh Screenshots không?", true)
    skip_shots = pull_shots ? "false" : "true"

    cmd = case platform
          when "ios" then "make ios-metadata-pull APP=#{app_key} SKIP_SCREENSHOTS=#{skip_shots}"
          when "macos" then "make mac-metadata-pull APP=#{app_key} SKIP_SCREENSHOTS=#{skip_shots}"
          when "aos" then "make aos-metadata-pull APP=#{app_key}"
          end

    execute_command(cmd)
  end

  # ============================================================================
  # 4. PUSH METADATA
  # ============================================================================

  def handle_metadata_push
    platform = prompt_choice("Chọn Nền Tảng Cần Push Metadata", [
      { label: "🍎 iOS (Apple App Store)", value: "ios" },
      { label: "💻 macOS (Mac App Store)", value: "macos" },
      { label: "🤖 Android / AOS (Google Play Store)", value: "aos" }
    ])

    app_key = select_app(platform)
    return unless app_key

    app_info = @apps[app_key] || {}
    default_version = app_info["version"] || "1.0.0"

    version = prompt_input("Nhập App Version (để trống sẽ dùng mặc định)", default_version)
    upload_shots = prompt_confirm("Có muốn đẩy (upload) ảnh Screenshots lên Store không?", false)

    case platform
    when "ios"
      submit = prompt_confirm("Gửi lên kiểm duyệt (Submit for Review) luôn?", false)
      cmd = "make ios-metadata-push APP=#{app_key} VERSION=#{version} SCREENSHOTS=#{upload_shots} SUBMIT=#{submit}"
    when "macos"
      submit = prompt_confirm("Gửi lên kiểm duyệt (Submit for Review) luôn?", false)
      cmd = "make mac-metadata-push APP=#{app_key} VERSION=#{version} SCREENSHOTS=#{upload_shots} SUBMIT=#{submit}"
    when "aos"
      cmd = "make aos-metadata-push APP=#{app_key} SCREENSHOTS=#{upload_shots}"
    end

    execute_command(cmd)
  end

  # ============================================================================
  # 5. INIT METADATA
  # ============================================================================

  def handle_metadata_init
    app_key = select_app("all")
    return unless app_key

    platform = prompt_choice("Chọn Nền Tảng Khởi Tạo Template", [
      { label: "🌐 Tất cả các nền tảng (iOS, macOS, AOS, Windows, Linux)", value: "all" },
      { label: "🍎 iOS", value: "ios" },
      { label: "💻 macOS", value: "macos" },
      { label: "🤖 Android / AOS", value: "aos" },
      { label: "🪟 Windows", value: "windows" },
      { label: "🐧 Linux", value: "linux" }
    ])

    cmd = "make metadata-init APP=#{app_key} PLATFORM=#{platform}"
    execute_command(cmd)
  end

  # ============================================================================
  # 6. SYNC CERTS (MATCH)
  # ============================================================================

  def handle_sync_certs
    platform = prompt_choice("Chọn Nền Tảng Đồng Bộ Certs", [
      { label: "🍎 iOS", value: "ios" },
      { label: "💻 macOS", value: "mac" }
    ])

    app_key = select_app(platform == "mac" ? "macos" : "ios", true)
    return unless app_key

    cert_type = prompt_choice("Chọn Loại Certificate", [
      { label: "App Store (Distribution)", value: "appstore" },
      { label: "Development", value: "development" },
      { label: "Developer ID (macOS Direct Distribution)", value: "developer_id" }
    ])

    readonly = prompt_confirm("Chạy ở chế độ Readonly (Không tạo mới cert nếu thiếu)?", true)

    app_arg = (app_key == "all") ? "" : " APP=#{app_key}"
    cmd = "make sync-certs-#{platform}#{app_arg} TYPE=#{cert_type} READONLY=#{readonly}"
    execute_command(cmd)
  end

  # ============================================================================
  # 7. WORKSPACE MANAGEMENT
  # ============================================================================

  def handle_prepare_workspace
    app_key = select_app("all")
    return unless app_key

    app_info = @apps[app_key] || {}
    default_branch = app_info["branch"] || "main"

    ref = prompt_input("Nhập Branch/Tag/Commit ref cần checkout", default_branch)
    force = prompt_confirm("Buộc clone lại từ đầu (Force Re-clone)?", false)

    cmd = "make prepare-workspace APP=#{app_key} REF=#{ref} FORCE=#{force}"
    execute_command(cmd)
  end
end

InteractiveMenu.new.run if __FILE__ == $0
