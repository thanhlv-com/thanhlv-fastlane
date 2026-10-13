# fastlane/lanes/standalone.rb
# Quản lý build & đóng gói Standalone cho các ứng dụng Desktop (Electron / Flutter)
# Độc lập hoàn toàn với các luồng App Store / TestFlight / Play Store.

platform :standalone do
  before_all do
    setup_ci if is_ci
  end

  desc "Build ứng dụng Desktop Standalone cho macOS (.dmg / .zip)"
  lane :mac_build do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane standalone mac_build app:<app_key>")
    app_info = get_app_config(app_key)
    workspace_dir = prepare_app_workspace(app_key, app_info, options, "macos")

    version_name, build_number = resolve_version_and_build_number(app_info, options)
    bundle_id = resolve_bundle_id(app_info, "macos", options)

    UI.message("🚀 ========================================================")
    UI.message("🚀 Bắt đầu build Standalone macOS: #{app_info['app_name']}")
    UI.message("🚀 Framework: #{app_info['framework'] || 'flutter'}")
    UI.message("🚀 Workspace: #{workspace_dir}")
    UI.message("🚀 Bundle ID: #{bundle_id}")
    UI.message("🚀 Version: #{version_name || 'Mặc định'}")
    UI.message("🚀 Build Number: #{build_number}")
    UI.message("🚀 ========================================================")

    # Nếu có cấu hình Match certs và không bỏ qua, chuẩn bị keychain certificates cho macOS
    skip_certs = options[:skip_certs] == true || options[:skip_certs] == "true"
    if !skip_certs && is_ci && ENV["MATCH_PASSWORD"]
      begin
        api_key = get_api_key rescue nil
        UI.message("🔑 Đang cài đặt chứng chỉ Apple qua Match để ký DMG Standalone...")
        match(
          type: "appstore",
          platform: "macos",
          generate_apple_certs: true,
          app_identifier: bundle_id,
          api_key: api_key,
          readonly: true
        ) rescue nil
      rescue => e
        UI.important("⚠️ Không thể tải Match certs (#{e.message}). Tiếp tục với chứng chỉ local hoặc ad-hoc.")
      end
    end

    if is_electron_app?(app_info, workspace_dir)
      pkg_mgr = (app_info["package_manager"] || "npm").to_s.downcase

      node_modules = File.join(workspace_dir, "node_modules")
      unless File.directory?(node_modules)
        UI.message("📦 Cài đặt dependencies: #{pkg_mgr} install...")
        run_node_cmd("#{pkg_mgr} install", workspace_dir)
      end

      package_json_path = File.join(workspace_dir, "package.json")
      pkg_json = JSON.parse(File.read(package_json_path)) rescue {}
      scripts = pkg_json["scripts"] || {}

      build_cmd = if scripts["build:mac"]
                    "#{pkg_mgr} run build:mac"
                  elsif scripts["build"]
                    "#{pkg_mgr} run build && npx electron-builder --mac"
                  else
                    "npx electron-builder --mac"
                  end

      UI.message("🛠 Đang đóng gói Electron macOS Standalone: #{build_cmd}")
      run_node_cmd(build_cmd, workspace_dir)

      dist_dir = File.join(workspace_dir, "dist")
      dmg_files = Dir.glob(File.join(dist_dir, "*.dmg"))
      zip_files = Dir.glob(File.join(dist_dir, "*.zip"))
      artifact_path = dmg_files.first || zip_files.first

      UI.success("🎉 Đóng gói Electron macOS Standalone (.dmg) thành công!")
      UI.success("📦 Thư mục output: #{dist_dir}")
      UI.success("📦 File sản phẩm DMG: #{artifact_path}") if artifact_path

      next artifact_path || dist_dir
    else
      # Flutter standalone macOS
      build_args = []
      build_args << "--build-name=#{version_name}" if version_name && !version_name.empty?
      build_args << "--build-number=#{build_number}" if build_number && !build_number.empty?
      build_args.concat(build_flutter_obfuscate_args(workspace_dir, "macos", app_info, options))

      flutter_cmd = "flutter build macos --release #{build_args.join(' ')}"
      UI.message("🛠 Đang compile Flutter macOS Standalone: #{flutter_cmd}")
      run_flutter_cmd(flutter_cmd, workspace_dir)

      output_dir = File.join(workspace_dir, "build/macos/Build/Products/Release")
      UI.success("🎉 Build Flutter macOS Standalone thành công tại: #{output_dir}")
      next output_dir
    end
  end

  desc "Build ứng dụng Desktop Standalone cho Windows (.exe)"
  lane :win_build do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane standalone win_build app:<app_key>")
    app_info = get_app_config(app_key)
    workspace_dir = prepare_app_workspace(app_key, app_info, options, "windows")

    version_name, build_number = resolve_version_and_build_number(app_info, options)

    UI.message("🚀 ========================================================")
    UI.message("🚀 Bắt đầu build Standalone Windows: #{app_info['app_name']}")
    UI.message("🚀 Framework: #{app_info['framework'] || 'flutter'}")
    UI.message("🚀 Workspace: #{workspace_dir}")
    UI.message("🚀 ========================================================")

    if is_electron_app?(app_info, workspace_dir)
      pkg_mgr = (app_info["package_manager"] || "npm").to_s.downcase

      node_modules = File.join(workspace_dir, "node_modules")
      unless File.directory?(node_modules)
        UI.message("📦 Cài đặt dependencies: #{pkg_mgr} install...")
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

      UI.message("🛠 Đang đóng gói Electron Windows Standalone: #{build_cmd}")
      run_node_cmd(build_cmd, workspace_dir)

      dist_dir = File.join(workspace_dir, "dist")
      exe_files = Dir.glob(File.join(dist_dir, "*.exe"))
      artifact_path = exe_files.first

      UI.success("🎉 Đóng gói Electron Windows Standalone (.exe) thành công!")
      UI.success("📦 Thư mục output: #{dist_dir}")
      UI.success("📦 File sản phẩm EXE: #{artifact_path}") if artifact_path

      next artifact_path || dist_dir
    else
      # Flutter Windows
      build_args = []
      build_args << "--build-name=#{version_name}" if version_name && !version_name.empty?
      build_args << "--build-number=#{build_number}" if build_number && !build_number.empty?
      build_args.concat(build_flutter_obfuscate_args(workspace_dir, "windows", app_info, options))

      flutter_cmd = "flutter build windows --release #{build_args.join(' ')}"
      UI.message("🛠 Đang compile Flutter Windows: #{flutter_cmd}")
      run_flutter_cmd(flutter_cmd, workspace_dir)

      output_dir = File.join(workspace_dir, "build/windows/runner/Release")
      UI.success("🎉 Build Flutter Windows thành công tại: #{output_dir}")
      next output_dir
    end
  end

  desc "Build ứng dụng Desktop Standalone cho Linux (.AppImage / .deb)"
  lane :linux_build do |options|
    app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane standalone linux_build app:<app_key>")
    app_info = get_app_config(app_key)
    workspace_dir = prepare_app_workspace(app_key, app_info, options, "linux")

    version_name, build_number = resolve_version_and_build_number(app_info, options)

    UI.message("🚀 ========================================================")
    UI.message("🚀 Bắt đầu build Standalone Linux: #{app_info['app_name']}")
    UI.message("🚀 Framework: #{app_info['framework'] || 'flutter'}")
    UI.message("🚀 Workspace: #{workspace_dir}")
    UI.message("🚀 ========================================================")

    if is_electron_app?(app_info, workspace_dir)
      pkg_mgr = (app_info["package_manager"] || "npm").to_s.downcase

      node_modules = File.join(workspace_dir, "node_modules")
      unless File.directory?(node_modules)
        UI.message("📦 Cài đặt dependencies: #{pkg_mgr} install...")
        run_node_cmd("#{pkg_mgr} install", workspace_dir)
      end

      package_json_path = File.join(workspace_dir, "package.json")
      pkg_json = JSON.parse(File.read(package_json_path)) rescue {}
      scripts = pkg_json["scripts"] || {}

      build_cmd = if scripts["build:linux"]
                    "#{pkg_mgr} run build:linux"
                  elsif scripts["build"]
                    "#{pkg_mgr} run build && npx electron-builder --linux"
                  else
                    "npx electron-builder --linux"
                  end

      UI.message("🛠 Đang đóng gói Electron Linux Standalone: #{build_cmd}")
      run_node_cmd(build_cmd, workspace_dir)

      dist_dir = File.join(workspace_dir, "dist")
      linux_files = Dir.glob(File.join(dist_dir, "*.{AppImage,deb,snap}"))
      artifact_path = linux_files.first

      UI.success("🎉 Đóng gói Electron Linux Standalone thành công!")
      UI.success("📦 Thư mục output: #{dist_dir}")
      UI.success("📦 File sản phẩm: #{artifact_path}") if artifact_path

      next artifact_path || dist_dir
    else
      # Flutter Linux
      build_args = []
      build_args << "--build-name=#{version_name}" if version_name && !version_name.empty?
      build_args << "--build-number=#{build_number}" if build_number && !build_number.empty?
      build_args.concat(build_flutter_obfuscate_args(workspace_dir, "linux", app_info, options))

      flutter_cmd = "flutter build linux --release #{build_args.join(' ')}"
      UI.message("🛠 Đang compile Flutter Linux: #{flutter_cmd}")
      run_flutter_cmd(flutter_cmd, workspace_dir)

      output_dir = File.join(workspace_dir, "build/linux/x64/release/bundle")
      UI.success("🎉 Build Flutter Linux thành công tại: #{output_dir}")
      next output_dir
    end
  end

  desc "Dispatcher tự động điều hướng build Standalone theo platform (platform: all|macos|windows|linux)"
  lane :build do |options|
    target_platform = (options[:platform] || options[:target_platform] || "all").to_s.downcase
    case target_platform
    when "all"
      UI.message("🌐 Bắt đầu build tất cả nền tảng Desktop Standalone (macOS, Windows, Linux)...")
      results = {}
      results[:mac] = mac_build(options)
      results[:win] = win_build(options)
      results[:linux] = linux_build(options)
      next results
    when "macos", "mac", "darwin"
      mac_build(options)
    when "windows", "win"
      win_build(options)
    when "linux"
      linux_build(options)
    else
      UI.user_error!("❌ Nền tảng '#{target_platform}' không được hỗ trợ trong standalone build. Chọn: all, macos, windows, linux")
    end
  end
end
