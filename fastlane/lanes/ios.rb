# fastlane/lanes/ios.rb
# Quản lý signing, build & deploy cho nền tảng iOS

platform :ios do
  before_all do
    setup_ci if is_ci
  end

  desc "Đăng ký App Identifier & tạo App mới trên App Store Connect cho iOS"
  lane :register_app do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane ios register_app app:OpsFlow_Hub")
    app_info = get_app_config(app_key)
    validate_platform_support!(app_key, app_info, "ios")

    bundle_id = resolve_bundle_id(app_info, "ios", options)
    api_key = get_api_key

    produce(
      api_key: api_key,
      app_identifier: bundle_id,
      app_name: app_info["app_name"],
      language: "English",
      skip_itc: false
    )

    UI.success("🎉 Đã đăng ký thành công Bundle ID & App trên App Store Connect: #{bundle_id}")
  end

  desc "Dọn dẹp Certificate & Provisioning Profile cũ/hết hạn trên máy local"
  lane :clean_certs do |options|
    clean_old_local_certs(options)
  end

  desc "Đồng bộ Certificate & Provisioning Profile (Match) cho iOS (1 app hoặc tất cả apps)"
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
      validate_platform_support!(app_key, app_info, "ios")
      bundle_ids = [resolve_bundle_id(app_info, "ios", options)]
      UI.message("🔄 Đồng bộ certs iOS cho app: #{app_key} (#{bundle_ids.first})")
    else
      # Lọc các app hỗ trợ nền tảng iOS
      target_apps = apps_data.select do |k, v|
        v["platforms"].nil? || v["platforms"].map { |p| normalize_platform_name(p) }.include?("ios")
      end
      bundle_ids = target_apps.values.map { |a| resolve_bundle_id(a, "ios") }.compact.uniq
      UI.message("🔄 Đồng bộ certs iOS cho #{bundle_ids.length} apps hỗ trợ iOS...")
    end

    api_key = get_api_key

    match(
      type: cert_type,
      platform: "ios",
      app_identifier: bundle_ids,
      api_key: api_key,
      readonly: is_readonly,
      force: is_force
    )

    UI.success("🎉 Hoàn tất đồng bộ Certificate & Profile iOS qua Fastlane Match!")
  end

  desc "Build Flutter IPA cho 1 app (không upload)"
  lane :build do |options|
    build_ios(options)
  end

  desc "Build Flutter IPA cho 1 app (alias: build_ios)"
  lane :build_ios do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane ios build app:OpsFlow_Hub [version:1.0.0] [build_number:1]")
    app_info = get_app_config(app_key)
    
    # 1. Tải hoặc cập nhật mã nguồn vào thư mục .workspace
    workspace_dir = prepare_app_workspace(app_key, app_info, options, "ios")

    bundle_id = resolve_bundle_id(app_info, "ios", options)
    flavor = resolve_flavor(app_info, options)
    version_name, build_number = resolve_version_and_build_number(app_info, options)

    UI.message("🚀 ========================================================")
    UI.message("🚀 Bắt đầu build iOS: #{app_info['app_name']} (#{bundle_id})")
    UI.message("🚀 Workspace: #{workspace_dir}")
    UI.message("🚀 Version (Build Name): #{version_name || 'Mặc định từ pubspec.yaml'}")
    UI.message("🚀 Build Number: #{build_number}")
    UI.message("🚀 Flavor: #{flavor && !flavor.empty? ? flavor : 'None'}")
    UI.message("🚀 ========================================================")

    # 2. Tải và cài đặt Certificates/Profiles qua Match nếu không bỏ qua
    if options[:skip_certs] != true && options[:skip_certs] != "true"
      begin
        api_key = get_api_key
        match(
          type: "appstore",
          platform: "ios",
          app_identifier: bundle_id,
          api_key: api_key,
          readonly: true
        )
      rescue => e
        UI.important("⚠️ Không thể đồng bộ qua Match (#{e.message}). Sẽ tiếp tục nếu chứng chỉ đã có sẵn trên máy.")
      end
    end

    # 3. Compile Flutter iOS bundle trong thư mục workspace
    build_args = []
    scheme_file = File.join(workspace_dir, "ios/Runner.xcodeproj/xcshareddata/xcschemes/#{flavor}.xcscheme")
    
    if flavor && !flavor.empty?
      if File.exist?(scheme_file)
        build_args << "--flavor #{flavor}"
      else
        UI.important("⚠️ Không tìm thấy Xcode scheme '#{flavor}.xcscheme' tại #{scheme_file}. Sẽ build scheme mặc định (Runner).")
      end
    end
    
    build_args << "--build-name=#{version_name}" if version_name && !version_name.empty?
    build_args << "--build-number=#{build_number}" if build_number && !build_number.empty?

    flutter_cmd = "flutter build ios --release --no-codesign #{build_args.join(' ')}"
    UI.message("🛠 Đang compile Flutter iOS trong workspace: #{flutter_cmd}")
    run_flutter_cmd(flutter_cmd, workspace_dir)

    # 4. Cấu hình Code Signing & Team ID cho Xcode Project trong workspace
    xcode_project = File.join(workspace_dir, "ios/Runner.xcodeproj")
    xcode_workspace = File.join(workspace_dir, "ios/Runner.xcworkspace")

    team_id = ENV["APPLE_TEAM_ID"] || CredentialsManager::AppfileConfig.try_fetch_value(:team_id)
    profile_name = ENV["sigh_#{bundle_id}_appstore_profile-name"] || "match AppStore #{bundle_id}"
    scheme_name = (flavor && !flavor.empty? && File.exist?(scheme_file)) ? flavor : "Runner"

    if team_id && !team_id.empty?
      UI.message("📝 Cập nhật Development Team: #{team_id} cho #{xcode_project}")
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
        code_sign_identity: "Apple Distribution",
        targets: ["Runner"]
      )
    end

    # 5. Đóng gói & Ký chứng chỉ IPA bằng Fastlane Gym (build_app)
    output_dir = options[:output_dir] || File.join(workspace_dir, "build/ios/ipa")
    output_name = "#{app_key}-#{version_name || 'release'}-#{build_number}.ipa"
    
    UI.message("📦 Đang đóng gói IPA với Profile: #{profile_name}, Scheme: #{scheme_name}, Team ID: #{team_id}")
    ipa_file = build_app(
      workspace: xcode_workspace,
      scheme: scheme_name,
      export_method: "app-store",
      clean: true,
      export_team_id: team_id,
      output_directory: output_dir,
      output_name: output_name,
      xcargs: team_id ? "DEVELOPMENT_TEAM=#{team_id}" : nil,
      export_options: {
        signingStyle: "manual",
        provisioningProfiles: {
          bundle_id => profile_name
        }
      }
    )

    UI.success("🎉 Build thành công IPA: #{ipa_file}")
    ipa_file
  end

  desc "Build Flutter IPA và Upload lên TestFlight hoặc App Store"
  lane :deploy do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane ios deploy app:OpsFlow_Hub [target:testflight|appstore] [version:1.0.0] [build_number:1]")
    target = options[:target] || "testflight"
    
    app_info = get_app_config(app_key)
    validate_platform_support!(app_key, app_info, "ios")

    bundle_id = resolve_bundle_id(app_info, "ios", options)
    api_key = get_api_key
    version_name, build_number = resolve_version_and_build_number(app_info, options)

    UI.message("🚀 ========================================================")
    UI.message("🚀 Bắt đầu phát hành iOS: #{app_info['app_name']} (#{bundle_id})")
    UI.message("🚀 Mục tiêu (Target): #{target}")
    UI.message("🚀 Version (Build Name): #{version_name || 'Mặc định từ pubspec.yaml'}")
    UI.message("🚀 Build Number: #{build_number}")
    UI.message("🚀 ========================================================")

    # 1. Tải và cài đặt Certificates/Profiles qua Match
    match(
      type: "appstore",
      platform: "ios",
      app_identifier: bundle_id,
      api_key: api_key,
      readonly: true
    )

    # 2. Build IPA trong .workspace
    ipa_file = build_ios(
      app: app_key,
      version: version_name,
      build_number: build_number,
      skip_certs: true
    )

    # 3. Upload lên TestFlight hoặc App Store
    if target.to_s.downcase == "testflight"
      upload_to_testflight(
        api_key: api_key,
        app_identifier: bundle_id,
        ipa: ipa_file,
        skip_waiting_for_build_processing: true
      )
    elsif target.to_s.downcase == "appstore"
      should_upload_metadata = options[:upload_metadata] == true || options[:upload_metadata] == "true"
      metadata_dir = resolve_metadata_path(app_key, "ios", options)
      screenshots_dir = resolve_screenshots_path(app_key, "ios", options)
      skip_screenshots = options[:upload_screenshots] != true && options[:upload_screenshots] != "true" && options[:screenshots] != true && options[:screenshots] != "true"

      upload_to_app_store(
        api_key: api_key,
        app_identifier: bundle_id,
        ipa: ipa_file,
        force: true,
        metadata_path: metadata_dir,
        screenshots_path: screenshots_dir,
        skip_screenshots: skip_screenshots,
        skip_metadata: !should_upload_metadata,
        run_precheck_before_submit: false
      )
    else
      UI.user_error!("Target không hợp lệ: #{target}. Chỉ chấp nhận 'testflight' hoặc 'appstore'.")
    end

    UI.success("🎉 Phát hành thành công #{app_info['app_name']} (#{bundle_id}) lên #{target} cho iOS!")
  end

  desc "Cập nhật (Push/Upload) Metadata lên App Store Connect cho iOS"
  lane :push_metadata do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane ios push_metadata app:OpsFlow_Hub [version:1.0.0] [upload_screenshots:true]")
    upload_app_metadata_to_store(app_key, "ios", options)
  end

  desc "Cập nhật Metadata lên App Store Connect cho iOS (alias: push_metadata)"
  lane :upload_metadata do |options|
    push_metadata(options)
  end

  desc "Tải (Pull/Download) Metadata và Screenshots từ App Store Connect về local cho iOS để chỉnh sửa"
  lane :pull_metadata do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane ios pull_metadata app:OpsFlow_Hub [skip_screenshots:false]")
    download_app_metadata_from_store(app_key, "ios", options)
  end

  desc "Tải Metadata và Screenshots từ App Store Connect về local cho iOS (alias: pull_metadata)"
  lane :download_metadata do |options|
    pull_metadata(options)
  end

  desc "Khởi tạo thư mục và các file Metadata template mẫu cho iOS app"
  lane :init_metadata do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane ios init_metadata app:OpsFlow_Hub")
    app_info = get_app_config(app_key)
    init_app_metadata_template(app_key, app_info, "ios")
  end
end
