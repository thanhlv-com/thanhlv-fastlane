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
