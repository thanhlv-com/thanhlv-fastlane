# fastlane/helpers/google_key_helper.rb
# Helper quản lý, mã hoá và giải mã Google Play Service Account JSON Key trên MATCH_GIT_URL
# Tương đồng với cơ chế lưu trữ và bảo mật của api_key_helper.rb (Apple Store Connect API Key)

require 'base64'
require 'fileutils'
require 'tmpdir'
require 'json'
begin
  require 'fastlane_core'
  require 'fastlane_core/ui/ui'
rescue LoadError
end

module FastlaneCore
  class UI
    def self.message(msg); puts msg; end
    def self.success(msg); puts msg; end
    def self.important(msg); puts msg; end
    def self.error(msg); puts msg; end
    def self.user_error!(msg); raise msg; end
    def self.password(msg)
      print "#{msg} "
      system('stty -echo') rescue nil
      pass = gets&.strip
      system('stty echo') rescue nil
      puts ""
      pass
    end
  end
end unless defined?(FastlaneCore::UI)

UI = FastlaneCore::UI unless defined?(UI)

# Tự động phát hiện file JSON Service Account Google Play trên máy local
def auto_detect_google_key_file
  # 1. Biến môi trường chỉ định rõ đường dẫn
  return File.expand_path(ENV["SUPPLY_JSON_KEY"]) if ENV["SUPPLY_JSON_KEY"] && File.exist?(File.expand_path(ENV["SUPPLY_JSON_KEY"]))
  return File.expand_path(ENV["GOOGLE_PLAY_KEY_FILE"]) if ENV["GOOGLE_PLAY_KEY_FILE"] && File.exist?(File.expand_path(ENV["GOOGLE_PLAY_KEY_FILE"]))

  fastlane_dir = File.expand_path(File.join(__dir__, ".."))
  root_dir = File.expand_path(File.join(fastlane_dir, ".."))

  # 2. Tìm theo pattern tên phổ biến trong fastlane/ và thư mục gốc
  search_patterns = [
    File.join(fastlane_dir, "{chplay-console*,google-play-key*,play-store*,pc-api*}*.json"),
    File.join(root_dir, "{chplay-console*,google-play-key*,play-store*,pc-api*}*.json")
  ]

  search_patterns.each do |pattern|
    matches = Dir.glob(pattern)
    return matches.first if matches.any?
  end

  # 3. Quét tất cả file .json trong fastlane/ (trừ apps.json) kiểm tra nội dung có phải Service Account Google không
  all_json = Dir.glob(File.join(fastlane_dir, "*.json")).reject { |f| File.basename(f) == "apps.json" }
  all_json.each do |f|
    begin
      content = File.read(f, 500) # Đọc 500 bytes đầu để kiểm tra
      return f if content && (content.include?("service_account") || content.include?("private_key"))
    rescue
      next
    end
  end

  nil
end

