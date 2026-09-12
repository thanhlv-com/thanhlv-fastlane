require 'json'
require 'fileutils'
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
  end
end unless defined?(FastlaneCore::UI)

UI = FastlaneCore::UI unless defined?(UI)

# Đọc danh sách apps từ apps.json ở thư mục fastlane/
def load_apps_config
  config_file = File.join(__dir__, "..", "apps.json")
  unless File.exist?(config_file)
    UI.user_error!("Không tìm thấy file #{config_file}")
  end
  JSON.parse(File.read(config_file))
end

# Lấy cấu hình của 1 app cụ thể theo app_key
def get_app_config(app_key)
  apps = load_apps_config
  if app_key.nil? || app_key.to_s.strip.empty?
    available_apps = apps.keys.join(", ")
    UI.user_error!("Vui lòng chỉ định app: app:<app_key>. Các app khả dụng: #{available_apps}")
  end

  app_info = apps[app_key.to_s]
  unless app_info
    available_apps = apps.keys.join(", ")
    UI.user_error!("Không tìm thấy cấu hình cho app '#{app_key}' trong apps.json. Các app khả dụng: #{available_apps}")
  end

  app_info
end

# Xác định bundle_id hoặc package_name theo platform
def resolve_bundle_id(app_info, platform = "ios", options = {})
  if options[:bundle_id] && !options[:bundle_id].empty?
    return options[:bundle_id]
  end
  if options[:package_name] && !options[:package_name].empty?
    return options[:package_name]
  end

  # Kiểm tra platform-specific override nếu có
  platform_key = platform.to_s.downcase
  if app_info["platforms_config"] && app_info["platforms_config"][platform_key]
    p_config = app_info["platforms_config"][platform_key]
    bundle_id = p_config["bundle_id"] || p_config["package_name"]
    return bundle_id if bundle_id && !bundle_id.empty?
  end

  if ["aos", "android"].include?(platform_key)
    app_info["package_name"] || app_info["bundle_id"]
  else
    app_info["bundle_id"] || app_info["package_name"]
  end
end

# Xác định flavor từ options hoặc apps.json
def resolve_flavor(app_info, options = {})
  raw_flavor = options[:flavor] || app_info["flavor"]
  (raw_flavor && !raw_flavor.to_s.strip.empty?) ? raw_flavor.to_s.strip : nil
end

# Xác định version (build_name) và build_number từ options hoặc apps.json
# Mặc định build_number lấy timestamp Unix Epoch theo giây (Time.now.to_i)
def resolve_version_and_build_number(app_info, options)
  raw_version = options[:version] || options[:build_name] || app_info["version"] || app_info["build_name"] || app_info["version_name"]
  raw_version = raw_version.to_s.strip if raw_version

  raw_build_number = options[:build_number] || app_info["build_number"]
  raw_build_number = raw_build_number.to_s.strip if raw_build_number

  version_name = nil
  build_num = raw_build_number

  if raw_version && !raw_version.empty?
    if raw_version.include?("+")
      parts = raw_version.split("+", 2)
      version_name = parts[0].strip
      build_num ||= parts[1].strip
    else
      version_name = raw_version
    end
  end

  # Mặc định lấy timestamp số giây từ 1970 đến giờ (Unix Epoch: Time.now.to_i)
  build_num = Time.now.to_i.to_s if build_num.nil? || build_num.empty? || build_num == "timestamp"

  [version_name, build_num]
end

# Xác định xem có bật làm rối mã nguồn (--obfuscate) hay không
# Ưu tiên: options[:obfuscate] -> ENV["OBFUSCATE"] -> app_info["obfuscate"] -> mặc định: true
def resolve_obfuscate(app_info, options = {})
  unless options[:obfuscate].nil?
    val = options[:obfuscate]
    return val == true || val.to_s.strip.downcase == "true" || val.to_s.strip == "1"
  end

  if ENV["OBFUSCATE"] && !ENV["OBFUSCATE"].to_s.strip.empty?
    val = ENV["OBFUSCATE"].to_s.strip.downcase
    return val == "true" || val == "1"
  end

  unless app_info["obfuscate"].nil?
    val = app_info["obfuscate"]
    return val == true || val.to_s.strip.downcase == "true" || val.to_s.strip == "1"
  end

  true
end

# Xác định đường dẫn thư mục lưu trữ debug symbols (--split-debug-info)
def resolve_split_debug_info_path(workspace_dir, platform = nil, options = {}, app_info = {})
  raw_path = options[:split_debug_info] || ENV["SPLIT_DEBUG_INFO"] || app_info["split_debug_info"]
  if raw_path && !raw_path.to_s.strip.empty?
    return raw_path.to_s.strip
  end

  if platform && !platform.to_s.strip.empty?
    "build/#{platform}/symbols"
  else
    "build/symbols"
  end
end

# Xây dựng danh sách tham số Flutter build liên quan đến obfuscation (--obfuscate và --split-debug-info)
def build_flutter_obfuscate_args(workspace_dir, platform, app_info, options = {})
  return [] unless resolve_obfuscate(app_info, options)

  symbols_dir = resolve_split_debug_info_path(workspace_dir, platform, options, app_info)
  full_symbols_path = File.expand_path(symbols_dir, workspace_dir)
  begin
    FileUtils.mkdir_p(full_symbols_path)
  rescue => e
    # Flutter CLI tự tạo thư mục khi build nếu chưa tồn tại
  end

  ["--obfuscate", "--split-debug-info=#{symbols_dir}"]
