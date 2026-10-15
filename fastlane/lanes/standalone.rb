# fastlane/lanes/standalone.rb
# Quản lý build & đóng gói Standalone cho các ứng dụng Desktop (Electron / Flutter)
# Độc lập hoàn toàn với các luồng App Store / TestFlight / Play Store.

require 'base64'
require 'tmpdir'
require 'fileutils'

# Trích xuất hoặc chuẩn bị file .p8 từ các nguồn cấu hình để dùng cho xcrun notarytool
def get_asc_api_key_file
  key_id = ENV["ASC_KEY_ID"]
  key_id = "FMTTSQML5M" if key_id.nil? || key_id.to_s.strip.empty?
  issuer_id = ENV["ASC_ISSUER_ID"]

  return nil if issuer_id.nil? || issuer_id.to_s.strip.empty?

  # 1. Kiểm tra file .p8 local có sẵn
  local_candidates = [
    ENV["ASC_KEY_PATH"],
    File.join(__dir__, "..", "api_keys", "AuthKey_#{key_id}.p8"),
    File.join(__dir__, "..", "AuthKey_#{key_id}.p8")
  ].compact.map { |f| File.expand_path(f) }
  local_file = local_candidates.find { |f| File.file?(f) }
  return [key_id, issuer_id, local_file, false] if local_file

  # 2. Biến môi trường ASC_KEY_CONTENT (trên CI/CD)
  key_content = ENV["ASC_KEY_CONTENT"]
  if key_content && !key_content.strip.empty?
    formatted = key_content.include?("BEGIN PRIVATE KEY") ? key_content : Base64.decode64(key_content)
    tmp_dir = Dir.mktmpdir("asc_key_")
    tmp_file = File.join(tmp_dir, "AuthKey_#{key_id}.p8")
    File.write(tmp_file, formatted)
    File.chmod(0600, tmp_file)
    return [key_id, issuer_id, tmp_file, true]
  end

  # 3. Tải từ MATCH_GIT_URL nếu có fetch_key_from_match_git
  match_password = ENV["MATCH_PASSWORD"]
  if match_password && !match_password.empty? && defined?(fetch_key_from_match_git)
    decrypted = fetch_key_from_match_git(key_id, match_password) rescue nil
    if decrypted && !decrypted.empty?
      tmp_dir = Dir.mktmpdir("asc_key_")
      tmp_file = File.join(tmp_dir, "AuthKey_#{key_id}.p8")
      File.write(tmp_file, decrypted)
      File.chmod(0600, tmp_file)
      return [key_id, issuer_id, tmp_file, true]
    end
  end

  nil
end

# Tự động gửi file DMG/PKG lên Apple Notary Service và dán tem (Staple)
def notarize_macos_artifact(artifact_path, options = {})
  return false unless File.exist?(artifact_path)
  return false unless artifact_path.end_with?(".dmg") || artifact_path.end_with?(".pkg")

  UI.message("🛡️ ========================================================")
  UI.message("🛡️ Bắt đầu quy trình Apple Notarization tự động cho macOS...")
  UI.message("🛡️ File: #{File.basename(artifact_path)}")
  UI.message("🛡️ ========================================================")

  key_info = get_asc_api_key_file
  if key_info.nil?
    UI.important("⚠️ Không tìm thấy thông tin App Store Connect API Key (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT). Bỏ qua bước Notarization.")
    return false
  end

  key_id, issuer_id, key_file, is_tmp = key_info
  UI.message("🔑 Sử dụng ASC Key ID: #{key_id}")
  UI.message("🔑 Sử dụng ASC Issuer ID: #{issuer_id}")

  # 1. Gửi file lên Apple Notary Service
  notary_cmd = "xcrun notarytool submit \"#{artifact_path}\" --key \"#{key_file}\" --key-id \"#{key_id}\" --issuer \"#{issuer_id}\" --wait"
  UI.message("🚀 Đang gửi file lên Apple Notary Service và chờ kết quả quét mã độc...")

  begin
    notary_output = sh(notary_cmd)
    UI.message(notary_output)

    if notary_output.include?("status: Accepted") || notary_output.include?("Accepted")
      UI.success("🎉 Apple Notarization THÀNH CÔNG! File đã được Apple quét và phê duyệt an toàn.")

      # 2. Dán tem (Staple) vào file
      UI.message("📎 Đang dán tem phê duyệt Notarization vào file (xcrun stapler staple)...")
      begin
        staple_output = sh("xcrun stapler staple \"#{artifact_path}\"")
        UI.message(staple_output)
        if staple_output.include?("worked!")
          UI.success("✅ Đã dán tem Notarization Ticket thành công vào #{File.basename(artifact_path)}!")
        else
          UI.message("ℹ️ Kết quả stapler: #{staple_output.strip}")
        end
      rescue => e_staple
        UI.important("⚠️ Không thể dán tem stapler: #{e_staple.message}. Ticket vẫn có giá trị trực tuyến trên server Apple.")
      end
      return true
    else
      UI.error("⚠️ Apple Notarization không đạt trạng thái Accepted.")
      # Lấy submission id để đọc log chi tiết
      if notary_output =~ /id:\s*([a-f0-9\-]+)/i
        sub_id = $1
        UI.message("🔍 Đang tải log chi tiết từ Apple cho submission ID: #{sub_id}...")
        log_cmd = "xcrun notarytool log \"#{sub_id}\" --key \"#{key_file}\" --key-id \"#{key_id}\" --issuer \"#{issuer_id}\""
        sh(log_cmd) rescue nil
      end
      return false
    end
  rescue => e_notary
    UI.important("⚠️ Quá trình Apple Notarization gặp thông báo: #{e_notary.message}")
    return false
  ensure
    if is_tmp && key_file && File.exist?(key_file)
      FileUtils.rm_rf(File.dirname(key_file)) rescue nil
    end
  end
