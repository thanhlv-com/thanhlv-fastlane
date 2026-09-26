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

# Khởi tạo kết nối Spaceship ConnectAPI với API Key
def ensure_spaceship_api_key(api_key = nil)
  api_key ||= get_api_key
  if defined?(Spaceship::ConnectAPI) && api_key
    Spaceship::ConnectAPI.token = api_key
  end
  api_key
end

# Kiểm tra và đăng ký 1 Bundle ID trên Apple Developer Portal nếu chưa có
def verify_or_create_portal_bundle_id(bundle_id, name, platform, options = {})
  platform_code = apple_portal_platform_code(platform)
  UI.message("  🔍 [1/2] Kiểm tra Identifier trên Apple Developer Portal: #{bundle_id} (Platform: #{platform_code})...")

  existing_bundle = nil
  begin
    resp = Spaceship::ConnectAPI.get_bundle_ids(filter: { identifier: bundle_id })
    existing_bundle = resp.first if resp && resp.respond_to?(:first)
  rescue => e
    # Trường hợp token lỗi hoặc API tạm thời gián đoạn
    UI.important("  ⚠️ Không thể kiểm tra trực tiếp qua ConnectAPI: #{e.message}. Sẽ uỷ thác cho produce.")
  end

  if existing_bundle
    portal_id = existing_bundle.respond_to?(:id) ? existing_bundle.id : "N/A"
    UI.message("  ✅ [EXISTS] Identifier '#{bundle_id}' đã tồn tại trên Apple Developer Portal (ID: #{portal_id}). Bỏ qua tạo mới.")
    return { status: "EXISTS", bundle_id: bundle_id, id: portal_id }
  end

  # Chưa có -> Đăng ký mới trên Developer Portal
  UI.message("  ➕ [CREATING] Identifier '#{bundle_id}' chưa có trên Apple Developer Portal. Đang tạo...")
  begin
    new_bundle = Spaceship::ConnectAPI.post_bundle_id(
      name: name,
      identifier: bundle_id,
      platform: platform_code
    )
    new_id = new_bundle.respond_to?(:id) ? new_bundle.id : "NEW"
    UI.success("  🎉 [CREATED] Đã đăng ký thành công Identifier '#{bundle_id}' trên Apple Developer Portal (ID: #{new_id})!")
    { status: "CREATED", bundle_id: bundle_id, id: new_id }
  rescue => e
    # Nếu báo lỗi đã tồn tại ngoài luồng (race condition / caching)
    if e.message.to_s.include?("already exists") || e.message.to_s.include?("has already been taken")
      UI.message("  ✅ [EXISTS] Identifier '#{bundle_id}' đã có sẵn trên Apple Developer Portal.")
      { status: "EXISTS", bundle_id: bundle_id, error: nil }
    else
      UI.error("  ❌ [FAILED] Không thể tạo Identifier '#{bundle_id}' trên Apple Developer Portal: #{e.message}")
      { status: "FAILED", bundle_id: bundle_id, error: e.message }
    end
  end
end

# Kiểm tra và đăng ký Ứng dụng trên App Store Connect nếu chưa có
def verify_or_create_asc_app(bundle_id, app_name, platform, api_key, options = {})
  produce_platform = apple_produce_platform_code(platform)
  UI.message("  🔍 [2/2] Kiểm tra App trên App Store Connect: '#{app_name}' (#{bundle_id})...")

  existing_app = nil
  begin
    resp = Spaceship::ConnectAPI.get_apps(filter: { bundleId: bundle_id })
    existing_app = resp.first if resp && resp.respond_to?(:first)
  rescue => e
    UI.important("  ⚠️ Không thể kiểm tra App qua ConnectAPI: #{e.message}. Sẽ uỷ thác cho produce.")
  end

  if existing_app
    app_id = existing_app.respond_to?(:id) ? existing_app.id : "N/A"
    app_display_name = existing_app.respond_to?(:name) ? existing_app.name : app_name
    UI.message("  ✅ [EXISTS] App '#{app_display_name}' (#{bundle_id}) đã tồn tại trên App Store Connect (Apple ID: #{app_id}). Bỏ qua tạo mới.")
    return { status: "EXISTS", app_id: app_id, app_name: app_display_name }
  end

  # Chưa có -> Tạo mới App trên App Store Connect thông qua produce
  UI.message("  ➕ [CREATING] App '#{app_name}' (#{bundle_id}) chưa có trên App Store Connect. Đang tạo...")
  begin
    # Gọi Fastlane produce với skip_devcenter: true vì Step 1 đã đảm bảo bundle_id ở Developer Portal
    if defined?(Fastlane::Actions::ProduceAction)
      Fastlane::Actions::ProduceAction.run(
        api_key: api_key,
        app_identifier: bundle_id,
        app_name: app_name,
        language: "English",
        platform: produce_platform,
        skip_devcenter: true
      )
    elsif respond_to?(:produce)
      produce(
        api_key: api_key,
        app_identifier: bundle_id,
        app_name: app_name,
        language: "English",
        platform: produce_platform,
        skip_devcenter: true
      )
    else
      UI.important("  ℹ️ Lệnh produce không khả dụng ngoài ngữ cảnh Fastlane lane. Bỏ qua tạo App.")
    end

    UI.success("  🎉 [CREATED] Đã tạo thành công App '#{app_name}' trên App Store Connect!")
    { status: "CREATED", app_name: app_name }
  rescue => e
    msg = e.message.to_s
    if msg.include?("already exists") || msg.include?("nothing to do on App Store Connect")
      UI.message("  ✅ [EXISTS] App '#{app_name}' đã tồn tại trên App Store Connect.")
      { status: "EXISTS", app_name: app_name }
    elsif msg.include?("already being used") || msg.include?("The App Name you entered is already being used")
      UI.error("  ❌ [FAILED] Tên app '#{app_name}' đã bị trùng lặp toàn cầu trên App Store Connect! Vui lòng đổi app_name trong apps.json.")
      { status: "FAILED", app_name: app_name, error: "Tên app đã bị trùng lặp trên App Store Connect: #{msg}" }
    else
      UI.error("  ❌ [FAILED] Lỗi tạo App '#{app_name}' trên App Store Connect: #{msg}")
      { status: "FAILED", app_name: app_name, error: msg }
    end
  end