end

# Xác định cấu hình Export Compliance (ITSAppUsesNonExemptEncryption)
# Mặc định giải quyết cảnh báo "Missing Compliance" trên App Store Connect / TestFlight là:
# "None of the algorithms mentioned above" (chỉ sử dụng mã hoá miễn trừ/tiêu chuẩn như HTTPS/TLS/SSL -> false)
# Thứ tự ưu tiên: options[:uses_non_exempt_encryption] -> ENV["USES_NON_EXEMPT_ENCRYPTION"] -> app_info["uses_non_exempt_encryption"] -> false (mặc định)
def resolve_uses_non_exempt_encryption(app_info = {}, options = {})
  app_info ||= {}
  options ||= {}

  unless options[:uses_non_exempt_encryption].nil?
    val = options[:uses_non_exempt_encryption]
    return val == true || val.to_s.strip.downcase == "true" || val.to_s.strip == "1"
  end

  if ENV["USES_NON_EXEMPT_ENCRYPTION"] && !ENV["USES_NON_EXEMPT_ENCRYPTION"].to_s.strip.empty?
    val = ENV["USES_NON_EXEMPT_ENCRYPTION"].to_s.strip.downcase
    return val == "true" || val == "1"
  end

  unless app_info["uses_non_exempt_encryption"].nil?
    val = app_info["uses_non_exempt_encryption"]
    return val == true || val.to_s.strip.downcase == "true" || val.to_s.strip == "1"
  end

  # Mặc định: false ("None of the algorithms mentioned above")
  false
end

# Tự động cập nhật hoặc thêm ITSAppUsesNonExemptEncryption vào Info.plist
# để tự động giải quyết "Missing Compliance" trên App Store Connect & TestFlight
def configure_export_compliance!(workspace_dir, platform, app_info = {}, options = {})
  uses_non_exempt = resolve_uses_non_exempt_encryption(app_info, options)
  platform_name = normalize_platform_name(platform)

  candidate_plists = []
  case platform_name
  when "ios"
    runner_plist = File.join(workspace_dir, "ios", "Runner", "Info.plist")
    candidate_plists << runner_plist if File.exist?(runner_plist)

    ios_dir = File.join(workspace_dir, "ios")
    if File.directory?(ios_dir)
      Dir.glob(File.join(ios_dir, "**", "Info.plist")).each do |p|
        next if p.include?("/Pods/") || p.include?("/.symlinks/") || p.include?("/build/") || p.include?("/DerivedData/")
        candidate_plists << p
      end
    end
  when "macos"
    runner_plist = File.join(workspace_dir, "macos", "Runner", "Info.plist")
    candidate_plists << runner_plist if File.exist?(runner_plist)

    macos_dir = File.join(workspace_dir, "macos")
    if File.directory?(macos_dir)
      Dir.glob(File.join(macos_dir, "**", "Info.plist")).each do |p|
        next if p.include?("/Pods/") || p.include?("/.symlinks/") || p.include?("/build/") || p.include?("/DerivedData/")
        candidate_plists << p
      end
    end
  end

  candidate_plists = candidate_plists.uniq
  if candidate_plists.empty?
    UI.message("ℹ️ Không tìm thấy file Info.plist trong #{workspace_dir}/#{platform_name} để cấu hình Export Compliance.")
    return
  end

  compliance_label = uses_non_exempt ? "true" : "false ('None of the algorithms mentioned above')"
  candidate_plists.each do |plist_path|
    apply_plist_compliance(plist_path, uses_non_exempt)
    relative_path = plist_path.sub(workspace_dir.to_s, "").sub(%r{^/}, "")
    UI.success("🛡 Đã cấu hình Export Compliance (ITSAppUsesNonExemptEncryption = #{compliance_label}) tại #{relative_path}")
  end
end

# Áp dụng cấu hình ITSAppUsesNonExemptEncryption vào file plist
def apply_plist_compliance(plist_path, uses_non_exempt)
  val_str = uses_non_exempt ? "true" : "false"
  updated = false

  # 1. Thử dùng công cụ PlistBuddy có sẵn trên macOS
  if File.exist?("/usr/libexec/PlistBuddy")
    set_cmd = "/usr/libexec/PlistBuddy -c \"Set :ITSAppUsesNonExemptEncryption #{val_str}\" \"#{plist_path}\" 2>/dev/null"
    add_cmd = "/usr/libexec/PlistBuddy -c \"Add :ITSAppUsesNonExemptEncryption bool #{val_str}\" \"#{plist_path}\" 2>/dev/null"
    updated = system("#{set_cmd} || #{add_cmd}")
  end

  # 2. Xử lý dự phòng trực tiếp bằng XML text nếu PlistBuddy không khả dụng
  unless updated
    content = File.read(plist_path)
    val_tag = uses_non_exempt ? "<true/>" : "<false/>"
    if content =~ /<key>ITSAppUsesNonExemptEncryption<\/key>\s*<(true|false)\/>/
      new_content = content.sub(/<key>ITSAppUsesNonExemptEncryption<\/key>\s*<(true|false)\/>/, "<key>ITSAppUsesNonExemptEncryption</key>\n\t#{val_tag}")
      File.write(plist_path, new_content)
    elsif content =~ /<\/dict>/
      new_content = content.sub(/<\/dict>/, "\t<key>ITSAppUsesNonExemptEncryption</key>\n\t#{val_tag}\n</dict>")
      File.write(plist_path, new_content)
    end
  end
end

