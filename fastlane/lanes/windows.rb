# fastlane/lanes/windows.rb
# Quản lý build, deploy & metadata cho nền tảng Windows

platform :windows do
  before_all do
    setup_ci if is_ci
  end

  desc "Khởi tạo thư mục và các file Metadata template mẫu cho Windows app"
  lane :init_metadata do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane windows init_metadata app:OpsFlow_Hub")
    app_info = get_app_config(app_key)
    init_app_metadata_template(app_key, app_info, "windows")
  end

  desc "Kiểm tra và chuẩn bị Metadata Windows cho phát hành"
  lane :upload_metadata do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane windows upload_metadata app:OpsFlow_Hub")
    upload_app_metadata_to_store(app_key, "windows", options)
  end

  desc "Cập nhật Metadata Windows (alias: upload_metadata)"
  lane :push_metadata do |options|
    upload_metadata(options)
  end

  desc "Build Flutter Windows Release Executable (.exe / .zip)"
  lane :build do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane windows build app:OpsFlow_Hub")
    app_info = get_app_config(app_key)
    workspace_dir = prepare_app_workspace(app_key, app_info, options, "windows")

    version_name, build_number = resolve_version_and_build_number(app_info, options)
    obfuscate_enabled = resolve_obfuscate(app_info, options)

    UI.message("🚀 ========================================================")
    UI.message("🚀 Bắt đầu build Windows: #{app_info['app_name']}")
    UI.message("🚀 Workspace: #{workspace_dir}")
    UI.message("🚀 Version (Build Name): #{version_name || 'Mặc định từ pubspec.yaml'}")
    UI.message("🚀 Build Number: #{build_number}")
    UI.message("🚀 Obfuscate: #{obfuscate_enabled ? 'Bật (--obfuscate)' : 'Tắt'}")
    UI.message("🚀 ========================================================")

    build_args = []
    build_args << "--build-name=#{version_name}" if version_name && !version_name.empty?
    build_args << "--build-number=#{build_number}" if build_number && !build_number.empty?
    build_args.concat(build_flutter_obfuscate_args(workspace_dir, "windows", app_info, options))

    flutter_cmd = "flutter build windows --release #{build_args.join(' ')}"
    UI.message("🛠 Đang compile Flutter Windows: #{flutter_cmd}")
    run_flutter_cmd(flutter_cmd, workspace_dir)

    UI.success("🎉 Build thành công Windows Release tại: #{File.join(workspace_dir, 'build/windows/runner/Release')}")
  end
end
