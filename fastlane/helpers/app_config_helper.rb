# fastlane/helpers/app_config_helper.rb
# Helper đọc cấu hình ứng dụng từ apps.json và xử lý versioning, bundle_id, flavor

require 'json'
require 'fastlane_core'
require 'fastlane_core/ui/ui'

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
