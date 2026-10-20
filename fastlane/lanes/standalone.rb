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

# Tự động gửi file DMG/PKG/ZIP lên Apple Notary Service và dán tem (Staple)
def notarize_macos_artifact(artifact_path, options = {})
  return false unless File.exist?(artifact_path)
  return false unless artifact_path.end_with?(".dmg") || artifact_path.end_with?(".pkg") || artifact_path.end_with?(".zip")

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
      staple_target = options[:staple_target] || artifact_path
      if staple_target.end_with?(".zip")
        UI.message("ℹ️ File .zip đã được Apple phê duyệt Notarization (không cần staple trực tiếp vào zip).")
      else
        UI.message("📎 Đang dán tem phê duyệt Notarization vào file: #{File.basename(staple_target)}...")
        begin
          staple_output = sh("xcrun stapler staple \"#{staple_target}\"")
          UI.message(staple_output)
          if staple_output.include?("worked!")
            UI.success("✅ Đã dán tem Notarization Ticket thành công vào #{File.basename(staple_target)}!")
          else
            UI.message("ℹ️ Kết quả stapler: #{staple_output.strip}")
          end
        rescue => e_staple
          UI.important("⚠️ Không thể dán tem stapler: #{e_staple.message}. Ticket vẫn có giá trị trực tuyến trên server Apple.")
        end
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

# Tự động tối ưu cấu hình electron-builder.yml để đạt tiêu chuẩn Apple Notarization
def configure_electron_macos_signing!(workspace_dir)
  builder_yml = File.join(workspace_dir, "electron-builder.yml")
  builder_yaml = File.join(workspace_dir, "electron-builder.yaml")
  target_file = File.exist?(builder_yml) ? builder_yml : (File.exist?(builder_yaml) ? builder_yaml : nil)

  return unless target_file

  require 'yaml'
  begin
    config = YAML.load_file(target_file) || {}
    config["mac"] ||= {}
    config["mac"]["hardenedRuntime"] = true
    config["mac"]["gatekeeperAssess"] = false

    entitlements_path = File.join(workspace_dir, "build", "entitlements.mac.plist")
    if File.exist?(entitlements_path)
      config["mac"]["entitlements"] ||= "build/entitlements.mac.plist"
      config["mac"]["entitlementsInherit"] ||= "build/entitlements.mac.plist"
    end

    File.write(target_file, YAML.dump(config))
    UI.success("🛠 Đã cấu hình electron-builder (hardenedRuntime=true, gatekeeperAssess=false, entitlements) chuẩn Notarization!")
  rescue => e
    UI.important("⚠️ Không thể cập nhật cấu hình electron-builder: #{e.message}")
  end
end