# Tải và giải mã Google Play Service Account JSON Key từ MATCH_GIT_URL trong bộ nhớ (không lưu ra ổ cứng)
def fetch_google_key_from_match_git(match_password, key_name = nil)
  git_url = ENV["MATCH_GIT_URL"] || "git@github.com:thanhlv-com/apple-certificates-keystore.git"
  git_branch = ENV["MATCH_GIT_BRANCH"] || "master"

  temp_dir = Dir.mktmpdir("fastlane_match_google_key_")

  begin
    UI.message("🌐 Đang tải Google Play Key từ MATCH_GIT_URL (#{git_url}, branch: #{git_branch})...")
    sh("git clone --depth 1 --branch #{git_branch} #{git_url} \"#{temp_dir}\"", log: false)

    search_dirs = [
      File.join(temp_dir, "api_keys"),
      File.join(temp_dir, "google_play_keys"),
      File.join(temp_dir, "google_keys")
    ].select { |d| Dir.exist?(d) }

    target_enc_file = nil
    target_plain_file = nil

    if key_name && !key_name.to_s.strip.empty?
      clean_name = key_name.to_s.strip.sub(/\.enc$/, '').sub(/\.json$/, '')
      search_dirs.each do |dir|
        candidates = [
          File.join(dir, "#{clean_name}.json.enc"),
          File.join(dir, "#{clean_name}.enc"),
          File.join(dir, "#{key_name}.enc"),
          File.join(dir, "#{key_name}"),
          File.join(dir, "#{clean_name}.json")
        ]
        found = candidates.find { |c| File.exist?(c) }
        if found
          if found.end_with?(".enc")
            target_enc_file = found
          else
            target_plain_file = found
          end
          break
        end
      end
    else
      # Tự động quét file trong các thư mục
      search_dirs.each do |dir|
        # Ưu tiên các file có đuôi .json.enc hoặc pattern chplay / google / play
        enc_files = Dir.glob(File.join(dir, "*.json.enc"))
        if enc_files.empty?
          enc_files = Dir.glob(File.join(dir, "{chplay*,google*,play*,pc-api*}*.enc"))
        end
        if enc_files.any?
          target_enc_file = enc_files.first
          break
        end

        plain_files = Dir.glob(File.join(dir, "{chplay*,google*,play*,pc-api*}*.json"))
        if plain_files.empty?
          plain_files = Dir.glob(File.join(dir, "*.json")).reject { |f| File.basename(f) == "apps.json" }
        end
        if plain_files.any?
          target_plain_file = plain_files.first
          break
        end
      end
    end

    if target_enc_file && File.exist?(target_enc_file)
      filename = File.basename(target_enc_file)
      UI.message("🔓 Đang giải mã #{filename} bằng MATCH_PASSWORD...")
      raw_decrypted = sh("openssl aes-256-cbc -d -pbkdf2 -in \"#{target_enc_file}\" -pass pass:\"#{match_password}\"", log: false)
      decrypted = raw_decrypted.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip

      # Kiểm tra tính hợp lệ của JSON sau khi giải mã
      begin
        JSON.parse(decrypted)
      rescue => e
        UI.user_error!("Giải mã file #{filename} thất bại hoặc MATCH_PASSWORD không chính xác! (#{e.message})")
      end

      return decrypted
    elsif target_plain_file && File.exist?(target_plain_file)
      filename = File.basename(target_plain_file)
      UI.important("⚠️ Cảnh báo: File #{filename} chưa được mã hoá trên Git repo!")
      return File.read(target_plain_file).strip
    else
      UI.user_error!("Không tìm thấy Google Play JSON key (.json.enc) trong thư mục api_keys/ của repo #{git_url}")
    end
  ensure
    FileUtils.remove_entry(temp_dir) if File.exist?(temp_dir)
  end
end

# Lấy thông tin xác thực Google Play (Hỗ trợ: SUPPLY_JSON_KEY_DATA trên CI, file JSON local, hoặc Match Git repo)
def get_google_play_key(options = {})
  key_content = ENV["SUPPLY_JSON_KEY_DATA"] || options[:json_key_data]
  key_path = ENV["SUPPLY_JSON_KEY"] || ENV["GOOGLE_PLAY_KEY_FILE"] || options[:json_key] || options[:filepath]
  match_password = ENV["MATCH_PASSWORD"]
  force_match = options[:from_git] == true || ENV["FORCE_MATCH_KEY"] == "true"

  # 1. Ưu tiên 1: Biến môi trường SUPPLY_JSON_KEY_DATA (trên CI/CD)
  if !force_match && key_content && !key_content.to_s.strip.empty?
    formatted_content = key_content.to_s.strip
    # Nếu là base64 (không bắt đầu bằng '{'), tự động decode
    if !formatted_content.start_with?("{")
      begin
        decoded = Base64.decode64(formatted_content)
        formatted_content = decoded if decoded.include?("{")
      rescue
      end
    end
    # Đảm bảo xoá key file khỏi ENV để Fastlane Supply không xung đột
    ENV.delete("SUPPLY_JSON_KEY")
    ENV.delete("GOOGLE_PLAY_KEY_FILE")
    ENV["SUPPLY_JSON_KEY_DATA"] = formatted_content
    return formatted_content
  end

  # 2. Ưu tiên 2: File JSON local (khi chạy local)
  local_file = key_path || auto_detect_google_key_file unless force_match
  if local_file && File.exist?(File.expand_path(local_file))
    expanded_path = File.expand_path(local_file)
    UI.message("🔑 Sử dụng local file Google Play Key: #{expanded_path}")
    content = File.read(expanded_path).strip
    ENV.delete("SUPPLY_JSON_KEY")
    ENV.delete("GOOGLE_PLAY_KEY_FILE")
    ENV["SUPPLY_JSON_KEY_DATA"] = content
    return content
  end

  # 3. Ưu tiên 3: Tải và giải mã từ MATCH_GIT_URL
  match_password ||= UI.password("Nhập MATCH_PASSWORD để giải mã Google Play Key từ MATCH_GIT_URL:") unless is_ci
  if match_password && !match_password.to_s.strip.empty?
    key_name = ENV["GOOGLE_PLAY_KEY_NAME"] || options[:key_name]
    decrypted_content = fetch_google_key_from_match_git(match_password, key_name)
    ENV.delete("SUPPLY_JSON_KEY")
    ENV.delete("GOOGLE_PLAY_KEY_FILE")
    ENV["SUPPLY_JSON_KEY_DATA"] = decrypted_content
    return decrypted_content
  else
    UI.user_error!("Không tìm thấy file JSON local và thiếu MATCH_PASSWORD để tải/giải mã Google Play Key từ MATCH_GIT_URL.")
  end
