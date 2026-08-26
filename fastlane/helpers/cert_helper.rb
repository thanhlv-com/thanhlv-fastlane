# fastlane/helpers/cert_helper.rb
# Helper quản lý và dọn dẹp các Certificates & Provisioning Profiles cũ/hết hạn ở local

require 'openssl'
require 'time'
require 'open3'
require 'fileutils'
begin
  require 'fastlane_core'
  require 'fastlane_core/ui/ui'
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

# Tìm danh sách Keychain hợp lệ trên máy local
def find_local_keychains(custom_keychain = nil)
  keychains = []

  # 1. Custom keychain nếu được chỉ định
  if custom_keychain && !custom_keychain.to_s.strip.empty?
    expanded = File.expand_path(custom_keychain)
    keychains << expanded if File.exist?(expanded)
  end

  # 2. Biến môi trường
  [ENV["MATCH_KEYCHAIN_PATH"], ENV["KEYCHAIN_PATH"], ENV["MATCH_KEYCHAIN_NAME"]].compact.each do |kc|
    next if kc.to_s.strip.empty?
    expanded = File.expand_path(kc)
    keychains << expanded if File.exist?(expanded)
  end

  # 3. Lấy từ lệnh security list-keychains
  begin
    out, _err, status = Open3.capture3("security", "list-keychains")
    if status.success?
      out.scan(/"([^"]+)"/).flatten.each do |kc|
        keychains << kc if File.exist?(kc)
      end
    end
  rescue => e
    # Bỏ qua nếu lỗi
  end

  # 4. Các đường dẫn mặc định trên macOS
  default_paths = [
    File.expand_path("~/Library/Keychains/login.keychain-db"),
    File.expand_path("~/Library/Keychains/login.keychain"),
    File.expand_path("~/Library/Keychains/default.keychain-db"),
    File.expand_path("~/Library/Keychains/default.keychain")
  ]

  default_paths.each do |path|
    keychains << path if File.exist?(path)
  end

  keychains.uniq
end

# Kiểm tra xem chứng chỉ có phải là chứng chỉ liên quan đến Apple Developer / Distribution không
def apple_developer_certificate?(subject, issuer = "")
  keywords = [
    "Apple Development:",
    "Apple Distribution:",
    "iPhone Developer:",
    "iPhone Distribution:",
    "Mac Developer:",
    "3rd Party Mac Developer Application:",
    "3rd Party Mac Developer Installer:",
    "Developer ID Application:",
    "Developer ID Installer:",
    "Mac App Distribution:"
  ]
  keywords.any? { |kw| subject.to_s.include?(kw) }
end

# Quét và xoá certificates cũ / hết hạn trong macOS Keychain
def clean_expired_local_certificates(options = {})
  dry_run = options[:dry_run] == true || options[:dry_run] == "true"
  clean_all = options[:all] == true || options[:all] == "true"
  keychain_param = options[:keychain]
  
  keychains = find_local_keychains(keychain_param)
  if keychains.empty?
    UI.important("⚠️ Không tìm thấy Keychain khả dụng nào trên máy local để kiểm tra chứng chỉ.")
    return 0
  end

  deleted_count = 0
  scanned_count = 0

  UI.message("🔍 Đang quét certificates trong các Keychains:")
  keychains.each { |kc| UI.message("   📂 #{kc}") }

  keychains.each do |keychain_path|
    raw_certs, _err, status = Open3.capture3("security", "find-certificate", "-a", "-p", keychain_path)
    next unless status.success? && raw_certs && !raw_certs.strip.empty?

    certs_pem = raw_certs.scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m)
    
    certs_pem.each do |pem|
      begin
        cert = OpenSSL::X509::Certificate.new(pem)
        subject = cert.subject.to_s
        issuer = cert.issuer.to_s
        
        next unless apple_developer_certificate?(subject, issuer)
        scanned_count += 1

        is_expired = cert.not_after < Time.now
        sha1 = OpenSSL::Digest::SHA1.hexdigest(cert.to_der).upcase
        common_name = subject[/CN=([^,]+)/, 1] || subject

        # Điều kiện xoá: đã hết hạn HOẶC clean_all = true
        should_delete = is_expired || clean_all

        if should_delete
          status_tag = is_expired ? "🔴 [HẾT HẠN - #{cert.not_after}]" : "⚠️ [XOÁ THEO YÊU CẦU]"
          UI.message("🗑 #{status_tag} #{common_name} (SHA1: #{sha1})")

          if dry_run
            UI.message("   ℹ️ [DRY RUN] Bỏ qua thao tác xoá thực tế")
            deleted_count += 1
          else
            del_out, del_err, del_status = Open3.capture3("security", "delete-certificate", "-Z", sha1, "-t", keychain_path)
            if del_status.success?
              UI.success("   ✅ Đã xoá thành công khỏi #{File.basename(keychain_path)}")
              deleted_count += 1
            else
              # Thử lại không kèm flag -t
              del_out2, del_err2, del_status2 = Open3.capture3("security", "delete-certificate", "-Z", sha1, keychain_path)
              if del_status2.success?
                UI.success("   ✅ Đã xoá thành công khỏi #{File.basename(keychain_path)}")
                deleted_count += 1
              else
                err_msg = (del_err2 && !del_err2.empty?) ? del_err2.strip : del_out2.strip
                UI.error("   ❌ Không thể xoá certificate #{common_name}: #{err_msg}")
              end
            end
          end
        else
          UI.message("   🟢 [HỢP LỆ - Hết hạn: #{cert.not_after}] #{common_name}")
        end
      rescue => e
        # Bỏ qua cert không parse được
      end
    end
  end

  if deleted_count > 0
    action_text = dry_run ? "Tìm thấy (dry run)" : "Đã xoá"
    UI.success("🎉 #{action_text} tổng cộng #{deleted_count} certificate(s) Apple cũ/hết hạn trên máy local.")
  else
    UI.success("✨ Keychain sạch sẽ! Không tìm thấy certificate Apple nào bị hết hạn cần xoá (Đã quét: #{scanned_count} Apple certs).")
  end

  deleted_count
