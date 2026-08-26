#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

ROOT_DIR = File.expand_path("..", __dir__)
APPS_JSON_PATH = File.join(ROOT_DIR, "fastlane", "apps.json")
WORKFLOWS_DIR = File.join(ROOT_DIR, ".github", "workflows")

unless File.exist?(APPS_JSON_PATH)
  puts "❌ Không tìm thấy file apps.json tại: #{APPS_JSON_PATH}"
  exit 1
end

begin
  apps_data = JSON.parse(File.read(APPS_JSON_PATH))
rescue StandardError => e
  puts "❌ Lỗi khi đọc file JSON #{APPS_JSON_PATH}: #{e.message}"
  exit 1
end

def normalize_platform(platform)
  return "" if platform.nil?
  p = platform.to_s.downcase.strip
  case p
  when "android", "aos"
    "aos"
  when "mac", "macos", "osx"
    "macos"
  when "ios", "iphone", "ipad"
    "ios"
  else
    p
  end
end

def filter_apps_by_platform(apps_data, target_platform)
  target_norm = normalize_platform(target_platform)
  matching = []

  apps_data.each do |app_key, app_info|
    platforms = app_info["platforms"]
    if platforms.nil? || !platforms.is_a?(Array) || platforms.empty?
      # Mặc định hỗ trợ tất cả nếu không khai báo
      matching << app_key
    else
      normalized_platforms = platforms.map { |p| normalize_platform(p) }
      matching << app_key if normalized_platforms.include?(target_norm)
    end
  end

  matching
end

# Lọc danh sách app theo từng nền tảng
ios_apps = filter_apps_by_platform(apps_data, "ios")
macos_apps = filter_apps_by_platform(apps_data, "macos")
aos_apps = filter_apps_by_platform(apps_data, "aos")
apple_apps = (ios_apps + macos_apps).uniq

puts "=================================================="
puts "🔍 KẾT QUẢ QUÉT APPS TRONG #{File.basename(APPS_JSON_PATH)}:"
puts "   📱 iOS Apps   (#{ios_apps.length})   : #{ios_apps.join(', ')}"
puts "   💻 macOS Apps (#{macos_apps.length}) : #{macos_apps.join(', ')}"
puts "   🤖 AOS Apps   (#{aos_apps.length})   : #{aos_apps.join(', ')}"
puts "   🍎 Apple Apps (#{apple_apps.length}) : #{apple_apps.join(', ')}"
puts "=================================================="

# Hàm cập nhật block inputs.app trong file workflow
def update_workflow_app_input(file_path, supported_apps, default_choice = "all", is_required = true)
  unless File.exist?(file_path)
    puts "⚠️ Không tìm thấy file workflow: #{file_path}"
    return
  end

  content = File.read(file_path)

  # Tạo danh sách options: ['all'] + supported_apps
  options_list = (["all"] + supported_apps).uniq
  default_val = options_list.include?(default_choice) ? default_choice : (options_list.first || "all")

  new_app_lines = [
    "      app:",
    "        description: \"Chọn App Key trong apps.json (hoặc 'all' để áp dụng toàn bộ)\"",
    "        required: #{is_required}",
    "        default: \"#{default_val}\"",
    "        type: choice",
    "        options:",
    *options_list.map { |opt| "          - \"#{opt}\"" }
  ]
  new_app_block = new_app_lines.join("\n")

  # Regex tìm khối input `app:` chuẩn xác (6 space cho app: và 8+ space cho các thuộc tính con)
  pattern = /^[ \t]*app:\n(?:[ \t]+[^\n]+\n)+?(?=[ \t]{6}[a-zA-Z0-9_-]+:|^[a-zA-Z0-9_-]+:|$)/m

  if content.match?(pattern)
    updated_content = content.sub(pattern, "#{new_app_block}\n")
    File.write(file_path, updated_content)
    puts "✅ Đã cập nhật thành công: #{File.basename(file_path)} (#{options_list.length} options: #{options_list.join(', ')})"
  else
    puts "⚠️ Không tìm thấy vị trí input `app:` phù hợp trong #{File.basename(file_path)}"
  end
end

# Cập nhật các file workflow
update_workflow_app_input(File.join(WORKFLOWS_DIR, "deploy-ios-fastlane.yml"), ios_apps, "all", true)
update_workflow_app_input(File.join(WORKFLOWS_DIR, "deploy-macos-fastlane.yml"), macos_apps, "all", true)
update_workflow_app_input(File.join(WORKFLOWS_DIR, "deploy-aos-fastlane.yml"), aos_apps, "all", true)
update_workflow_app_input(File.join(WORKFLOWS_DIR, "sync-certs-fastlane.yml"), apple_apps, "all", false)

puts "🎉 Hoàn tất tự động cập nhật Type Choice cho tất cả GitHub Actions Workflows!"
