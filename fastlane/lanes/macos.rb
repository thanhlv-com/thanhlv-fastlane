# fastlane/lanes/macos.rb
# Quản lý signing, build & deploy cho nền tảng macOS

platform :mac do
  before_all do
    setup_ci if is_ci
  end

  desc "Đăng ký macOS App Identifier & tạo App mới trên App Store Connect"
  lane :register_app do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane mac register_app app:OpsFlow_Hub")
    app_info = get_app_config(app_key)
    validate_platform_support!(app_key, app_info, "macos")

    bundle_id = resolve_bundle_id(app_info, "macos", options)
    api_key = get_api_key

    produce(
      api_key: api_key,
      app_identifier: bundle_id,
      app_name: app_info["app_name"],
      language: "Vietnamese",
      platform: "osx",
      skip_itc: false
    )

    UI.success("🎉 Đã đăng ký thành công macOS Bundle ID & App trên App Store Connect: #{bundle_id}")
  end

  desc "Dọn dẹp Certificate & Provisioning Profile cũ/hết hạn trên máy local"
  lane :clean_certs do |options|
    clean_old_local_certs(options)
  end

  desc "Đồng bộ Certificate & Provisioning Profile (Match) cho macOS (1 app hoặc tất cả apps)"
  lane :sync_certs do |options|
    app_key = options[:app]
    cert_type = options[:type] || "appstore"
    is_readonly = options[:readonly] == "true" || options[:readonly] == true
    is_force = options[:force] == "true" || options[:force] == true
    clean_old = options[:clean_old_certs] == "true" || options[:clean_old_certs] == true

    if clean_old
      clean_old_local_certs(options)
    end

    apps_data = load_apps_config

    if app_key
      app_info = get_app_config(app_key)
      validate_platform_support!(app_key, app_info, "macos")
      bundle_ids = [resolve_bundle_id(app_info, "macos", options)]
      UI.message("🔄 Đồng bộ certs macOS cho app: #{app_key} (#{bundle_ids.first})")
    else
      # Lọc các app hỗ trợ nền tảng macOS
      target_apps = apps_data.select do |k, v|
        v["platforms"].nil? || v["platforms"].map { |p| normalize_platform_name(p) }.include?("macos")
      end
      bundle_ids = target_apps.values.map { |a| resolve_bundle_id(a, "macos") }.compact.uniq
      UI.message("🔄 Đồng bộ certs macOS cho #{bundle_ids.length} apps hỗ trợ macOS...")
    end

    api_key = get_api_key

    # 1. Đồng bộ macOS App Distribution Certificate & Profiles
    UI.message("🔑 [1/2] Đồng bộ macOS App Distribution Certificate & Profiles...")
    match(
      type: cert_type,
      platform: "macos",
      generate_apple_certs: true,
      app_identifier: bundle_ids,
      api_key: api_key,
      readonly: is_readonly,
      force: is_force
    )

    # 2. Đồng bộ Mac Installer Distribution Certificate (bắt buộc để ký .pkg)
    if cert_type == "appstore"
      UI.message("🔑 [2/2] Đồng bộ Mac Installer Distribution Certificate...")
      match(
        type: "mac_installer_distribution",
        platform: "macos",
        app_identifier: bundle_ids,
        skip_provisioning_profiles: true,
        api_key: api_key,
        readonly: is_readonly,
        force: is_force
      )
    end

    UI.success("🎉 Hoàn tất đồng bộ Certificate & Profile macOS qua Fastlane Match!")
  end

  desc "Build Flutter macOS Package (.pkg) cho 1 app (không upload)"
  lane :build do |options|
    build_macos(options)
  end

  desc "Build Flutter macOS Package (.pkg) cho 1 app (alias: build_macos)"
  lane :build_macos do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane mac build app:OpsFlow_Hub [version:1.0.0] [build_number:1]")
    app_info = get_app_config(app_key)
    
    # 1. Tải hoặc cập nhật mã nguồn vào thư mục .workspace
    workspace_dir = prepare_app_workspace(app_key, app_info, options, "macos")

    bundle_id = resolve_bundle_id(app_info, "macos", options)
    flavor = resolve_flavor(app_info, options)
    version_name, build_number = resolve_version_and_build_number(app_info, options)

    UI.message("🚀 ========================================================")
    UI.message("🚀 Bắt đầu build macOS: #{app_info['app_name']} (#{bundle_id})")
    UI.message("🚀 Workspace: #{workspace_dir}")
    UI.message("🚀 Version (Build Name): #{version_name || 'Mặc định từ pubspec.yaml'}")
    UI.message("🚀 Build Number: #{build_number}")
    UI.message("🚀 Flavor: #{flavor && !flavor.empty? ? flavor : 'None'}")
    UI.message("🚀 ========================================================")

    # 2. Tải và cài đặt Certificates/Profiles qua Match nếu không bỏ qua
    if options[:skip_certs] != true && options[:skip_certs] != "true"
      begin
        api_key = get_api_key
        # 2.1 App Distribution Profile macOS & Apple Distribution Certificate
        match(
          type: "appstore",
          platform: "macos",
          generate_apple_certs: true,
          app_identifier: bundle_id,
          api_key: api_key,
          readonly: true
        )
        # 2.2 Installer Distribution Certificate (.pkg)
        match(
          type: "mac_installer_distribution",
          platform: "macos",
          app_identifier: bundle_id,
          skip_provisioning_profiles: true,
          api_key: api_key,
          readonly: true
        )
      rescue => e
        UI.important("⚠️ Không thể đồng bộ qua Match (#{e.message}). Sẽ tiếp tục nếu chứng chỉ đã có sẵn trên máy.")
      end
    end

    # 3. Compile cấu hình Flutter macOS trong workspace
    build_args = []
    scheme_file = File.join(workspace_dir, "macos/Runner.xcodeproj/xcshareddata/xcschemes/#{flavor}.xcscheme")
    
    if flavor && !flavor.empty?
      if File.exist?(scheme_file)
        build_args << "--flavor #{flavor}"
      else
        UI.important("⚠️ Không tìm thấy Xcode scheme '#{flavor}.xcscheme' tại #{scheme_file}. Sẽ build scheme mặc định (Runner).")
      end
    end
    
    build_args << "--build-name=#{version_name}" if version_name && !version_name.empty?
    build_args << "--build-number=#{build_number}" if build_number && !build_number.empty?

    flutter_cmd = "flutter build macos --release --config-only #{build_args.join(' ')}"
    UI.message("🛠 Đang chuẩn bị cấu hình Flutter macOS trong workspace: #{flutter_cmd}")
    run_flutter_cmd(flutter_cmd, workspace_dir)

    # 4. Cấu hình Code Signing & Team ID cho Xcode Project trong workspace
    xcode_project = File.join(workspace_dir, "macos/Runner.xcodeproj")
    xcode_workspace = File.join(workspace_dir, "macos/Runner.xcworkspace")

    team_id = ENV["APPLE_TEAM_ID"] || CredentialsManager::AppfileConfig.try_fetch_value(:team_id)
    profile_name = ENV["sigh_#{bundle_id}_appstore_macos_profile-name"] ||
                   ENV["sigh_#{bundle_id}_macos_profile-name"] ||
                   ENV["sigh_#{bundle_id}_mac_appstore_profile-name"] ||
                   ENV["sigh_#{bundle_id}_appstore_profile-name"] ||
                   "match AppStore #{bundle_id} macos"
    code_sign_identity = ENV["MATCH_CERTIFICATE_NAME"] || "Apple Distribution"
    scheme_name = (flavor && !flavor.empty? && File.exist?(scheme_file)) ? flavor : "Runner"

    if team_id && !team_id.empty?
      UI.message("📝 Cập nhật Development Team: #{team_id} cho #{xcode_project}")
      UI.message("📝 Cập nhật Code Sign Identity: #{code_sign_identity}")
      update_project_team(
        path: xcode_project,
        teamid: team_id
      )
      update_code_signing_settings(
        use_automatic_signing: false,
        path: xcode_project,
        team_id: team_id,
        bundle_identifier: bundle_id,
        profile_name: profile_name,
        code_sign_identity: code_sign_identity,
        targets: ["Runner"]
      )
    end

    # 5. Đóng gói & Ký chứng chỉ PKG bằng Fastlane Gym (build_mac_app)
    output_dir = options[:output_dir] || File.join(workspace_dir, "build/macos/pkg")
    output_name = "#{app_key}-#{version_name || 'release'}-#{build_number}.pkg"

    UI.message("📦 Đang đóng gói PKG với Profile: #{profile_name}, Scheme: #{scheme_name}, Team ID: #{team_id}")
    pkg_file = build_mac_app(
      workspace: xcode_workspace,
      scheme: scheme_name,
      export_method: "app-store",
      clean: true,
      export_team_id: team_id,
      installer_cert_name: "3rd Party Mac Developer Installer",
      output_directory: output_dir,
      output_name: output_name,
      xcargs: team_id ? "DEVELOPMENT_TEAM=#{team_id}" : nil,
      export_options: {
        signingStyle: "manual",
        installerSigningCertificate: "3rd Party Mac Developer Installer",
        provisioningProfiles: {
          bundle_id => profile_name
        }
      }
    )

    UI.success("🎉 Build thành công macOS Package: #{pkg_file}")
    pkg_file
  end

  desc "Build Flutter macOS Package và Upload lên TestFlight hoặc Mac App Store"
  lane :deploy do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane mac deploy app:OpsFlow_Hub [target:testflight|appstore] [version:1.0.0] [build_number:1]")
    target = options[:target] || "testflight"
    
    app_info = get_app_config(app_key)
    validate_platform_support!(app_key, app_info, "macos")

    bundle_id = resolve_bundle_id(app_info, "macos", options)
    api_key = get_api_key
    version_name, build_number = resolve_version_and_build_number(app_info, options)

    UI.message("🚀 ========================================================")
    UI.message("🚀 Bắt đầu phát hành macOS: #{app_info['app_name']} (#{bundle_id})")
    UI.message("🚀 Mục tiêu (Target): #{target}")
    UI.message("🚀 Version (Build Name): #{version_name || 'Mặc định từ pubspec.yaml'}")
    UI.message("🚀 Build Number: #{build_number}")
    UI.message("🚀 ========================================================")

    # 1. Tải và cài đặt Certificates/Profiles qua Match
    # 1.1 macOS App Distribution Profile & Apple Distribution Certificate
    match(
      type: "appstore",
      platform: "macos",
      generate_apple_certs: true,
      app_identifier: bundle_id,
      api_key: api_key,
      readonly: true
    )

    # 1.2 Mac Installer Distribution (.pkg)
    match(
      type: "mac_installer_distribution",
      platform: "macos",
      app_identifier: bundle_id,
      skip_provisioning_profiles: true,
      api_key: api_key,
      readonly: true
    )

    # 2. Build macOS PKG trong .workspace
    pkg_file = build_macos(
      app: app_key,
      version: version_name,
      build_number: build_number,
      skip_certs: true
    )

    # 3. Upload lên TestFlight hoặc Mac App Store
    if target.to_s.downcase == "testflight"
      upload_to_testflight(
        api_key: api_key,
        app_identifier: bundle_id,
        pkg: pkg_file,
        skip_waiting_for_build_processing: true
      )
    elsif target.to_s.downcase == "appstore"
      upload_to_app_store(
        api_key: api_key,
        app_identifier: bundle_id,
        pkg: pkg_file,
        platform: "osx",
        force: true,
        skip_screenshots: true,
        skip_metadata: true
      )
    else
      UI.user_error!("Target không hợp lệ: #{target}. Chỉ chấp nhận 'testflight' hoặc 'appstore'.")
    end

    UI.success("🎉 Phát hành thành công #{app_info['app_name']} (#{bundle_id}) lên #{target} cho macOS!")
  end
end
