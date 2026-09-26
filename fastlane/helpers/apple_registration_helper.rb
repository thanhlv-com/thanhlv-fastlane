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

# Kiểm tra và đăng ký Ứng dụng trên App Store Connect nếu chưa có
def verify_or_create_asc_app(bundle_id, app_name, platform, api_key, portal_status = "UNKNOWN", options = {})
  if portal_status.is_a?(Hash) && options.empty?
    options = portal_status
    portal_status = "UNKNOWN"
  end
  produce_platform = apple_produce_platform_code(platform)
  connect_platform = apple_portal_platform_code(platform)
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
    UI.message("  ✅ [EXISTS] App '#{app_display_name}' (#{bundle_id}) đã tồn tại trên App Store Connect (Apple ID: #{app_id}). Bỏ qua tạo mới.")
    return { status: "EXISTS", app_id: app_id, app_name: app_display_name }
  end

  # Chưa có -> Tạo mới App trên App Store Connect
  UI.message("  ➕ [CREATING] App '#{app_name}' (#{bundle_id}) chưa có trên App Store Connect. Đang tạo...")
  sku = options[:sku] || "#{bundle_id.gsub(/[^0-9A-Za-z]/, '_').upcase}_#{Time.now.to_i}"
  version = options[:app_version] || "1.0"
  primary_locale = options[:language] || "en-US"

  # 1. Ưu tiên: Tạo trực tiếp qua Spaceship::ConnectAPI REST API (sử dụng Token, không đòi hỏi Apple ID password hay interactive login)
  begin
    created_app = nil
    if defined?(Spaceship::ConnectAPI::App) && Spaceship::ConnectAPI::App.respond_to?(:create)
      created_app = Spaceship::ConnectAPI::App.create(
        name: app_name,
        version_string: version,
        sku: sku,
        primary_locale: primary_locale,
        bundle_id: bundle_id,
        platforms: [connect_platform]
      )
    elsif defined?(Spaceship::ConnectAPI) && Spaceship::ConnectAPI.respond_to?(:post_app)
      created_app = Spaceship::ConnectAPI.post_app(
        name: app_name,
        version_string: version,
        sku: sku,
        primary_locale: primary_locale,
        bundle_id: bundle_id,
        platforms: [connect_platform]
      )
    end

    if created_app
      new_app_id = created_app.respond_to?(:id) ? created_app.id : "NEW"
      UI.success("  🎉 [CREATED] Đã tạo thành công App '#{app_name}' trên App Store Connect (Apple ID: #{new_app_id})!")
      return { status: "CREATED", app_name: app_name, app_id: new_app_id }
    end
  rescue => e
    msg = e.message.to_s
    if msg.include?("already exists") || msg.include?("already been taken") || msg.include?("already in use")
      UI.message("  ✅ [EXISTS] App '#{app_name}' đã tồn tại trên App Store Connect.")
      return { status: "EXISTS", app_name: app_name }
    elsif msg.include?("already being used") || msg.include?("The App Name you entered is already being used")
      err = "Tên app '#{app_name}' đã bị trùng lặp toàn cầu trên App Store Connect! Vui lòng đổi app_name trong fastlane/apps.json."
      UI.error("  ❌ [FAILED] #{err}")
      return { status: "FAILED", app_name: app_name, error: err }
    else
      UI.important("  ⚠️ ConnectAPI tạo App gặp phản hồi từ Apple: #{msg}")
    end
  end

  # 2. Fallback: Fastlane produce (yêu cầu credentials web session của Apple ID: FASTLANE_USER & FASTLANE_PASSWORD / FASTLANE_SESSION)
  fastlane_user = ENV["FASTLANE_USER"] || options[:username]
  fastlane_password = ENV["FASTLANE_PASSWORD"] || options[:password]
  has_web_auth = fastlane_user && !fastlane_user.strip.empty? && (fastlane_password || ENV["FASTLANE_SESSION"] || ENV["FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD"])

  if has_web_auth
    UI.message("  🌐 Đang thử tạo App Store Connect qua produce bằng session Apple ID (#{fastlane_user})...")
    begin
      produce_params = {
        username: fastlane_user,
        app_identifier: bundle_id,
        app_name: app_name,
        language: "English",
        platform: produce_platform,
        skip_devcenter: true, # BẮT BUỘC: luôn luôn true vì Identifier đã được tạo ở Dev Portal
        skip_itc: false,
        sku: sku
      }
      produce_params[:api_key] = api_key if api_key

      if respond_to?(:produce)
        produce(produce_params)
      elsif defined?(Fastlane::Actions::ProduceAction)
        Fastlane::Actions::ProduceAction.run(produce_params)
      else
        raise "Không thể gọi action produce ngoài ngữ cảnh Fastlane lane"
      end

      UI.success("  🎉 [CREATED] Đã tạo thành công App '#{app_name}' trên App Store Connect qua produce!")
      return { status: "CREATED", app_name: app_name }
    rescue => e
      msg = e.message.to_s
      if msg.include?("already exists") || msg.include?("nothing to do on App Store Connect")
        UI.message("  ✅ [EXISTS] App '#{app_name}' đã tồn tại trên App Store Connect.")
        return { status: "EXISTS", app_name: app_name }
      elsif msg.include?("already being used") || msg.include?("The App Name you entered is already being used")
        err = "Tên app '#{app_name}' đã bị trùng lặp toàn cầu trên App Store Connect! Vui lòng đổi app_name trong fastlane/apps.json."
        UI.error("  ❌ [FAILED] #{err}")
        return { status: "FAILED", app_name: app_name, error: err }
      else
        UI.error("  ❌ [FAILED] Lỗi tạo App '#{app_name}' trên App Store Connect qua produce: #{msg}")
        return { status: "FAILED", app_name: app_name, error: msg }
      end
    end
  else
    # Môi trường CI sử dụng App Store Connect API Key thuần túy
    err_guide = "Apple không cho phép tạo mới App Record bằng App Store Connect API Key (chính sách bảo mật của Apple: The resource 'apps' does not allow 'CREATE').\n" \
                "  👉 Hướng dẫn xử lý:\n" \
                "     1. Tạo ứng dụng thủ công trên web App Store Connect: https://appstoreconnect.apple.com/apps/new\n" \
                "        - Platform: #{produce_platform.upcase}\n" \
                "        - App Name: #{app_name}\n" \
                "        - Primary Language: English (hoặc Vietnamese)\n" \
                "        - Bundle ID: Chọn '#{bundle_id}' (đã được tạo thành công trên Dev Portal)\n" \
                "        - SKU: #{sku}\n" \
                "     2. Hoặc cung cấp secret FASTLANE_USER & FASTLANE_PASSWORD (kèm FASTLANE_SESSION nếu có 2FA) để tự động tạo qua web session."
    UI.error("  ❌ [FAILED] #{err_guide}")
    return {
      status: "FAILED",
      app_name: app_name,
      error: "Apple hạn chế API Key tạo App mới. Vui lòng tạo trên web: https://appstoreconnect.apple.com/apps/new (Bundle ID: #{bundle_id})"
    }
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
  asc_res = verify_or_create_asc_app(bundle_id, app_name, norm_platform, api_key, portal_res[:status], options)

  # 3. Secondary identifiers (nếu có)
  ext_results = verify_secondary_identifiers(app_info, norm_platform, api_key, options)

  ext_failed = ext_results.select { |r| r[:status] == "FAILED" }
  overall_success = portal_res[:status] != "FAILED" && asc_res[:status] != "FAILED" && ext_failed.empty?

  if overall_success
    UI.success("✨ Hoàn tất kiểm tra & đồng bộ Apple Identifier và App cho '#{app_key}'!")
  else
    UI.error("❌ Có lỗi phát sinh khi đồng bộ '#{app_key}'. Vui lòng xem chi tiết ở log phía trên.")
    # Ném lỗi để Fastlane/CI ghi nhận FAILED trừ khi được gọi trong ngữ cảnh batch (fail_on_error: false)
    if options[:fail_on_error] != false
      error_msg = portal_res[:error] || asc_res[:error] || (ext_failed.first ? ext_failed.first[:error] : nil) || "Lỗi kiểm tra/đăng ký Apple cho #{app_key}"
      UI.user_error!("❌ Đăng ký Apple thất bại cho '#{app_key}' (#{norm_platform.upcase}): #{error_msg}")
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
    error: portal_res[:error] || asc_res[:error] || (ext_failed.first ? ext_failed.first[:error] : nil)
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
          asc_status: "FAILED",
          error: e.message
        }
      end
    end
  end

  render_apple_registration_summary(results)

  # Kiểm tra kết quả toàn batch: nếu có bất kỳ app nào FAILED thì ném UI.user_error! để báo thất bại
  failed_items = results.select { |r| r[:portal_status] == "FAILED" || r[:asc_status] == "FAILED" }
  if failed_items.any?
    summary_errors = failed_items.map { |f| "#{f[:app_key]} [#{f[:platform]}]: #{f[:error]}" }.join("\n  - ")
    UI.user_error!("❌ Có #{failed_items.size} ứng dụng thất bại khi đăng ký Apple:\n  - #{summary_errors}")
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