# Tự động tải và nạp các Apple Intermediate CA & Root CA Certificates vào Keychain
# Giải quyết triệt để lỗi CSSMERR_TP_NOT_TRUSTED trên môi trường CI (GitHub Actions)
def install_apple_intermediate_certificates!
  return unless /darwin/ =~ RUBY_PLATFORM

  cert_urls = [
    # Developer ID CAs (Tối quan trọng cho Developer ID Application / Installer)
    "https://www.apple.com/certificateauthority/DeveloperIDCA.cer",
    "https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer",
    # WWDR CAs (G1 -> G6)
    "https://www.apple.com/certificateauthority/AppleWWDRCAG2.cer",
    "https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer",
    "https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer",
    "https://www.apple.com/certificateauthority/AppleWWDRCAG5.cer",
    "https://www.apple.com/certificateauthority/AppleWWDRCAG6.cer",
    # Apple Root CAs
    "https://www.apple.com/appleca/AppleIncRootCertificate.cer",
    "https://www.apple.com/certificateauthority/AppleRootCA-G2.cer",
    "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer"
  ]

  # Nạp vào tất cả Keychain đang hoạt động trên hệ thống
  target_keychains = [
    File.expand_path("~/Library/Keychains/fastlane_tmp_keychain-db"),
    File.expand_path("~/Library/Keychains/fastlane_tmp_keychain"),
    File.expand_path("~/Library/Keychains/login.keychain-db"),
    File.expand_path("~/Library/Keychains/login.keychain")
  ].select { |p| File.exist?(p) }.uniq

  UI.message("🌐 Đang kiểm tra & nạp Apple Intermediate & Root CA Certificates để khắc phục CSSMERR_TP_NOT_TRUSTED...")
  cert_urls.each do |url|
    filename = File.basename(url)
    tmp_cert = File.join(Dir.tmpdir, filename)
    download_res = system("curl -fsSL --retry 3 --retry-all-errors \"#{url}\" -o \"#{tmp_cert}\"")
    if download_res && File.exist?(tmp_cert)
      target_keychains.each do |kc|
        add_cmd = "security add-certificates -k \"#{kc}\" \"#{tmp_cert}\""
        `#{add_cmd} 2>&1`
      end
      UI.message("   ✅ Đã nạp #{filename} vào: #{target_keychains.map { |k| File.basename(k) }.join(', ')}")
    else
      UI.important("   ⚠️ Không thể tải #{filename} từ #{url}")
    end
  end

  # Đảm bảo Search List của user chứa đầy đủ các Keychains
  if target_keychains.any?
    current_search_list = `security list-keychains -d user 2>/dev/null`.scan(/"([^"]+)"/).flatten
    needed_search_list = (target_keychains + current_search_list + [
      "/Library/Keychains/System.keychain",
      "/System/Library/Keychains/SystemRootCertificates.keychain"
    ]).select { |p| File.exist?(p) }.uniq
    sh("security list-keychains -d user -s #{needed_search_list.map(&:shellescape).join(' ')}") rescue nil
  end

  UI.success("✅ Đã hoàn tất quy trình nạp Apple Intermediate CAs và cập nhật Keychain Search List!")
end