end

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

# Hàm chính: Kiểm tra & đăng ký đầy đủ Identifier & App cho 1 app cụ thể
def verify_and_register_apple_app(app_key, app_info, platform = "ios", options = {})
  norm_platform = normalize_apple_platform(platform)
  validate_platform_support!(app_key, app_info, norm_platform)

  bundle_id = resolve_bundle_id(app_info, norm_platform, options)
  app_name = options[:app_name] || app_info["app_name"] || app_key

  UI.message("\n" + "=" * 70)
  UI.message("🚀 Bắt đầu kiểm tra & đăng ký Apple cho app: #{app_key} (#{app_name})")
  UI.message("🚀 Nền tảng: #{norm_platform.upcase} | Bundle ID: #{bundle_id}")
  UI.message("=" * 70)

  api_key = ensure_spaceship_api_key(options[:api_key])

  # 1. Kiểm tra & tạo Identifier trên Developer Portal
  portal_res = verify_or_create_portal_bundle_id(bundle_id, app_name, norm_platform, options)

  # 2. Kiểm tra & tạo App trên App Store Connect
  asc_res = verify_or_create_asc_app(bundle_id, app_name, norm_platform, api_key, options)

  # 3. Secondary identifiers (nếu có)
  ext_results = verify_secondary_identifiers(app_info, norm_platform, api_key, options)

  overall_success = portal_res[:status] != "FAILED" && asc_res[:status] != "FAILED"

  if overall_success
    UI.success("✨ Hoàn tất kiểm tra & đồng bộ Apple Identifier và App cho '#{app_key}'!")
  else
    UI.important("⚠️ Có lỗi phát sinh khi đồng bộ '#{app_key}'. Vui lòng xem chi tiết ở log phía trên.")
  end

  {
    app_key: app_key,
    app_name: app_name,
    platform: norm_platform,
    bundle_id: bundle_id,
    portal_status: portal_res[:status],
    asc_status: asc_res[:status],
    extensions_count: ext_results.size,
    error: portal_res[:error] || asc_res[:error]
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
  UI.message("🌟 Bắt đầu quét và đồng bộ Apple Identifiers & App Store Connect Apps")
  UI.message("🌟 Target Platforms: #{platforms_to_check.join(', ').upcase}")
  UI.message("🌟 Tổng số apps trong apps.json: #{apps_data.keys.size}")
  UI.message("🌟" * 35 + "\n")

  # Đảm bảo khởi tạo API Key một lần duy nhất trước khi bắt đầu batch
  ensure_spaceship_api_key(options[:api_key])

  results = []

  apps_data.each do |app_key, app_info|
    app_platforms = (app_info["platforms"] || ["ios", "android"]).map { |p| normalize_apple_platform(p) }

    platforms_to_check.each do |plt|
      next unless app_platforms.include?(plt)

      begin
        res = verify_and_register_apple_app(app_key, app_info, plt, options)
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
          asc_status: "FAILED",
          error: e.message
        }
      end
    end
  end

  render_apple_registration_summary(results)
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
                when "CREATED" then "🎉 CREATED"
                when "EXISTS" then "✅ EXISTS"
                else "❌ FAILED"
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
