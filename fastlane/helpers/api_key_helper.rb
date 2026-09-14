# fastlane/helpers/api_key_helper.rb
# Helper quản lý và xác thực App Store Connect API Key

require 'base64'
require 'fileutils'
require 'tmpdir'
require 'fastlane_core'
require 'fastlane_core/ui/ui'

UI = FastlaneCore::UI unless defined?(UI)

# Tự động phát hiện Key ID từ biến môi trường hoặc file local .p8
def auto_detect_key_id
  return ENV["ASC_KEY_ID"] if ENV["ASC_KEY_ID"] && !ENV["ASC_KEY_ID"].empty?

  local_keys = Dir.glob(File.join(__dir__, "..", "api_keys", "AuthKey_*.p8*")) +
               Dir.glob(File.join(__dir__, "..", "AuthKey_*.p8*"))
  if local_keys.any?
    filename = File.basename(local_keys.first)
    match = filename.match(/AuthKey_([A-Z0-9]+)\.p8/)
    return match[1] if match
  end

  "FMTTSQML5M"
end

# Tải và giải mã API Key từ MATCH_GIT_URL trong bộ nhớ (không lưu file ra ổ cứng)
def fetch_key_from_match_git(key_id, match_password)
  git_url = ENV["MATCH_GIT_URL"] || "git@github.com:thanhlv-com/apple-certificates-keystore.git"
  git_branch = ENV["MATCH_GIT_BRANCH"] || "master"

  temp_dir = Dir.mktmpdir("fastlane_match_key_")

  begin
    UI.message("🌐 Đang tải API Key từ MATCH_GIT_URL (#{git_url}, branch: #{git_branch})...")
    sh("git clone --depth 1 --branch #{git_branch} #{git_url} \"#{temp_dir}\"", log: false)

    enc_key_file = File.join(temp_dir, "api_keys", "AuthKey_#{key_id}.p8.enc")
    plain_key_file = File.join(temp_dir, "api_keys", "AuthKey_#{key_id}.p8")

    if File.exist?(enc_key_file)
      UI.message("🔓 Đang giải mã AuthKey_#{key_id}.p8.enc bằng MATCH_PASSWORD...")
      raw_decrypted = sh("openssl aes-256-cbc -d -pbkdf2 -in \"#{enc_key_file}\" -pass pass:\"#{match_password}\"", log: false)
      decrypted = raw_decrypted.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
      return decrypted
    elsif File.exist?(plain_key_file)
      UI.important("⚠️ Cảnh báo: File AuthKey_#{key_id}.p8 chưa được mã hoá trên Git repo!")
      return File.read(plain_key_file).strip
    else
      UI.user_error!("Không tìm thấy AuthKey_#{key_id}.p8.enc trong thư mục api_keys/ của repo #{git_url}")
    end
  ensure
    FileUtils.remove_entry(temp_dir) if File.exist?(temp_dir)
  end
end

# Khởi tạo App Store Connect API Key (Hỗ trợ: ASC_KEY_CONTENT trên CI, File .p8 local, hoặc Match Git repo)
def get_api_key
  key_id = auto_detect_key_id
  issuer_id = ENV["ASC_ISSUER_ID"]
  key_path = ENV["ASC_KEY_PATH"]
  key_content = ENV["ASC_KEY_CONTENT"]
  match_password = ENV["MATCH_PASSWORD"]

  unless issuer_id && !issuer_id.empty?
    UI.user_error!("Thiếu biến môi trường ASC_ISSUER_ID. Vui lòng khai báo ASC_ISSUER_ID.")
  end

  # 1. Ưu tiên 1: Biến môi trường ASC_KEY_CONTENT (trên CI/CD)
  if key_content && !key_content.strip.empty?
    formatted_content = key_content.include?("BEGIN PRIVATE KEY") ? key_content : Base64.decode64(key_content)
    return app_store_connect_api_key(
      key_id: key_id,
      issuer_id: issuer_id,
      key_content: formatted_content,
      in_house: false
    )
  end

  # 2. Ưu tiên 2: File .p8 local (khi chạy local)
  local_candidates = [
    key_path,
    File.join(__dir__, "..", "api_keys", "AuthKey_#{key_id}.p8"),
    File.join(__dir__, "..", "AuthKey_#{key_id}.p8")
  ].compact.map { |f| File.expand_path(f) }
  local_key_file = local_candidates.find { |f| File.file?(f) }

  if local_key_file
    UI.message("🔑 Sử dụng local file API Key: #{local_key_file}")
    return app_store_connect_api_key(
      key_id: key_id,
      issuer_id: issuer_id,
      key_filepath: local_key_file,
      in_house: false
    )
  end

  # 3. Ưu tiên 3: Tải và giải mã từ MATCH_GIT_URL
  match_password ||= UI.password("Nhập MATCH_PASSWORD để giải mã API Key từ MATCH_GIT_URL:") unless is_ci
  if match_password && !match_password.empty?
    decrypted_content = fetch_key_from_match_git(key_id, match_password)
    return app_store_connect_api_key(
      key_id: key_id,
      issuer_id: issuer_id,
      key_content: decrypted_content,
      in_house: false
    )
  else
    UI.user_error!("Không tìm thấy file .p8 local và thiếu MATCH_PASSWORD để tải/giải mã API Key từ MATCH_GIT_URL.")
  end
end

