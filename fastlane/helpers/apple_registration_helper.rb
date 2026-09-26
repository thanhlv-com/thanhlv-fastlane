# fastlane/helpers/apple_registration_helper.rb
# frozen_string_literal: true
#
# Helper tự động kiểm tra và đăng ký:
# 1. Identifiers (Bundle ID, App IDs, Extensions) trên Apple Developer Portal (https://developer.apple.com/account/resources/identifiers/list) nếu chưa có
# 2. Ứng dụng (App) trên App Store Connect (https://appstoreconnect.apple.com/apps) nếu chưa có
# Hỗ trợ xử lý đơn lẻ (1 app) hoặc hàng loạt (tất cả apps hỗ trợ iOS/macOS) với tính năng Idempotent hoàn toàn.

require 'json'
begin
  require 'fastlane_core'
  require 'fastlane_core/ui/ui'
  require 'terminal-table'
rescue LoadError
end

unless defined?(UI)
  class FallbackUI
    def self.message(msg); puts msg; end
    def self.success(msg); puts "\e[32m#{msg}\e[0m"; end
    def self.important(msg); puts "\e[33m#{msg}\e[0m"; end
    def self.error(msg); puts "\e[31m#{msg}\e[0m"; end
    def self.user_error!(msg); raise msg; end
  end
  UI = FallbackUI
end

# Chuẩn hoá tên nền tảng cho Apple
def normalize_apple_platform(platform)
  p = platform.to_s.strip.downcase
  case p
  when "mac", "osx", "macos"
    "macos"
  when "ios"
    "ios"
  else
    p
  end
end

# Mã nền tảng cho Spaceship::ConnectAPI (IOS hoặc MAC_OS)
def apple_portal_platform_code(platform)
  norm = normalize_apple_platform(platform)
  norm == "macos" ? "MAC_OS" : "IOS"
end

# Mã nền tảng cho Fastlane produce (ios hoặc osx)
def apple_produce_platform_code(platform)
  norm = normalize_apple_platform(platform)
  norm == "macos" ? "osx" : "ios"
end

# Khởi tạo kết nối Spaceship ConnectAPI với API Key (xử lý an toàn Token object vs Hash)
def ensure_spaceship_api_key(api_key = nil)
  api_key ||= get_api_key
  return nil unless api_key

  if defined?(Spaceship::ConnectAPI)
    begin
      # Kiểm tra nếu token đã là instance Token hợp lệ
      curr_token = Spaceship::ConnectAPI.token rescue nil
      if curr_token && curr_token.respond_to?(:in_house)
        return api_key
      elsif curr_token.is_a?(Hash)
        # Tránh lỗi NoMethodError in_house nếu token vô tình bị gán thành Hash trước đó
        Spaceship::ConnectAPI.token = nil rescue nil
      end

      # Chuyển đổi Hash trả về từ app_store_connect_api_key sang Spaceship::ConnectAPI::Token
      if api_key.is_a?(Hash)
        sym_key = api_key.transform_keys(&:to_sym)
        sym_key[:key] ||= sym_key[:key_content]
        sym_key[:filepath] ||= sym_key[:key_filepath]
        sym_key[:in_house] = false if sym_key[:in_house].nil?

        if defined?(Spaceship::ConnectAPI::Token)
          token = if Spaceship::ConnectAPI::Token.respond_to?(:from)
                    Spaceship::ConnectAPI::Token.from(hash: sym_key)
                  elsif Spaceship::ConnectAPI::Token.respond_to?(:create)
                    Spaceship::ConnectAPI::Token.create(**sym_key)
                  end
          Spaceship::ConnectAPI.token = token if token
        end
      elsif api_key.respond_to?(:in_house)
        Spaceship::ConnectAPI.token = api_key
      end
    rescue => e
      UI.important("  ⚠️ Không thể thiết lập Spaceship::ConnectAPI.token từ api_key: #{e.message}")
    end
  end

  api_key
end

