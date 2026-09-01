# fastlane/lanes/linux.rb
# Quản lý build, deploy & metadata cho nền tảng Linux

platform :linux do
  before_all do
    setup_ci if is_ci
  end

  desc "Khởi tạo thư mục và các file Metadata template mẫu cho Linux app"
  lane :init_metadata do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane linux init_metadata app:OpsFlow_Hub")
    app_info = get_app_config(app_key)
    init_app_metadata_template(app_key, app_info, "linux")
  end

  desc "Kiểm tra và chuẩn bị Metadata Linux cho phát hành (AppStream / Metainfo)"
  lane :upload_metadata do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane linux upload_metadata app:OpsFlow_Hub")
    upload_app_metadata_to_store(app_key, "linux", options)
  end

  desc "Cập nhật Metadata Linux (alias: upload_metadata)"
  lane :push_metadata do |options|
    upload_metadata(options)
  end

  desc "Build Flutter Linux Release Executable / Bundle"
  lane :build do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane linux build app:OpsFlow_Hub")
    app_info = get_app_config(app_key)
    workspace_dir = prepare_app_workspace(app_key, app_info, options, "linux")

    version_name, build_number = resolve_version_and_build_number(app_info, options)
    build_args = []
    build_args << "--build-name=#{version_name}" if version_name && !version_name.empty?
    build_args << "--build-number=#{build_number}" if build_number && !build_number.empty?

    flutter_cmd = "flutter build linux --release #{build_args.join(' ')}"
    UI.message("🛠 Đang compile Flutter Linux: #{flutter_cmd}")
    run_flutter_cmd(flutter_cmd, workspace_dir)

    UI.success("🎉 Build thành công Linux Release tại: #{File.join(workspace_dir, 'build/linux/x64/release/bundle')}")
  end
end
