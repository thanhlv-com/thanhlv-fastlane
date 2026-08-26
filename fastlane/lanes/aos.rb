# fastlane/lanes/aos.rb
# Quản lý build & deploy cho nền tảng Android (AOS)

def build_aos_app(options)
  app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane aos build app:OpsFlow_Hub [type:apk|appbundle] [version:1.0.0] [build_number:1]")
  app_info = get_app_config(app_key)
  
  # 1. Tải hoặc cập nhật mã nguồn vào thư mục .workspace
  workspace_dir = prepare_app_workspace(app_key, app_info, options, "aos")

  package_name = resolve_bundle_id(app_info, "aos", options)
  flavor = resolve_flavor(app_info, options)
  version_name, build_number = resolve_version_and_build_number(app_info, options)
  
  build_type = (options[:type] || options[:target] || "apk").to_s.downcase
  build_type = "appbundle" if build_type == "aab" || build_type == "bundle"

  UI.message("🚀 ========================================================")
  UI.message("🚀 Bắt đầu build Android (AOS): #{app_info['app_name']} (#{package_name})")
  UI.message("🚀 Workspace: #{workspace_dir}")
  UI.message("🚀 Loại artifact (Type): #{build_type.upcase}")
  UI.message("🚀 Version (Build Name): #{version_name || 'Mặc định từ pubspec.yaml'}")
  UI.message("🚀 Build Number: #{build_number}")
  UI.message("🚀 Flavor: #{flavor && !flavor.empty? ? flavor : 'None'}")
  UI.message("🚀 ========================================================")

  # 2. Xây dựng tham số Flutter build
  build_args = []
  build_args << "--flavor #{flavor}" if flavor && !flavor.empty?
  build_args << "--build-name=#{version_name}" if version_name && !version_name.empty?
  build_args << "--build-number=#{build_number}" if build_number && !build_number.empty?

  flutter_cmd = "flutter build #{build_type} --release #{build_args.join(' ')}"
  UI.message("🛠 Đang compile Flutter Android trong workspace: #{flutter_cmd}")
  run_flutter_cmd(flutter_cmd, workspace_dir)

  # 3. Tìm file artifact đầu ra
  artifact_path = nil
  if build_type == "appbundle"
    possible_paths = Dir.glob(File.join(workspace_dir, "build/app/outputs/bundle/**/*.aab"))
    artifact_path = possible_paths.first
  else
    possible_paths = Dir.glob(File.join(workspace_dir, "build/app/outputs/flutter-apk/**/*.apk"))
    artifact_path = possible_paths.reject { |p| p.include?("intermediates") }.first || possible_paths.first
  end

  if artifact_path && File.exist?(artifact_path)
    UI.success("🎉 Build thành công Android #{build_type.upcase}: #{artifact_path}")
  else
    UI.important("⚠️ Không tìm thấy file artifact tự động. Hãy kiểm tra thư mục: #{File.join(workspace_dir, 'build/app/outputs')}")
  end

  artifact_path
end

def deploy_aos_app(options)
  app_key = options[:app] || UI.user_error!("Vui lòng chỉ định app: fastlane aos deploy app:OpsFlow_Hub [track:internal|alpha|beta|production] [version:1.0.0] [build_number:1]")
  track = options[:track] || "internal"

  app_info = get_app_config(app_key)
  validate_platform_support!(app_key, app_info, "aos")
  package_name = resolve_bundle_id(app_info, "aos", options)

  # 1. Build AAB (Android App Bundle)
  aab_file = build_aos_app(options.merge(type: "appbundle"))
  unless aab_file && File.exist?(aab_file)
    UI.user_error!("Không tìm thấy file AAB sau khi build để upload lên Google Play!")
  end

  # 2. Upload lên Google Play Store qua Fastlane Supply
  # Xoá các biến môi trường rỗng để tránh Fastlane Supply tự động kiểm tra verify_block với giá trị ''
  ENV.delete("SUPPLY_JSON_KEY") if ENV["SUPPLY_JSON_KEY"].to_s.strip.empty?
  ENV.delete("GOOGLE_PLAY_KEY_FILE") if ENV["GOOGLE_PLAY_KEY_FILE"].to_s.strip.empty?
  ENV.delete("SUPPLY_JSON_KEY_DATA") if ENV["SUPPLY_JSON_KEY_DATA"].to_s.strip.empty?

  json_key = ENV["SUPPLY_JSON_KEY"] || ENV["GOOGLE_PLAY_KEY_FILE"] || options[:json_key]
  json_key_data = ENV["SUPPLY_JSON_KEY_DATA"] || options[:json_key_data]

  # Nếu dùng json_key_data, đảm bảo xoá hẳn SUPPLY_JSON_KEY khỏi ENV để tránh Fastlane ưu tiên nhầm
  if json_key_data && !json_key_data.empty?
    ENV.delete("SUPPLY_JSON_KEY")
    ENV.delete("GOOGLE_PLAY_KEY_FILE")
  end

  UI.message("🚀 Đang upload AAB lên Google Play Console (Track: #{track}, Package: #{package_name})...")
  
  supply_args = {
    package_name: package_name,
    aab: aab_file,
    track: track,
    skip_upload_images: true,
    skip_upload_screenshots: true
  }
  supply_args[:json_key] = json_key if json_key && !json_key.empty?
  supply_args[:json_key_data] = json_key_data if json_key_data && !json_key_data.empty?

  upload_to_play_store(supply_args)
  UI.success("🎉 Phát hành thành công #{app_info['app_name']} (#{package_name}) lên Google Play Store track #{track}!")
end

# Hỗ trợ platform :aos
platform :aos do
  before_all do
    setup_ci if is_ci
  end

  desc "Build Android APK hoặc App Bundle (.aab) trong .workspace"
  lane :build do |options|
    build_aos_app(options)
  end

  desc "Build Android APK hoặc App Bundle (alias: build_aos)"
  lane :build_aos do |options|
    build_aos_app(options)
  end

  desc "Build Android App Bundle (.aab) và Deploy lên Google Play Console"
  lane :deploy do |options|
    deploy_aos_app(options)
  end
end

# Hỗ trợ platform :android (alias)
platform :android do
  before_all do
    setup_ci if is_ci
  end

  desc "Build Android APK hoặc App Bundle (.aab) trong .workspace"
  lane :build do |options|
    build_aos_app(options)
  end

  desc "Build Android APK hoặc App Bundle (alias: build_android)"
  lane :build_android do |options|
    build_aos_app(options)
  end

  desc "Build Android App Bundle (.aab) và Deploy lên Google Play Console"
  lane :deploy do |options|
    deploy_aos_app(options)
  end
end