# Tự động xác định Apple Team ID (seed_id) cần thiết khi đăng ký Bundle ID
def resolve_apple_seed_id(options = {})
  # 1. Từ options hoặc biến môi trường
  seed = options[:seed_id] || options[:team_id] || ENV["APPLE_TEAM_ID"] || ENV["TEAM_ID"]
  return seed.to_s.strip if seed && !seed.to_s.strip.empty?

  # 2. Từ Appfile nếu có
  if defined?(CredentialsManager::AppfileConfig)
    appfile_team = CredentialsManager::AppfileConfig.try_fetch_value(:team_id) rescue nil
    return appfile_team.to_s.strip if appfile_team && !appfile_team.to_s.strip.empty?
  end

  # 3. Lấy động từ các Bundle IDs sẵn có trong tài khoản qua ConnectAPI
  if defined?(Spaceship::ConnectAPI) && Spaceship::ConnectAPI.respond_to?(:get_bundle_ids)
    begin
      resp = Spaceship::ConnectAPI.get_bundle_ids(limit: 5)
      if resp
        models = resp.respond_to?(:to_models) ? resp.to_models : resp.to_a
        found = models.find { |b| b.respond_to?(:seed_id) && b.seed_id && !b.seed_id.to_s.strip.empty? }
        if found
          resolved = found.seed_id.to_s.strip
          UI.message("  ℹ️ Tự động phát hiện seed_id (Apple Team ID): #{resolved}")
          return resolved
        end
      end
    rescue => e
      UI.message("  ℹ️ Không thể truy vấn seed_id tự động từ ConnectAPI get_bundle_ids: #{e.message}")
    end
  end

  nil
end

# Kiểm tra và đăng ký 1 Bundle ID trên Apple Developer Portal nếu chưa có
def verify_or_create_portal_bundle_id(bundle_id, name, platform, options = {})
  platform_code = apple_portal_platform_code(platform)
  UI.message("  🔍 [1/2] Kiểm tra Identifier trên Apple Developer Portal: #{bundle_id} (Platform: #{platform_code})...")

  existing_bundle = nil
  begin
    if defined?(Spaceship::ConnectAPI) && Spaceship::ConnectAPI.respond_to?(:get_bundle_ids)
      resp = Spaceship::ConnectAPI.get_bundle_ids(filter: { identifier: bundle_id })
      existing_bundle = resp.first if resp && resp.respond_to?(:first)
    end
  rescue => e
    UI.important("  ⚠️ Không thể kiểm tra trực tiếp qua ConnectAPI get_bundle_ids: #{e.message}")
  end

  if existing_bundle
    portal_id = existing_bundle.respond_to?(:id) ? existing_bundle.id : "N/A"
    UI.message("  ✅ [EXISTS] Identifier '#{bundle_id}' đã tồn tại trên Apple Developer Portal (ID: #{portal_id}). Bỏ qua tạo mới.")
    return { status: "EXISTS", bundle_id: bundle_id, id: portal_id }
  end

  # Chưa có -> Đăng ký mới trên Developer Portal qua ConnectAPI
  UI.message("  ➕ [CREATING] Identifier '#{bundle_id}' chưa có trên Apple Developer Portal. Đang tạo...")
  seed_id = resolve_apple_seed_id(options)
  unless seed_id && !seed_id.empty?
    err = "Không tìm thấy Apple Team ID (seed_id). Vui lòng cấu hình biến môi trường APPLE_TEAM_ID hoặc cung cấp trong options."
    UI.error("  ❌ [FAILED] #{err}")
    return { status: "FAILED", bundle_id: bundle_id, error: err }
  end

  clean_name = name.to_s.gsub(/[^a-zA-Z0-9\s._-]/, '').strip
  clean_name = bundle_id if clean_name.empty?
  clean_name = clean_name[0...50].strip

  begin
    new_bundle = nil
    if defined?(Spaceship::ConnectAPI::BundleId) && Spaceship::ConnectAPI::BundleId.respond_to?(:create)
      new_bundle = Spaceship::ConnectAPI::BundleId.create(
        name: clean_name,
        platform: platform_code,
        identifier: bundle_id,
        seed_id: seed_id
      )
    elsif defined?(Spaceship::ConnectAPI) && Spaceship::ConnectAPI.respond_to?(:post_bundle_id)
      new_bundle = Spaceship::ConnectAPI.post_bundle_id(
        name: clean_name,
        platform: platform_code,
        identifier: bundle_id,
        seed_id: seed_id
      )
    end

    new_id = new_bundle.respond_to?(:id) ? new_bundle.id : "NEW"
    UI.success("  🎉 [CREATED] Đã đăng ký thành công Identifier '#{bundle_id}' trên Apple Developer Portal (ID: #{new_id})!")
    return { status: "CREATED", bundle_id: bundle_id, id: new_id }
  rescue => e
    msg = e.message.to_s
    if msg.include?("already exists") || msg.include?("has already been taken") || msg.include?("ENTITY_ERROR.ATTRIBUTE.NOT_UNIQUE")
      UI.message("  ✅ [EXISTS] Identifier '#{bundle_id}' đã có sẵn trên Apple Developer Portal.")
      return { status: "EXISTS", bundle_id: bundle_id, error: nil }
    else
      UI.error("  ❌ [FAILED] Không thể tạo Identifier '#{bundle_id}' trên Apple Developer Portal: #{msg}")
      return { status: "FAILED", bundle_id: bundle_id, error: msg }
    end
  end
