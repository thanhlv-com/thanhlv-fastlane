# fastlane/helpers/git_workspace_helper.rb
# Helper quản lý tải và cập nhật mã nguồn ứng dụng vào thư mục .workspace

require 'fileutils'
require 'open3'
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

# Trả về đường dẫn gốc của thư mục .workspace
def workspace_root_path
  File.expand_path(File.join(__dir__, "..", "..", ".workspace"))
end

# Trả về đường dẫn thư mục làm việc của app cụ thể trong .workspace
def app_workspace_path(app_key)
  File.join(workspace_root_path, app_key.to_s)
end

# Chuẩn hoá tên nền tảng (platform)
def normalize_platform_name(platform)
  return "" if platform.nil?
  p = platform.to_s.downcase.strip
  case p
  when "android", "aos"
    "aos"
  when "mac", "macos", "osx"
    "macos"
  when "ios", "iphone", "ipad"
    "ios"
  when "windows", "win", "win32", "win64"
    "windows"
  when "linux", "ubuntu", "debian"
    "linux"
  else
    p
  end
end

# Kiểm tra ứng dụng có hỗ trợ nền tảng được yêu cầu hay không
def validate_platform_support!(app_key, app_info, target_platform)
  return true if target_platform.nil? || target_platform.to_s.empty?

  platforms = app_info["platforms"]
  if platforms.nil? || !platforms.is_a?(Array) || platforms.empty?
    # Nếu không khai báo platforms, mặc định cho phép chạy và thông báo nhắc nhở
    UI.message("ℹ️ Không tìm thấy danh sách 'platforms' trong cấu hình của '#{app_key}'. Cho phép tiếp tục...")
    return true
  end

  target_normalized = normalize_platform_name(target_platform)
  supported_normalized = platforms.map { |p| normalize_platform_name(p) }

  unless supported_normalized.include?(target_normalized)
    UI.user_error!("❌ App '#{app_key}' không hỗ trợ nền tảng '#{target_platform}'! Các nền tảng được cấu hình hỗ trợ: #{platforms.join(', ')}")
  end

  true
end

# Chuẩn bị workspace cho app: Clone hoặc Pull mã nguồn từ Git repo
def prepare_app_workspace(app_key, app_info, options = {}, target_platform = nil)
  validate_platform_support!(app_key, app_info, target_platform) if target_platform

  git_url = options[:git_url] || app_info["git_url"] || app_info["git"]
  git_branch = options[:branch] || options[:git_branch] || app_info["branch"] || app_info["git_branch"] || "main"
  skip_pull = options[:skip_pull] == true || options[:skip_pull] == "true" ||
              options[:skip_git] == true || options[:skip_git] == "true" ||
              options[:skip_git_pull] == true || options[:skip_git_pull] == "true"

  workspace_dir = app_workspace_path(app_key)
  FileUtils.mkdir_p(workspace_root_path)

  UI.message("📂 ========================================================")
  UI.message("📂 Quản lý Workspace cho: #{app_key}")
  UI.message("📂 Thư mục: #{workspace_dir}")
  UI.message("📂 Git URL: #{git_url || '(Chưa cấu hình Git URL)'}")
  UI.message("📂 Branch : #{git_branch}")
  UI.message("📂 ========================================================")

  git_dir = File.join(workspace_dir, ".git")

  if File.exist?(git_dir)
    # Repo đã tồn tại trong workspace
    if skip_pull
      UI.message("⏩ Bỏ qua bước git pull theo yêu cầu (skip_pull: true).")
    else
      UI.message("🔄 Đang cập nhật mã nguồn từ Git (fetch & pull branch #{git_branch})...")
      begin
        sh("git -C \"#{workspace_dir}\" fetch origin")
        sh("git -C \"#{workspace_dir}\" checkout \"#{git_branch}\"")
        sh("git -C \"#{workspace_dir}\" pull origin \"#{git_branch}\"")
        UI.success("✅ Cập nhật mã nguồn thành công tại: #{workspace_dir}")
      rescue => e
        UI.error("⚠️ Lỗi khi pull git: #{e.message}. Sẽ tiếp tục với mã nguồn hiện tại.")
      end
    end
  else
    # Repo chưa được clone
    if git_url.nil? || git_url.to_s.strip.empty?
      UI.user_error!("❌ Không tìm thấy 'git_url' trong cấu hình #{app_key} (apps.json) và thư mục workspace chưa tồn tại!")
    end

    UI.message("🌐 Đang clone repository #{git_url} (branch: #{git_branch}) vào workspace...")
    FileUtils.mkdir_p(workspace_dir)

    begin
      sh("git clone --branch \"#{git_branch}\" \"#{git_url}\" \"#{workspace_dir}\"")
    rescue => e
      UI.important("⚠️ Không thể clone với --branch #{git_branch}, thử clone mặc định...")
      sh("git clone \"#{git_url}\" \"#{workspace_dir}\"")
      sh("git -C \"#{workspace_dir}\" checkout \"#{git_branch}\"") rescue nil
    end

    UI.success("🎉 Clone mã nguồn thành công vào: #{workspace_dir}")
  end

  # Chạy flutter pub get nếu là dự án Flutter
  pubspec_file = File.join(workspace_dir, "pubspec.yaml")
  if File.exist?(pubspec_file) && (options[:skip_pub_get] != true && options[:skip_pub_get] != "true")
    UI.message("📦 Phát hiện dự án Flutter, đang chạy 'flutter pub get'...")
    run_flutter_cmd("flutter pub get", workspace_dir)
  end

  workspace_dir
end

# Thực thi lệnh Flutter trong thư mục workspace với môi trường sạch
def run_flutter_cmd(command, working_dir)
  unless system("which flutter > /dev/null 2>&1")
    UI.important("⚠️ Không tìm thấy lệnh 'flutter' trong PATH. Bỏ qua lệnh: #{command}")
    return false
  end

  clean_cmd = "env -u GEM_HOME -u GEM_PATH -u BUNDLE_BIN_PATH -u BUNDLE_GEMFILE -u RUBYOPT #{command}"
  full_cmd = "cd \"#{working_dir}\" && #{clean_cmd}"

  if defined?(Bundler)
    Bundler.with_unbundled_env do
      sh(full_cmd)
    end
  else
    sh(full_cmd)
  end
end