end

# Quét và xoá Provisioning Profiles cũ / hết hạn ở local
def clean_local_provisioning_profiles(options = {})
  dry_run = options[:dry_run] == true || options[:dry_run] == "true"
  clean_all = options[:all] == true || options[:all] == "true" || options[:force] == true || options[:force] == "true"
  
  profiles_dir = File.expand_path("~/Library/MobileDevice/Provisioning Profiles")
  
  unless Dir.exist?(profiles_dir)
    UI.message("ℹ️ Thư mục Provisioning Profiles không tồn tại hoặc rỗng (#{profiles_dir}).")
    return 0
  end

  profile_files = Dir.glob(File.join(profiles_dir, "*.{mobileprovision,provisionprofile}"))
  if profile_files.empty?
    UI.message("ℹ️ Không có Provisioning Profile nào trong #{profiles_dir}.")
    return 0
  end

  UI.message("🔍 Đang quét #{profile_files.length} file Provisioning Profile tại: #{profiles_dir}...")
  
  deleted_count = 0
  now = Time.now

  profile_files.each do |file_path|
    content = File.binread(file_path) rescue nil
    next unless content

    # Trích xuất XML Plist từ file provisioning profile
    name = nil
    uuid = nil
    exp_date = nil

    if content =~ /(<\?xml.*?<\/plist>)/m
      xml_plist = $1
      if xml_plist =~ /<key>Name<\/key>\s*<string>(.*?)<\/string>/m
        name = $1
      end
      if xml_plist =~ /<key>UUID<\/key>\s*<string>(.*?)<\/string>/m
        uuid = $1
      end
      if xml_plist =~ /<key>ExpirationDate<\/key>\s*<date>(.*?)<\/date>/m
        begin
          exp_date = Time.parse($1)
        rescue => e
        end
      end
    end

    file_name = File.basename(file_path)
    profile_display_name = name ? "#{name} (#{uuid || file_name})" : file_name
    is_expired = exp_date ? (exp_date < now) : false
    should_delete = is_expired || clean_all

    if should_delete
      status_tag = is_expired ? "🔴 [HẾT HẠN - #{exp_date}]" : "⚠️ [XOÁ THEO YÊU CẦU]"
      UI.message("🗑 #{status_tag} #{profile_display_name}")

      if dry_run
        UI.message("   ℹ️ [DRY RUN] Bỏ qua xoá file: #{file_name}")
        deleted_count += 1
      else
        begin
          File.delete(file_path)
          UI.success("   ✅ Đã xoá file: #{file_name}")
          deleted_count += 1
        rescue => e
          UI.error("   ❌ Lỗi khi xoá file #{file_name}: #{e.message}")
        end
      end
    end
  end

  if deleted_count > 0
    action_text = dry_run ? "Tìm thấy (dry run)" : "Đã xoá"
    UI.success("🎉 #{action_text} tổng cộng #{deleted_count} Provisioning Profile(s) cũ/hết hạn trên máy local.")
  else
    UI.success("✨ Thư mục Provisioning Profiles sạch sẽ! Không có profile nào bị hết hạn.")
  end

  deleted_count
end

# Hàm tổng hợp dọn dẹp cả certificates và profiles cũ ở local
def clean_old_local_certs(options = {})
  clean_profiles = options[:profiles] != false && options[:profiles] != "false"
  clean_certs = options[:certs] != false && options[:certs] != "false"

  UI.message("🧹 ========================================================")
  UI.message("🧹 Bắt đầu dọn dẹp Certificate & Profile cũ ở local")
  UI.message("🧹 Tùy chọn:")
  UI.message("🧹   - Expired Only: #{options[:all] ? 'Không (xoá tất cả)' : 'Có (chỉ xoá khi hết hạn)'}")
  UI.message("🧹   - Dry Run: #{options[:dry_run] ? 'BẬT (không xoá thật)' : 'TẮT'}")
  UI.message("🧹   - Dọn Certificates: #{clean_certs ? 'Có' : 'Không'}")
  UI.message("🧹   - Dọn Profiles: #{clean_profiles ? 'Có' : 'Không'}")
  UI.message("🧹 ========================================================")

  total_deleted_certs = 0
  total_deleted_profiles = 0

  if clean_certs
    total_deleted_certs = clean_expired_local_certificates(options)
  end

  if clean_profiles
    total_deleted_profiles = clean_local_provisioning_profiles(options)
  end

  UI.message("🏁 ========================================================")
  UI.success("🏁 Hoàn tất dọn dẹp local! (Certs đã xoá: #{total_deleted_certs}, Profiles đã xoá: #{total_deleted_profiles})")
  UI.message("🏁 ========================================================")
end