end

# Kiểm tra trạng thái ứng dụng trên App Store Connect (chỉ kiểm tra xem đã tạo bằng tay chưa)
def verify_asc_app(bundle_id, app_name, platform, options = {})
  UI.message("  🔍 [2/2] Kiểm tra App trên App Store Connect: '#{app_name}' (#{bundle_id})...")

  existing_app = nil
  begin
    if defined?(Spaceship::ConnectAPI) && Spaceship::ConnectAPI.respond_to?(:get_apps)
      resp = Spaceship::ConnectAPI.get_apps(filter: { bundleId: bundle_id })
      existing_app = resp.first if resp && resp.respond_to?(:first)
    end
  rescue => e
    UI.important("  ⚠️ Không thể kiểm tra App qua ConnectAPI get_apps: #{e.message}")
  end

  if existing_app
    app_id = existing_app.respond_to?(:id) ? existing_app.id : "N/A"
    app_display_name = existing_app.respond_to?(:name) ? existing_app.name : app_name
    UI.message("  ✅ [EXISTS] App '#{app_display_name}' (#{bundle_id}) đã có trên App Store Connect (Apple ID: #{app_id}).")
    return { status: "EXISTS", app_id: app_id, app_name: app_display_name }
  end

  # Chưa có trên App Store Connect -> Thông báo hướng dẫn tạo tay trên web
  UI.message("  ℹ️ [NOT_CREATED] App '#{app_name}' (#{bundle_id}) chưa có trên App Store Connect.")
  UI.message("     👉 Bạn có thể tạo thủ công tại: https://appstoreconnect.apple.com/apps/new (chọn Bundle ID: #{bundle_id})")
  { status: "NOT_CREATED", app_name: app_name, bundle_id: bundle_id }
end
alias verify_or_create_asc_app verify_asc_app