end

platform :standalone do
  before_all do
    setup_ci if is_ci
  end

  desc "Đồng bộ hoặc tạo mới chứng chỉ Developer ID Application qua Match (dùng để ký Standalone & Notarize)"
  lane :sync_developer_id do |options|
    app_key = options[:app]
    bundle_id = nil

    if app_key && !app_key.to_s.strip.empty? && app_key.to_s.downcase != "all"
      app_info = get_app_config(app_key)
      bundle_id = resolve_bundle_id(app_info, "macos", options)
    else
      # Lấy bundle_id từ app macOS đầu tiên trong apps.json làm mỏ neo định danh cho match
      apps_data = load_apps_config
      target_app = apps_data.find do |_k, v|
        (v["platforms"] || []).map { |p| normalize_platform_name(p) }.include?("macos")
      end
      if target_app
        app_key = target_app[0]
        bundle_id = resolve_bundle_id(target_app[1], "macos")
      else
        bundle_id = "com.thanhlv.webclone"
      end
    end

    is_readonly = options[:readonly] == true || options[:readonly] == "true"
    is_force = options[:force] == true || options[:force] == "true"
    api_key = get_api_key

    UI.message("🔑 ========================================================")
    UI.message("🔑 Đồng bộ / Tạo chứng chỉ Developer ID Application qua Match")
    UI.message("🔑 App tham chiếu: #{app_key} (#{bundle_id})")
    UI.message("🔑 Readonly: #{is_readonly ? 'Có (Chỉ đọc, không tạo mới)' : 'Không (Tự tạo nếu chưa có hoặc hết hạn)'}")
    UI.message("🔑 Force: #{is_force ? 'Bắt buộc tạo mới' : 'Không (giữ nguyên nếu cert còn hạn)'}")
    UI.message("🔑 ========================================================")

    match(
      type: "developer_id",
      platform: "macos",
      app_identifier: bundle_id,
      api_key: api_key,
      readonly: is_readonly,
      skip_provisioning_profiles: true,
      force: is_force
    )
    UI.success("🎉 Hoàn tất đồng bộ/cập nhật Developer ID Application Certificate trên Keystore!")
  end

  desc "Import chứng chỉ Developer ID Application (.p12) vào apple-certificates-keystore qua Match"
  lane :import_developer_id do |options|
    p12_path = options[:p12_path] || UI.user_error!("Vui lòng chỉ định đường dẫn file: p12_path:<đường_dẫn_file_p12>")
    p12_password = options[:p12_password] || ENV["P12_PASSWORD"] || ENV["MATCH_PASSWORD"] || ""

    UI.user_error!("Không tìm thấy file .p12 tại: #{p12_path}") unless File.exist?(p12_path)

    require 'tmpdir'
    require 'fileutils'
    require 'match'
    require 'match/importer'

    tmp_dir = Dir.mktmpdir("dev_id_import_")
    begin
      cer_pem = File.join(tmp_dir, "cert.pem")
      cer_der = File.join(tmp_dir, "cert.cer")
      key_pem = File.join(tmp_dir, "key.pem")

      # Kiểm tra cờ -legacy cho OpenSSL 3+ (cần thiết để giải mã thuật toán RC2-40-CBC xuất từ macOS Keychain)
      legacy_flag = `openssl pkcs12 -help 2>&1`.include?("-legacy") ? "-legacy" : ""

      ENV["DEV_ID_IMPORT_PASS"] = p12_password

      UI.message("🔑 Đang xử lý file .p12 và trích xuất Certificate (OpenSSL legacy: #{!legacy_flag.empty?})...")
      
      # 1. Trích xuất Certificate (PEM & DER)
      sh("openssl pkcs12 #{legacy_flag} -in \"#{p12_path}\" -clcerts -nokeys -passin env:DEV_ID_IMPORT_PASS -out \"#{cer_pem}\"")
      sh("openssl x509 -in \"#{cer_pem}\" -outform der -out \"#{cer_der}\"")

      # 2. Trích xuất Private Key dạng PEM unencrypted (Fastlane Match lưu private key dạng unencrypted PEM RSA trong file .p12)
      sh("openssl pkcs12 #{legacy_flag} -in \"#{p12_path}\" -nocerts -nodes -passin env:DEV_ID_IMPORT_PASS -out \"#{key_pem}\"")

      # 3. Xác định mã ID định danh (Certificate ID hoặc Serial Number)
      cert_obj = OpenSSL::X509::Certificate.new(File.read(cer_pem))
      serial_hex = cert_obj.serial.to_s(16).upcase
      cert_id = options[:cert_id] || ENV["CERT_ID"]
      cert_id = serial_hex if cert_id.nil? || cert_id.to_s.strip.empty?

      final_cer = File.join(tmp_dir, "#{cert_id}.cer")
      final_p12 = File.join(tmp_dir, "#{cert_id}.p12")
      FileUtils.cp(cer_der, final_cer)
      # Fastlane Match yêu cầu file .p12 chứa Private Key dạng PEM (không đặt password để security import trên macOS không bị lỗi MAC verification)
      FileUtils.cp(key_pem, final_p12)

      api_key = get_api_key rescue nil

      match_params = {
        type: "developer_id",
        platform: "macos",
        git_url: ENV["MATCH_GIT_URL"] || "git@github.com:thanhlv-com/apple-certificates-keystore.git",
        storage_mode: "git",
        git_branch: "master",
        shallow_clone: true,
        skip_provisioning_profiles: true,
        skip_certificate_matching: true,
        api_key: api_key
      }

      config = FastlaneCore::Configuration.create(Match::Options.available_options, match_params)
      UI.message("🚀 Đang mã hóa và đẩy chứng chỉ vào apple-certificates-keystore (ID: #{cert_id})...")
      Match::Importer.new.import_cert(config, cert_path: final_cer, p12_path: final_p12, profile_path: "")
      UI.success("🎉 Đã import và mã hóa thành công Developer ID Certificate (#{cert_id}) vào Keystore!")
    rescue => e
      UI.user_error!("❌ Lỗi khi import chứng chỉ Developer ID: #{e.message}")
    ensure
      ENV.delete("DEV_ID_IMPORT_PASS")
      FileUtils.rm_rf(tmp_dir) if tmp_dir && File.exist?(tmp_dir)
    end
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
        is_readonly = options[:readonly] != false && options[:readonly] != "false"

        # 1.1 Ưu tiên tải chứng chỉ Developer ID Application trước
        begin
          UI.message("🔑 [1/2] Đang đồng bộ chứng chỉ Developer ID Application qua Match...")
          match(
            type: "developer_id",
            platform: "macos",
            app_identifier: bundle_id,
            api_key: api_key,
            readonly: is_readonly,
            skip_provisioning_profiles: true
          )
          ENV["CSC_NAME"] = "Developer ID Application"
        rescue => e_dev
          UI.important("ℹ️ Không thể đồng bộ Developer ID cert (#{e_dev.message}). Fallback sang Distribution cert...")
          match(
            type: "appstore",
            platform: "macos",
            generate_apple_certs: true,
            app_identifier: bundle_id,
            api_key: api_key,
            readonly: true
          ) rescue nil
        end
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

      # 3. Tự động Apple Notarization và Staple cho macOS Standalone
      should_notarize = options[:notarize] != false && options[:notarize] != "false"
      if should_notarize && (is_ci || ENV["ASC_KEY_CONTENT"] || ENV["ASC_KEY_PATH"]) && dmg_files.any?
        dmg_to_notarize = dmg_files.first
        notarize_macos_artifact(dmg_to_notarize, options)
      end

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
