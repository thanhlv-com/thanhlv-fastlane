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
    init_app_metadata_template(app_key, app_info, "windows", TOP_20_METADATA_LOCALES, options)
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

    # Xử lý riêng cho dự án Electron Desktop
    if is_electron_app?(app_info, workspace_dir)
      UI.message("⚡ Phát hiện dự án Electron Desktop. Bắt đầu đóng gói Windows qua electron-builder...")
      pkg_mgr = (app_info["package_manager"] || "npm").to_s.downcase

      node_modules = File.join(workspace_dir, "node_modules")
      unless File.directory?(node_modules)
        UI.message("📦 Cài đặt dependencies cho Electron: #{pkg_mgr} install...")
        run_node_cmd("#{pkg_mgr} install", workspace_dir)
      end

      package_json_path = File.join(workspace_dir, "package.json")
      pkg_json = JSON.parse(File.read(package_json_path)) rescue {}
      scripts = pkg_json["scripts"] || {}

      build_cmd = if scripts["build:win"]
                    "#{pkg_mgr} run build:win"
                  elsif scripts["build"]
                    "#{pkg_mgr} run build && npx electron-builder --win"
                  else
                    "npx electron-builder --win"
                  end

      UI.message("🛠 Đang đóng gói Electron Windows: #{build_cmd}")
      run_node_cmd(build_cmd, workspace_dir)

      dist_dir = File.join(workspace_dir, "dist")
      exe_files = Dir.glob(File.join(dist_dir, "*.exe"))
      artifact_path = exe_files.first

      UI.success("🎉 Đóng gói Electron Windows thành công!")
      UI.success("📦 Thư mục output: #{dist_dir}")
      UI.success("📦 File sản phẩm: #{artifact_path}") if artifact_path
      next artifact_path || dist_dir
    end

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