# In chi tiết trạng thái Keychain và Code Signing Identities phục vụ debug/kiểm tra lỗi
def log_keychain_and_signing_status(stage_name = "Debug")
  return unless /darwin/ =~ RUBY_PLATFORM

  UI.message("🔍 ========================================================")
  UI.message("🔍 [LOG KIỂM TRA] #{stage_name}")
  UI.message("🔍 ========================================================")

  # 1. Biến môi trường quan trọng
  UI.message("🌐 [1] Biến môi trường liên quan:")
  UI.message("   - CI: #{ENV['CI'].inspect}")
  UI.message("   - MATCH_KEYCHAIN_NAME: #{ENV['MATCH_KEYCHAIN_NAME'].inspect}")
  UI.message("   - MATCH_KEYCHAIN_PASSWORD: #{ENV['MATCH_KEYCHAIN_PASSWORD'] ? '***[SET]' : 'nil'}")
  UI.message("   - CSC_KEYCHAIN: #{ENV['CSC_KEYCHAIN'].inspect}")
  UI.message("   - CSC_NAME: #{ENV['CSC_NAME'].inspect}")
  UI.message("   - CSC_LINK: #{ENV['CSC_LINK'] ? '***[SET]' : 'nil'}")

  # 2. Cấu hình Keychain hệ thống
  default_kc = `security default-keychain 2>&1`.strip rescue "N/A"
  user_search_list = `security list-keychains -d user 2>&1`.strip rescue "N/A"
  sys_search_list = `security list-keychains -d system 2>&1`.strip rescue "N/A"

  UI.message("🔑 [2] Cấu hình Keychain macOS:")
  UI.message("   - Default Keychain: #{default_kc}")
  UI.message("   - User Search List:\n#{user_search_list.split("\n").map { |l| "       #{l}" }.join("\n")}")
  UI.message("   - System Search List:\n#{sys_search_list.split("\n").map { |l| "       #{l}" }.join("\n")}")

  # 3. Identities trong Search List hiện tại
  all_ids = `security find-identity -p codesigning 2>&1`.strip rescue "N/A"
  valid_ids = `security find-identity -v -p codesigning 2>&1`.strip rescue "N/A"

  UI.message("📋 [3] Code Signing Identities trong Search List hiện hành:")
  UI.message("   [Tất cả identities (-p codesigning)]:\n#{all_ids.split("\n").map { |l| "       #{l}" }.join("\n")}")
  UI.message("   [Identities hợp lệ (-v -p codesigning)]:\n#{valid_ids.split("\n").map { |l| "       #{l}" }.join("\n")}")

  # 4. Quét từng file Keychain cụ thể trên máy
  keychain_files = Dir.glob(File.expand_path("~/Library/Keychains/*keychain*")) + [
    "/Library/Keychains/System.keychain"
  ]
  keychain_files = keychain_files.select { |p| File.file?(p) }.uniq

  UI.message("📂 [4] Quét danh sách file Keychain trên ổ đĩa:")
  keychain_files.each do |kc|
    kc_name = File.basename(kc)
    kc_all = `security find-identity -p codesigning "#{kc}" 2>&1`.strip rescue "N/A"
    kc_val = `security find-identity -v -p codesigning "#{kc}" 2>&1`.strip rescue "N/A"
    UI.message("   📁 #{kc_name} (#{kc}):")
    UI.message("      - Tất cả: #{kc_all.lines.last&.strip || kc_all}")
    UI.message("      - Hợp lệ: #{kc_val.lines.last&.strip || kc_val}")
    if kc_all.include?("identities found") && !kc_all.include?("0 identities found")
      UI.message("      - Chi tiết:\n#{kc_all.split("\n").map { |l| "         #{l}" }.join("\n")}")
    end
  end
  UI.message("🔍 ========================================================")
end

# Đảm bảo chứng chỉ Developer ID Application đã có trong Keychain máy (tự động đồng bộ Match nếu thiếu)
def ensure_developer_id_certificate_in_keychain(bundle_id = "com.thanhlv.*", options = {})
  return nil unless /darwin/ =~ RUBY_PLATFORM

  check_identities = `security find-identity -v -p codesigning 2>/dev/null`
  if check_identities.include?("Developer ID Application")
    match_data = check_identities.match(/"(Developer ID Application: [^"]+)"/)
    identity_name = match_data ? match_data[1] : "Developer ID Application"
    UI.success("✅ Đã tìm thấy chứng chỉ Developer ID Application trong Keychain: #{identity_name}")
    return identity_name
  end

  match_output_dir = Dir.mktmpdir("match_out_")
  begin
    api_key = get_api_key rescue nil
    is_readonly = options[:readonly] != false && options[:readonly] != "false"

    # 1. Tải Apple Intermediate & Root CAs để đảm bảo chuỗi chứng chỉ đầy đủ (tránh CSSMERR_TP_NOT_TRUSTED)
    install_apple_intermediate_certificates!

    # 2. Đồng bộ Developer ID Application Certificate qua Match
    UI.message("🔑 Đang đồng bộ chứng chỉ Developer ID Application qua Match...")
    match(
      type: "developer_id",
      platform: "macos",
      app_identifier: bundle_id,
      api_key: api_key,
      readonly: is_readonly,
      clone_branch_directly: true,
      skip_provisioning_profiles: true,
      output_path: match_output_dir
    )
    UI.success("🎉 Fastlane Match hoàn tất đồng bộ chứng chỉ Developer ID Application!")

    # 3. Tự động khắc phục nếu Keychain chưa có Code Signing Identity (do file .p12 trên Keystore là bản cũ dạng PEM)
    check_identities = `security find-identity -v -p codesigning 2>/dev/null`
    if !check_identities.include?("Developer ID Application")
      UI.important("⚠️ Không tìm thấy Developer ID Application trong Keychain sau bước Match. Đang kích hoạt tự phục hồi...")

      candidate_p12s = Dir.glob(File.join(match_output_dir, "**", "*.{p12,P12,key,pem}"))
      candidate_cers = Dir.glob(File.join(match_output_dir, "**", "*.{cer,CER,crt}"))

      downloaded_p12 = candidate_p12s.uniq.select { |f| File.file?(f) && File.size?(f) }.first
      downloaded_cer = candidate_cers.uniq.select { |f| File.file?(f) && File.size?(f) }.first

      if downloaded_p12 && downloaded_cer
        raw_key = File.binread(downloaded_p12) rescue "".b
        if !raw_key.b.start_with?("\x30\x82".b) && !raw_key.b.include?("BEGIN".b)
          cleaned = raw_key.to_s.gsub(/[\r\n\s]/, '')
          decoded = Base64.decode64(cleaned).b rescue nil
          if decoded && (decoded.start_with?("\x30\x82".b) || decoded.include?("BEGIN".b))
            raw_key = decoded
          end
        end

        work_dir = Dir.mktmpdir("recover_dev_id_")
        begin
          key_raw_file = File.join(work_dir, "key_raw.p12")
          File.binwrite(key_raw_file, raw_key)
          key_pem = File.join(work_dir, "key.pem")
          legacy_flag = `openssl pkcs12 -help 2>&1`.include?("-legacy") ? "-legacy" : ""

          key_extracted = false
          if raw_key.include?("BEGIN".b)
            key_match = raw_key.match(/(-----BEGIN [A-Z ]*PRIVATE KEY-----[^-]+-----END [A-Z ]*PRIVATE KEY-----)/m)
            if key_match
              File.write(key_pem, key_match[1])
              key_extracted = true
            else
              File.binwrite(key_pem, raw_key)
              key_extracted = true
            end
          else
            passwords_to_try = [ENV["MATCH_PASSWORD"], "", ENV["P12_PASSWORD"]].compact.uniq
            passwords_to_try.each do |pass|
              ENV["RECOVER_PASS"] = pass
              cmd = "openssl pkcs12 #{legacy_flag} -in \"#{key_raw_file}\" -nocerts -nodes -passin env:RECOVER_PASS -out \"#{key_pem}\" 2>/dev/null"
              if system(cmd) && File.size?(key_pem)
                key_extracted = true
                break
              end
            end
          end

          key_rsa = File.join(work_dir, "key_rsa.pem")
          system("openssl rsa -in \"#{key_pem}\" -out \"#{key_rsa}\" 2>/dev/null || cp \"#{key_pem}\" \"#{key_rsa}\"")

          target_keychains = [
            (ENV["MATCH_KEYCHAIN_NAME"] ? (FastlaneCore::Helper.keychain_path(ENV["MATCH_KEYCHAIN_NAME"]) rescue nil) : nil),
            (FastlaneCore::Helper.keychain_path("fastlane_tmp_keychain") rescue nil),
            (FastlaneCore::Helper.keychain_path("login.keychain") rescue nil)
          ].compact.uniq.select { |p| File.exist?(p) }

          target_keychains.each do |kc|
            `security import "#{key_rsa}" -k "#{kc}" -P "" -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/productbuild -T /usr/bin/productsign 2>&1`
            `security import "#{downloaded_cer}" -k "#{kc}" -P "" 2>&1`
            kc_pass = ENV["MATCH_KEYCHAIN_PASSWORD"] || ""
            `security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "#{kc_pass}" "#{kc}" 2>/dev/null`
          end

          UI.success("🎉 Đã hoàn tất tự phục hồi Developer ID Application vào Keychain!")
        ensure
          ENV.delete("RECOVER_PASS")
          FileUtils.rm_rf(work_dir) if work_dir && File.exist?(work_dir)
        end
      end
    end
  rescue => e
    UI.error("❌ Lỗi xảy ra trong quá trình đồng bộ Match Developer ID: #{e.class} - #{e.message}")
  ensure
    FileUtils.rm_rf(match_output_dir) if match_output_dir && File.exist?(match_output_dir)
  end

  final_check = `security find-identity -v -p codesigning 2>/dev/null`
  match_data = final_check.match(/"(Developer ID Application: [^"]+)"/)
  match_data ? match_data[1] : (final_check.include?("Developer ID Application") ? "Developer ID Application" : nil)
end

platform :standalone do
  before_all do
    setup_ci if is_ci
  end


  desc "Import chứng chỉ Developer ID Application (.p12) vào apple-certificates-keystore qua Match"
  lane :import_developer_id do |options|
    p12_path = options[:p12_path]
    p12_base64 = options[:p12_base64] || ENV["P12_BASE64"] || ENV["INPUT_P12_BASE64"]
    p12_password = options[:p12_password] || ENV["P12_PASSWORD"] || ENV["MATCH_PASSWORD"] || ""

    require 'tmpdir'
    require 'fileutils'
    require 'base64'
    require 'match'
    require 'match/importer'

    tmp_dir = Dir.mktmpdir("dev_id_import_")
    begin
      input_raw_p12 = File.join(tmp_dir, "input_raw.p12")

      # 1. Trích xuất nội dung raw data từ p12_base64 hoặc p12_path (tự động decode Base64)
      raw_content = nil
      if p12_base64 && !p12_base64.to_s.strip.empty?
        UI.message("📦 Phát hiện chuỗi Base64 truyền trực tiếp. Đang giải mã về raw data...")
        cleaned_b64 = p12_base64.to_s.gsub(/[\r\n\s]/, '')
        raw_content = Base64.decode64(cleaned_b64).b
      elsif p12_path && File.exist?(p12_path)
        raw_content = File.binread(p12_path) rescue "".b
        # Tự động phát hiện nếu file tại p12_path chứa chuỗi Base64 thay vì raw binary
        if !raw_content.b.start_with?("\x30\x82".b) && !raw_content.b.include?("BEGIN".b)
          cleaned_b64 = raw_content.to_s.gsub(/[\r\n\s]/, '')
          decoded = Base64.decode64(cleaned_b64).b rescue nil
          if decoded && (decoded.start_with?("\x30\x82".b) || decoded.include?("BEGIN".b))
            UI.message("📦 Nội dung file tại #{p12_path} là chuỗi Base64. Đã tự động giải mã về raw data!")
            raw_content = decoded
          end
        end
      else
        UI.user_error!("Vui lòng cung cấp chuỗi Base64 (p12_base64:<chuỗi> / ENV['P12_BASE64']) hoặc đường dẫn file (p12_path:<đường_dẫn>)!")
      end

      UI.user_error!("❌ Dữ liệu chứng chỉ đầu vào rỗng!") if raw_content.nil? || raw_content.empty?

      File.binwrite(input_raw_p12, raw_content)

      cer_pem = File.join(tmp_dir, "cert.pem")
      cer_der = File.join(tmp_dir, "cert.cer")
      key_pem = File.join(tmp_dir, "key.pem")

      legacy_flag = `openssl pkcs12 -help 2>&1`.include?("-legacy") ? "-legacy" : ""

      UI.message("🔑 Đang xử lý và bóc tách Certificate + Private Key từ file đầu vào...")

      # Bóc tách Certificate & Private Key từ file đầu vào (hỗ trợ cả text PEM và binary PKCS#12)
      if raw_content.include?("BEGIN")
        UI.message("📄 Dữ liệu đầu vào phát hiện định dạng text PEM. Đang bóc tách Certificate và Private Key...")
        if raw_content.include?("CERTIFICATE")
          cert_match = raw_content.match(/(-----BEGIN CERTIFICATE-----[^-]+-----END CERTIFICATE-----)/m)
          File.write(cer_pem, cert_match[1]) if cert_match
        end
        if raw_content.include?("PRIVATE KEY")
          key_match = raw_content.match(/(-----BEGIN [A-Z ]*PRIVATE KEY-----[^-]+-----END [A-Z ]*PRIVATE KEY-----)/m)
          File.write(key_pem, key_match[1]) if key_match
        end
      else
        # Thử giải mã PKCS#12 bằng danh sách mật khẩu khả dĩ
        passwords_to_try = [p12_password, ENV["MATCH_PASSWORD"], ""].compact.uniq
        extracted = false
        passwords_to_try.each do |test_pass|
          ENV["DEV_ID_TEST_PASS"] = test_pass
          extract_cert_cmd = "openssl pkcs12 #{legacy_flag} -in \"#{input_raw_p12}\" -clcerts -nokeys -passin env:DEV_ID_TEST_PASS -out \"#{cer_pem}\" 2>/dev/null"
          extract_key_cmd = "openssl pkcs12 #{legacy_flag} -in \"#{input_raw_p12}\" -nocerts -nodes -passin env:DEV_ID_TEST_PASS -out \"#{key_pem}\" 2>/dev/null"
          if system(extract_cert_cmd) && File.size?(cer_pem) && system(extract_key_cmd) && File.size?(key_pem)
            extracted = true
            break
          end
        end

        unless extracted
          UI.user_error!("❌ Không thể giải mã file .p12 với mật khẩu đã cung cấp. Vui lòng kiểm tra lại mật khẩu xuất file!")
        end
      end

      UI.user_error!("❌ Không tìm thấy Certificate hợp lệ trong file đầu vào!") unless File.size?(cer_pem)
      UI.user_error!("❌ Không tìm thấy Private Key hợp lệ trong file đầu vào!") unless File.size?(key_pem)

      # Chuyển cert sang định dạng DER (.cer) cho Match
      sh("openssl x509 -in \"#{cer_pem}\" -outform der -out \"#{cer_der}\"")

      # 2. Xác định mã ID định danh (Apple Certificate ID hoặc Serial Number)
      cert_obj = OpenSSL::X509::Certificate.new(File.read(cer_pem))
      serial_hex = cert_obj.serial.to_s(16).upcase
      cert_id = options[:cert_id] || ENV["CERT_ID"]

      api_key = get_api_key rescue nil

      if cert_id.nil? || cert_id.to_s.strip.empty?
        if api_key
          begin
            require 'spaceship'
            token = Spaceship::ConnectAPI::Token.create(**api_key)
            Spaceship::ConnectAPI.token = token
            models = Spaceship::ConnectAPI.get_certificates.to_models
            matching_cert = models.find do |c|
              c.serial_number.to_s.upcase == serial_hex
            end
            if matching_cert
              cert_id = matching_cert.id
              UI.success("🔍 Đã tự động khớp Apple Certificate ID từ Developer Portal: #{cert_id} (Serial: #{serial_hex})")
            end
          rescue => err
            UI.message("⚠️ Không thể truy vấn Certificate ID từ API: #{err.message}")
          end
        end
        cert_id ||= serial_hex
      end

      final_cer = File.join(tmp_dir, "#{cert_id}.cer")
      final_p12 = File.join(tmp_dir, "#{cert_id}.p12")
      FileUtils.cp(cer_der, final_cer)

      # 3. Chuẩn hóa Private Key RSA thuần túy (Fastlane Match lưu private key dạng unencrypted PEM RSA Key trong file .p12 trước khi mã hóa kho Git)
      key_rsa = File.join(tmp_dir, "key_rsa.pem")
      sh("openssl rsa -in \"#{key_pem}\" -out \"#{key_rsa}\"") rescue FileUtils.cp(key_pem, key_rsa)
      File.write(final_p12, File.read(key_rsa))

      # 4. Xác thực độ toàn vẹn của Private Key
      verify_out = `openssl rsa -check -noout -in "#{final_p12}" 2>&1`
      if $?.success?
        UI.success("✅ Private Key RSA (.p12) đã được kiểm tra và xác nhận đạt chuẩn 100% Fastlane Match!")
      else
        UI.user_error!("❌ Lỗi xác thực Private Key vừa tạo: #{verify_out.strip}")
      end

      match_params = {
        type: "developer_id",
        platform: "macos",
        git_url: ENV["MATCH_GIT_URL"] || "git@github.com:thanhlv-com/apple-certificates-keystore.git",
        storage_mode: "git",
        git_branch: "master",
        shallow_clone: true,
        clone_branch_directly: true,
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
      ENV.delete("DEV_ID_TEST_PASS")
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

    # 1. Log kiểm tra trạng thái ban đầu
    log_keychain_and_signing_status("1. TRƯỚC KHI ĐỒNG BỘ CHỨNG CHỈ")

    # 2. Tải và cài đặt Certificates qua Match nếu không bỏ qua (chuẩn hóa tương tự macos.rb)
    skip_certs = options[:skip_certs] == true || options[:skip_certs] == "true"
    if !skip_certs
      identity = ensure_developer_id_certificate_in_keychain(bundle_id, options)
      ENV["CSC_NAME"] = identity || "Developer ID Application"
      log_keychain_and_signing_status("2. SAU KHI ĐỒNG BỘ MATCH")
    else
      UI.message("ℹ️ Bỏ qua bước đồng bộ chứng chỉ do skip_certs: true")
    end

    if is_electron_app?(app_info, workspace_dir)
      pkg_mgr = (app_info["package_manager"] || "npm").to_s.downcase

      # Tự động tối ưu cấu hình electron-builder chuẩn Apple Notarization
      configure_electron_macos_signing!(workspace_dir)

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

      # Log kiểm tra ngay trước khi build electron
      log_keychain_and_signing_status("3. NGAY TRƯỚC KHI CHẠY ELECTRON-BUILDER")

      UI.message("🛠 Đang đóng gói Electron macOS Standalone: #{build_cmd}")
      run_node_cmd(build_cmd, workspace_dir)

      log_keychain_and_signing_status("4. SAU KHI CHẠY ELECTRON-BUILDER")

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

  desc "Đồng bộ chứng chỉ Developer ID Application từ kho Match Keystore vào Keychain local"
  lane :sync_dev_id do |options|
    app_key = options[:app] || "web-clone"
    app_info = get_app_config(app_key) rescue {}
    bundle_id = resolve_bundle_id(app_info, "macos", options) rescue "com.thanhlv.*"
    identity = ensure_developer_id_certificate_in_keychain(bundle_id, options)
    if identity
      UI.success("🎉 Chứng chỉ Developer ID Application sẵn sàng trong Keychain: #{identity}")
      identity
    else
      UI.user_error!("❌ Không thể cài đặt chứng chỉ Developer ID Application vào Keychain.")
    end
  end

  desc "Ký chứng chỉ Developer ID và công chứng (Notarize + Staple) file macOS có sẵn (.dmg, .app, .pkg)"
  lane :sign_file do |options|
    file_path = options[:file] || options[:path] || UI.user_error!("Vui lòng chỉ định đường dẫn file: fastlane standalone sign_file file:<đường_dẫn>")
    file_path = File.expand_path(file_path)
    UI.user_error!("Không tìm thấy file: #{file_path}") unless File.exist?(file_path)

    # 1. Tìm hoặc đồng bộ Identity Developer ID Application
    identity = options[:identity] || ensure_developer_id_certificate_in_keychain("com.thanhlv.*", options)
    unless identity
      UI.user_error!("❌ Không tìm thấy chứng chỉ Developer ID Application hợp lệ trong Keychain!")
    end
    UI.message("🔑 Sử dụng Code Signing Identity: #{identity}")

    # 2. Thực hiện ký file
    if File.directory?(file_path) && file_path.end_with?(".app")
      UI.message("✍️ Đang ký gói ứng dụng (.app): #{file_path}")
      frameworks_dir = File.join(file_path, "Contents", "Frameworks")
      if File.directory?(frameworks_dir)
        Dir.glob(File.join(frameworks_dir, "*.app")).each do |helper_app|
          sh("codesign --force --timestamp --options runtime --sign \"#{identity}\" \"#{helper_app}\"") rescue nil
        end
        Dir.glob(File.join(frameworks_dir, "*.framework")).each do |fw|
          sh("codesign --force --timestamp --options runtime --sign \"#{identity}\" \"#{fw}\"") rescue nil
        end
        Dir.glob(File.join(frameworks_dir, "*.dylib")).each do |dylib|
          sh("codesign --force --timestamp --options runtime --sign \"#{identity}\" \"#{dylib}\"") rescue nil
        end
      end

      ent_candidates = [
        options[:entitlements],
        File.join(File.dirname(file_path), "..", "build", "entitlements.mac.plist"),
        File.join(File.dirname(file_path), "entitlements.mac.plist"),
        File.join(File.dirname(file_path), "build", "entitlements.mac.plist")
      ].compact
      found_ent = ent_candidates.find { |e| File.exist?(e) }
      ent_flag = found_ent ? "--entitlements \"#{found_ent}\"" : ""

      sh("codesign --force --timestamp --options runtime #{ent_flag} --sign \"#{identity}\" \"#{file_path}\"")
      sh("codesign --verify --deep --strict --verbose=2 \"#{file_path}\"")
      UI.success("✅ Đã ký .app thành công!")
    elsif file_path.end_with?(".dmg")
      UI.message("✍️ Đang ký file DMG: #{file_path}")
      sh("codesign --force --timestamp --sign \"#{identity}\" \"#{file_path}\"")
      sh("codesign --verify --verbose=2 \"#{file_path}\"")
      UI.success("✅ Đã ký .dmg thành công!")
    elsif file_path.end_with?(".pkg")
      UI.message("✍️ Đang kiểm tra / ký file PKG...")
      identities_output = `security find-identity -v -p codesigning 2>/dev/null`
      installer_match = identities_output.match(/"(Developer ID Installer: [^"]+)"/)
      if installer_match
        signed_pkg = file_path.sub(/\.pkg$/, "_signed.pkg")
        sh("productsign --sign \"#{installer_match[1]}\" \"#{file_path}\" \"#{signed_pkg}\"")
        FileUtils.mv(signed_pkg, file_path)
        UI.success("✅ Đã ký .pkg bằng Developer ID Installer!")
      else
        UI.important("⚠️ Không tìm thấy Developer ID Installer trong Keychain. Bỏ qua productsign.")
      end
    else
      UI.user_error!("Định dạng file không được hỗ trợ để ký macOS (chỉ hỗ trợ .dmg, .app, .pkg)")
    end

    # 3. Apple Notarization & Staple
    should_notarize = options[:notarize] != false && options[:notarize] != "false"
    if should_notarize
      if file_path.end_with?(".dmg") || file_path.end_with?(".pkg")
        notarize_macos_artifact(file_path, options)
      elsif file_path.end_with?(".app")
        UI.message("📦 Đang nén .app thành .zip tạm thời để gửi Apple Notary Service...")
        zip_path = "#{file_path}.zip"
        sh("ditto -c -k --keepParent \"#{file_path}\" \"#{zip_path}\"")
        begin
          if notarize_macos_artifact(zip_path, options.merge(staple_target: file_path))
            sh("xcrun stapler staple \"#{file_path}\"") rescue nil
          end
        ensure
          FileUtils.rm_f(zip_path)
        end
      end

      # 4. Kiểm tra Gatekeeper
      UI.message("🔍 Kiểm tra trạng thái Gatekeeper sau công chứng...")
      if file_path.end_with?(".app")
        sh("spctl --assess --type execute --verbose \"#{file_path}\"") rescue nil
      elsif file_path.end_with?(".dmg")
        sh("spctl --assess --type open --context context:primary-signature --verbose \"#{file_path}\"") rescue nil
      end
    end

    UI.success("🎉 Hoàn tất quy trình ký và công chứng cho: #{File.basename(file_path)}")
    file_path
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