# Mã hoá và push App Store Connect API Key lên MATCH_GIT_URL
def push_api_key_to_git(options = {})
  clean_str = ->(v) { (v.nil? || v.to_s.strip.empty?) ? nil : v.to_s.strip }
  key_id = clean_str.call(options[:key_id]) || auto_detect_key_id
  raw_path = clean_str.call(options[:filepath]) || clean_str.call(options[:key_path]) || clean_str.call(ENV["ASC_KEY_PATH"])

  candidates = [
    raw_path,
    File.join(__dir__, "..", "api_keys", "AuthKey_#{key_id}.p8"),
    File.join(__dir__, "..", "AuthKey_#{key_id}.p8")
  ].compact.map { |f| File.expand_path(f) }
  key_path = candidates.find { |f| File.file?(f) }

  unless key_path
    UI.user_error!("Không tìm thấy file key tại: #{raw_path || 'fastlane/api_keys/AuthKey_' + key_id.to_s + '.p8'}")
  end

  temp_dir = Dir.mktmpdir("fastlane_push_key_")

  begin
    UI.message("🌐 Đang clone repo #{git_url} (branch: #{git_branch})...")
    sh("git clone --branch #{git_branch} #{git_url} \"#{temp_dir}\"")

    api_keys_dir = File.join(temp_dir, "api_keys")
    FileUtils.mkdir_p(api_keys_dir)

    target_enc_file = File.join(api_keys_dir, "AuthKey_#{key_id}.p8.enc")
    UI.message("🔐 Đang mã hoá file #{key_path} -> #{target_enc_file}...")
    sh("openssl aes-256-cbc -salt -pbkdf2 -in \"#{File.expand_path(key_path)}\" -out \"#{target_enc_file}\" -pass pass:\"#{match_password}\"", log: false)

    UI.message("🚀 Đang commit và push lên #{git_url}...")
    sh("cd \"#{temp_dir}\" && git config user.name \"Fastlane CI\" && git config user.email \"fastlane@thanhlv.com\"") rescue nil
    sh("cd \"#{temp_dir}\" && git add api_keys/AuthKey_#{key_id}.p8.enc && git commit -m \"Add encrypted App Store Connect API Key for #{key_id}\" && git push origin #{git_branch}")

    UI.success("🎉 Đã mã hoá và push thành công API Key lên #{git_url} (thư mục api_keys/)!")
  ensure
    FileUtils.remove_entry(temp_dir) if File.exist?(temp_dir)
  end
end

# Tải và giải mã App Store Connect API Key từ MATCH_GIT_URL về thư mục fastlane/api_keys
def pull_api_key_from_git(options = {})
  clean_str = ->(v) { (v.nil? || v.to_s.strip.empty?) ? nil : v.to_s.strip }
  requested_key_id = clean_str.call(options[:key_id]) || clean_str.call(ENV["ASC_KEY_ID"])
  git_url = ENV["MATCH_GIT_URL"] || "git@github.com:thanhlv-com/apple-certificates-keystore.git"
  git_branch = ENV["MATCH_GIT_BRANCH"] || "master"
  match_password = clean_str.call(ENV["MATCH_PASSWORD"]) || UI.password("Nhập MATCH_PASSWORD để giải mã API Key:")

  dest_dir = File.expand_path(File.join(__dir__, "..", "api_keys"))
  FileUtils.mkdir_p(dest_dir)

  temp_dir = Dir.mktmpdir("fastlane_pull_apple_key_")

  begin
    UI.message("🌐 Đang clone repo #{git_url} (branch: #{git_branch})...")
    sh("git clone --depth 1 --branch #{git_branch} #{git_url} \"#{temp_dir}\"", log: false)

    api_keys_dir = File.join(temp_dir, "api_keys")
    unless Dir.exist?(api_keys_dir)
      UI.user_error!("Không tìm thấy thư mục api_keys/ trong repo #{git_url}")
    end

    # Tìm các file key
    candidates = if requested_key_id
                   [
                     File.join(api_keys_dir, "AuthKey_#{requested_key_id}.p8.enc"),
                     File.join(api_keys_dir, "AuthKey_#{requested_key_id}.p8")
                   ].select { |f| File.exist?(f) }
                 else
                   Dir.glob(File.join(api_keys_dir, "AuthKey_*.p8*"))
                 end

    if candidates.empty?
      target_desc = requested_key_id ? "cho Key ID #{requested_key_id}" : ""
      UI.user_error!("Không tìm thấy file AuthKey_*.p8.enc nào #{target_desc} trong thư mục api_keys/ của repo #{git_url}")
    end

    saved_files = []
    candidates.each do |key_file|
      base = File.basename(key_file)
      match = base.match(/AuthKey_([A-Z0-9]+)\.p8/)
      key_id = match ? match[1] : base.sub(/\.enc$/, '')
      dest_filename = "AuthKey_#{key_id}.p8"
      dest_file = File.join(dest_dir, dest_filename)

      content = if key_file.end_with?(".enc")
                  UI.message("🔓 Đang giải mã #{base} bằng MATCH_PASSWORD...")
                  raw_decrypted = sh("openssl aes-256-cbc -d -pbkdf2 -in \"#{key_file}\" -pass pass:\"#{match_password}\"", log: false)
                  raw_decrypted.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
                else
                  UI.important("⚠️ File #{base} không được mã hoá trên Git repo!")
                  File.read(key_file).strip
                end

      unless content.include?("BEGIN PRIVATE KEY") || content.include?("BEGIN EC PRIVATE KEY")
        UI.user_error!("Giải mã #{base} thất bại hoặc MATCH_PASSWORD không chính xác!")
      end

      File.write(dest_file, content + "\n")
      File.chmod(0600, dest_file) rescue nil
      saved_files << dest_file
      UI.success("✔ Đã lưu và giải mã thành công: #{dest_file}")
    end

    UI.success("🎉 Hoàn tất tải #{saved_files.length} Apple API Key về: #{dest_dir}")
    saved_files
  ensure
    FileUtils.remove_entry(temp_dir) if File.exist?(temp_dir)
  end
end