end

# Mã hoá và push Google Play Service Account JSON Key lên MATCH_GIT_URL
def push_google_key_to_git(options = {})
  key_path = options[:filepath] || options[:key_path] || ENV["SUPPLY_JSON_KEY"] || ENV["GOOGLE_PLAY_KEY_FILE"] || auto_detect_google_key_file
  
  unless key_path && File.exist?(File.expand_path(key_path))
    UI.user_error!("Không tìm thấy file Google Play JSON key! Vui lòng truyền filepath:<đường_dẫn_file.json> hoặc đặt file json trong thư mục fastlane/.")
  end

  expanded_path = File.expand_path(key_path)
  base_filename = File.basename(expanded_path)

  # Xác thực sơ bộ file JSON
  begin
    json_data = JSON.parse(File.read(expanded_path))
    unless json_data["type"] == "service_account" || json_data["private_key"]
      UI.important("⚠️ Cảnh báo: File #{base_filename} có vẻ không phải là Google Service Account Key tiêu chuẩn.")
    end
  rescue => e
    UI.user_error!("File #{base_filename} không phải định dạng JSON hợp lệ: #{e.message}")
  end

  # Xác định tên file mã hoá đích trong git repo
  key_name = options[:key_name] || ENV["GOOGLE_PLAY_KEY_NAME"]
  target_filename = if key_name && !key_name.to_s.strip.empty?
                      clean = key_name.to_s.strip.sub(/\.enc$/, '')
                      clean.end_with?(".json") ? "#{clean}.enc" : "#{clean}.json.enc"
                    else
                      "#{base_filename}.enc"
                    end

  git_url = ENV["MATCH_GIT_URL"] || "git@github.com:thanhlv-com/apple-certificates-keystore.git"
  git_branch = ENV["MATCH_GIT_BRANCH"] || "master"
  match_password = ENV["MATCH_PASSWORD"] || UI.password("Nhập MATCH_PASSWORD để mã hoá Google Play key:")

  if match_password.to_s.strip.empty?
    UI.user_error!("MATCH_PASSWORD không được để trống!")
  end

  temp_dir = Dir.mktmpdir("fastlane_push_google_key_")

  begin
    UI.message("🌐 Đang clone repo #{git_url} (branch: #{git_branch})...")
    sh("git clone --branch #{git_branch} #{git_url} \"#{temp_dir}\"")

    # Lưu trong thư mục api_keys/ (tương đồng tuyệt đối với AuthKey_*.p8.enc của Apple)
    api_keys_dir = File.join(temp_dir, "api_keys")
    FileUtils.mkdir_p(api_keys_dir)

    target_enc_file = File.join(api_keys_dir, target_filename)
    UI.message("🔐 Đang mã hoá file #{base_filename} -> api_keys/#{target_filename}...")
    sh("openssl aes-256-cbc -salt -pbkdf2 -in \"#{expanded_path}\" -out \"#{target_enc_file}\" -pass pass:\"#{match_password}\"", log: false)

    UI.message("🚀 Đang commit và push lên #{git_url}...")
    sh("cd \"#{temp_dir}\" && git config user.name \"Fastlane CI\" && git config user.email \"fastlane@thanhlv.com\"") rescue nil
    sh("cd \"#{temp_dir}\" && git add \"api_keys/#{target_filename}\" && git commit -m \"Add encrypted Google Play Console Key #{target_filename}\" && git push origin #{git_branch}")

    UI.success("🎉 Đã mã hoá và push thành công Google Play Key lên #{git_url} (thư mục api_keys/#{target_filename})!")
  ensure
    FileUtils.remove_entry(temp_dir) if File.exist?(temp_dir)
  end
end