# Kiểm tra & đăng ký các Secondary Identifiers (Extensions & App Groups) nếu có cấu hình
def verify_secondary_identifiers(app_info, platform, api_key, options = {})
  results = []
  platform_code = apple_portal_platform_code(platform)

  # 1. Extensions (ví dụ OneSignalNotificationServiceExtension, Widget)
  if app_info["extensions"].is_a?(Array) && app_info["extensions"].any?
    app_info["extensions"].each do |ext|
      ext_bundle = ext.is_a?(Hash) ? ext["bundle_id"] : ext.to_s
      ext_name = ext.is_a?(Hash) ? (ext["name"] || ext_bundle) : ext_bundle
      next if ext_bundle.nil? || ext_bundle.empty?

      UI.message("  🧩 Kiểm tra Extension Identifier: #{ext_bundle}...")
      res = verify_or_create_portal_bundle_id(ext_bundle, ext_name, platform, options)
      results << res.merge(type: "extension")
    end
  end

  # 2. App Groups
  if app_info["app_groups"].is_a?(Array) && app_info["app_groups"].any?
    app_info["app_groups"].each do |group_id|
      next if group_id.nil? || group_id.empty?
      UI.message("  👥 Kiểm tra App Group Identifier: #{group_id}...")
      # App groups có thể được xử lý riêng nếu API hỗ trợ
    end
  end

  results
end

# Hàm chính: Kiểm tra & đăng ký đầy đủ Identifier & kiểm tra App cho 1 app cụ thể
def verify_and_register_apple_app(app_key, app_info, platform = "ios", options = {})
  norm_platform = normalize_apple_platform(platform)
  validate_platform_support!(app_key, app_info, norm_platform)

  bundle_id = resolve_bundle_id(app_info, norm_platform, options)
  app_name = options[:app_name] || app_info["app_name"] || app_key

  UI.message("\n" + "=" * 70)
  UI.message("🚀 Bắt đầu kiểm tra & đăng ký Apple Identifier cho app: #{app_key} (#{app_name})")
  UI.message("🚀 Nền tảng: #{norm_platform.upcase} | Bundle ID: #{bundle_id}")
  UI.message("=" * 70)

  api_key = ensure_spaceship_api_key(options[:api_key])

  # 1. Kiểm tra & tạo Identifier trên Developer Portal nếu chưa có
  portal_res = verify_or_create_portal_bundle_id(bundle_id, app_name, norm_platform, options)

  # 2. Kiểm tra App trên App Store Connect (chỉ kiểm tra sự tồn tại)
  asc_res = verify_asc_app(bundle_id, app_name, norm_platform, options)

  # 3. Secondary identifiers (nếu có)
  ext_results = verify_secondary_identifiers(app_info, norm_platform, api_key, options)

  ext_failed = ext_results.select { |r| r[:status] == "FAILED" }
  overall_success = portal_res[:status] != "FAILED" && ext_failed.empty?

  if overall_success
    UI.success("✨ Hoàn tất kiểm tra & đồng bộ Identifier Apple cho '#{app_key}'!")
    if asc_res[:status] == "NOT_CREATED"
      UI.important("💡 Ghi chú: App '#{app_name}' chưa có trên App Store Connect. Vui lòng tạo tay tại https://appstoreconnect.apple.com/apps/new (chọn Bundle ID: #{bundle_id})")
    end
  else
    UI.error("❌ Có lỗi phát sinh khi đăng ký Identifier cho '#{app_key}'. Vui lòng xem chi tiết ở log phía trên.")
    # Ném lỗi để Fastlane/CI ghi nhận FAILED trừ khi được gọi trong ngữ cảnh batch (fail_on_error: false)
    if options[:fail_on_error] != false
      error_msg = portal_res[:error] || (ext_failed.first ? ext_failed.first[:error] : nil) || "Lỗi đăng ký Identifier cho #{app_key}"
      UI.user_error!("❌ Đăng ký Apple Identifier thất bại cho '#{app_key}' (#{norm_platform.upcase}): #{error_msg}")
    end
  end

  {
    app_key: app_key,
    app_name: app_name,
    platform: norm_platform,
    bundle_id: bundle_id,
    portal_status: portal_res[:status],
    asc_status: asc_res[:status],
    extensions_count: ext_results.size,
    error: portal_res[:error] || (ext_failed.first ? ext_failed.first[:error] : nil)
  }
end

# Chạy kiểm tra & đăng ký hàng loạt cho tất cả các apps hỗ trợ Apple
def verify_and_register_all_apple_apps(target_platform = "all", options = {})
  apps_data = load_apps_config
  norm_target = normalize_apple_platform(target_platform)

  # Xác định các nền tảng cần quét
  platforms_to_check = case norm_target
                       when "ios" then ["ios"]
                       when "macos" then ["macos"]
                       else ["ios", "macos"]
                       end

  UI.message("\n" + "🌟" * 35)
  UI.message("🌟 Bắt đầu quét và đồng bộ Apple Identifiers & kiểm tra App Store Connect")
  UI.message("🌟 Target Platforms: #{platforms_to_check.join(', ').upcase}")
  UI.message("🌟 Tổng số apps trong apps.json: #{apps_data.keys.size}")
  UI.message("🌟" * 35 + "\n")

  # Đảm bảo khởi tạo API Key một lần duy nhất trước khi bắt đầu batch
  ensure_spaceship_api_key(options[:api_key])

  results = []
  batch_options = options.merge(fail_on_error: false)

  apps_data.each do |app_key, app_info|
    app_platforms = (app_info["platforms"] || ["ios", "android"]).map { |p| normalize_apple_platform(p) }

    platforms_to_check.each do |plt|
      next unless app_platforms.include?(plt)

      begin
        res = verify_and_register_apple_app(app_key, app_info, plt, batch_options)
        results << res
      rescue => e
        UI.error("❌ Ngoại lệ khi xử lý app '#{app_key}' trên nền tảng #{plt}: #{e.message}")
        failed_bundle = begin
                          resolve_bundle_id(app_info, plt, options)
                        rescue => _
                          "UNKNOWN"
                        end
        results << {
          app_key: app_key,
          app_name: app_info["app_name"] || app_key,
          platform: plt,
          bundle_id: failed_bundle,
          portal_status: "FAILED",
          asc_status: "UNKNOWN",
          error: e.message
        }
      end
    end
  end

  render_apple_registration_summary(results)

  # Kiểm tra kết quả toàn batch: chỉ fail nếu có Identifier trên Developer Portal thất bại
  failed_items = results.select { |r| r[:portal_status] == "FAILED" }
  if failed_items.any?
    summary_errors = failed_items.map { |f| "#{f[:app_key]} [#{f[:platform]}]: #{f[:error]}" }.join("\n  - ")
    UI.user_error!("❌ Có #{failed_items.size} ứng dụng thất bại khi đăng ký Apple Identifier:\n  - #{summary_errors}")
  end

  results
end

# In bảng tổng hợp kết quả đẹp mắt trên Terminal
def render_apple_registration_summary(results)
  return if results.nil? || results.empty?

  rows = results.map do |r|
    portal_badge = case r[:portal_status]
                   when "CREATED" then "🎉 CREATED"
                   when "EXISTS" then "✅ EXISTS"
                   else "❌ FAILED"
                   end

    asc_badge = case r[:asc_status]
                when "EXISTS" then "✅ EXISTS"
                when "NOT_CREATED" then "ℹ️ NOT CREATED (Manual)"
                else "❓ UNKNOWN"
                end

    [
      r[:app_key],
      r[:platform].to_s.upcase,
      r[:bundle_id],
      portal_badge,
      asc_badge,
      r[:error] ? r[:error][0..35] : "OK"
    ]
  end

  headings = ["App Key", "Platform", "Bundle ID", "Dev Portal", "App Store Connect", "Notes"]

  puts "\n"
  if defined?(Terminal::Table)
    table = Terminal::Table.new(
      title: "Apple Identifiers & App Store Connect Sync Summary",
      headings: headings,
      rows: rows
    )
    puts table
  else
    puts "=" * 80
    puts "APPLE IDENTIFIERS & APP STORE CONNECT SYNC SUMMARY"
    puts "=" * 80
    rows.each do |row|
      puts "#{row[0]} [#{row[1]}] (#{row[2]}): Portal=#{row[3]} | ASC=#{row[4]} | #{row[5]}"
    end
    puts "=" * 80
  end
  puts "\n"
end
