#!/usr/bin/env ruby
# frozen_string_literal: true

# scripts/sync_workspace_code.rb
# Tự động clone hoặc pull mã nguồn mới nhất của các ứng dụng từ fastlane/apps.json
# về thư mục .workspace_code

require 'json'
require 'fileutils'

# ANSI Color formatting
module Colors
  CYAN    = "\e[36m"
  GREEN   = "\e[32m"
  YELLOW  = "\e[33m"
  RED     = "\e[31m"
  BLUE    = "\e[34m"
  MAGENTA = "\e[35m"
  RESET   = "\e[0m"
  BOLD    = "\e[1m"
  DIM     = "\e[2m"
end

class WorkspaceCodeSync
  include Colors

  ROOT_DIR = File.expand_path("..", __dir__)
  APPS_JSON_PATH = File.join(ROOT_DIR, "fastlane", "apps.json")
  WORKSPACE_CODE_DIR = File.join(ROOT_DIR, ".workspace_code")

  def initialize
    @apps_data = load_apps_data
    @target_app = resolve_target_app
    @target_branch = resolve_target_branch
  end

  def run
    print_banner
    FileUtils.mkdir_p(WORKSPACE_CODE_DIR)

    apps_to_sync = filter_apps
    if apps_to_sync.empty?
      puts "#{YELLOW}⚠️ Không tìm thấy ứng dụng nào phù hợp để đồng bộ!#{RESET}"
      exit 0
    end

    puts "#{BOLD}🚀 Bắt đầu đồng bộ #{apps_to_sync.size} ứng dụng vào:#{RESET} #{CYAN}#{WORKSPACE_CODE_DIR}#{RESET}\n"

    success_list = []
    failed_list = []
    skipped_list = []

    apps_to_sync.each_with_index do |(app_key, app_info), index|
      puts "#{BOLD}----------------------------------------------------------------------#{RESET}"
      puts "#{BOLD}[#{index + 1}/#{apps_to_sync.size}] 📱 Ứng dụng:#{RESET} #{CYAN}#{app_key}#{RESET} #{DIM}(#{app_info['app_name'] || 'N/A'})#{RESET}"

      git_url = (app_info["git_url"] || app_info["git"]).to_s.strip
      if git_url.empty?
        puts "  #{YELLOW}⚠️ Bỏ qua: Không tìm thấy 'git_url' trong apps.json#{RESET}"
        skipped_list << { key: app_key, reason: "Thiếu git_url" }
        next
      end

      branch = @target_branch || app_info["branch"] || app_info["git_branch"] || "main"
      target_dir = resolve_target_dir(app_key, git_url)

      result = sync_repo(app_key, git_url, branch, target_dir)
      if result[:status] == :success
        success_list << { key: app_key, action: result[:action], dir: target_dir }
      else
        failed_list << { key: app_key, error: result[:error], dir: target_dir }
      end
    end

    print_summary(apps_to_sync.size, success_list, failed_list, skipped_list)

    exit(failed_list.empty? ? 0 : 1)
  end

  private

  def load_apps_data
    unless File.exist?(APPS_JSON_PATH)
      puts "#{RED}❌ Không tìm thấy file cấu hình: #{APPS_JSON_PATH}#{RESET}"
      exit 1
    end

    JSON.parse(File.read(APPS_JSON_PATH))
  rescue StandardError => e
    puts "#{RED}❌ Lỗi khi đọc file fastlane/apps.json: #{e.message}#{RESET}"
    exit 1
  end

  def resolve_target_app
    arg = (ENV['APP'] && !ENV['APP'].strip.empty?) ? ENV['APP'].strip : ARGV[0]
    return nil if arg.nil? || arg.strip.empty? || arg.strip.downcase == 'all'
    arg.strip
  end

  def resolve_target_branch
    branch = (ENV['BRANCH'] && !ENV['BRANCH'].strip.empty?) ? ENV['BRANCH'].strip : nil
    branch ||= (ENV['REF'] && !ENV['REF'].strip.empty?) ? ENV['REF'].strip : nil
    branch ||= (ARGV[1] && !ARGV[1].strip.empty?) ? ARGV[1].strip : nil
    branch
  end

  def filter_apps
    return @apps_data if @target_app.nil?

    # Tìm chính xác theo app_key
    if @apps_data.key?(@target_app)
      return { @target_app => @apps_data[@target_app] }
    end

    # Tìm tương đương (không phân biệt hoa thường, hoặc gạch dưới / gạch ngang)
    normalized_target = @target_app.downcase.tr('_-', '')
    match_key = @apps_data.keys.find do |k|
      k.downcase.tr('_-', '') == normalized_target
    end

    if match_key
      return { match_key => @apps_data[match_key] }
    end

    # Tìm theo tên repo trong git_url
    match_by_repo = @apps_data.find do |_, info|
      git_url = (info["git_url"] || "").strip
      repo_name = File.basename(git_url, ".git").downcase.tr('_-', '')
      repo_name == normalized_target
    end

    if match_by_repo
      return { match_by_repo[0] => match_by_repo[1] }
    end

    puts "#{RED}❌ Không tìm thấy app '#{@target_app}' trong fastlane/apps.json!#{RESET}"
    puts "#{YELLOW}💡 Các app khả dụng: #{@apps_data.keys.join(', ')}#{RESET}"
    exit 1
  end

  def resolve_target_dir(app_key, git_url)
    repo_name = File.basename(git_url, ".git").strip
    candidate_key = File.join(WORKSPACE_CODE_DIR, app_key)
    candidate_repo = File.join(WORKSPACE_CODE_DIR, repo_name)

    # Ưu tiên 1: Thư mục theo app_key nếu đã tồn tại
    return candidate_key if File.directory?(candidate_key)

    # Ưu tiên 2: Thư mục theo tên repo nếu đã tồn tại sẵn
    return candidate_repo if File.directory?(candidate_repo)

    # Nếu chưa tồn tại: Mặc định dùng app_key
    candidate_key
  end

  def sync_repo(app_key, git_url, branch, target_dir)
    git_dir = File.join(target_dir, ".git")

    if File.directory?(git_dir)
      # ========================================================================
      # REPO ĐÃ TỒN TẠI -> PULL CẬP NHẬT MÃ NGUỒN MỚI
      # ========================================================================
      puts "  #{BLUE}📂 Thư mục:#{RESET} #{target_dir}"
      puts "  #{BLUE}🌿 Nhánh:#{RESET}   #{branch}"

      # Kiểm tra thay đổi chưa commit
      status_output = `git -C "#{target_dir}" status --porcelain 2>/dev/null`.strip
      unless status_output.empty?
        puts "  #{YELLOW}⚠️  Lưu ý: Có thay đổi chưa commit trong working directory:#{RESET}"
        status_output.lines.take(3).each { |line| puts "     #{DIM}#{line.strip}#{RESET}" }
        puts "     #{DIM}...#{RESET}" if status_output.lines.size > 3
      end

      puts "  #{CYAN}🔄 Đang fetch và pull code mới từ origin/#{branch}...#{RESET}"
      
      fetch_ok = system("git -C \"#{target_dir}\" fetch origin 2>&1")
      unless fetch_ok
        puts "  #{RED}✖ Lỗi khi fetch từ origin remote!#{RESET}"
        return { status: :failed, error: "git fetch origin failed" }
      end

      # Chuyển nhánh nếu cần
      current_branch = `git -C "#{target_dir}" rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
      if current_branch != branch
        puts "  #{YELLOW}🔀 Đang chuyển từ nhánh '#{current_branch}' sang '#{branch}'...#{RESET}"
        checkout_ok = system("git -C \"#{target_dir}\" checkout \"#{branch}\" 2>&1")
        unless checkout_ok
          # Thử checkout tạo nhánh theo dõi origin/<branch> nếu local chưa có
          system("git -C \"#{target_dir}\" checkout -B \"#{branch}\" \"origin/#{branch}\" 2>&1")
        end
      end

      # Pull code mới
      pull_ok = system("git -C \"#{target_dir}\" pull origin \"#{branch}\" 2>&1")
      if pull_ok
        puts "  #{GREEN}✔ Đã cập nhật thành công mã nguồn mới nhất!#{RESET}"
        { status: :success, action: :pulled }
      else
        puts "  #{RED}✖ Lỗi khi git pull (có thể do conflict hoặc uncommitted changes).#{RESET}"
        { status: :failed, error: "git pull origin #{branch} failed" }
      end

    else
      # ========================================================================
      # REPO CHƯA TỒN TẠI -> CLONE MỚI
      # ========================================================================
      puts "  #{BLUE}🌐 Git URL:#{RESET} #{git_url}"
      puts "  #{BLUE}🌿 Nhánh:  #{RESET} #{branch}"
      puts "  #{BLUE}📂 Đích:   #{RESET} #{target_dir}"
      puts "  #{CYAN}⬇️  Đang clone mã nguồn về .workspace_code...#{RESET}"

      FileUtils.mkdir_p(File.dirname(target_dir))

      clone_cmd = "git clone --branch \"#{branch}\" \"#{git_url}\" \"#{target_dir}\""
      clone_ok = system(clone_cmd)

      unless clone_ok
        puts "  #{YELLOW}⚠️  Clone với --branch #{branch} không thành công, thử clone mặc định...#{RESET}"
        clone_fallback_ok = system("git clone \"#{git_url}\" \"#{target_dir}\"")
        if clone_fallback_ok
          system("git -C \"#{target_dir}\" checkout \"#{branch}\" 2>/dev/null")
          clone_ok = true
        end
      end

      if clone_ok && File.directory?(git_dir)
        puts "  #{GREEN}✔ Đã clone thành công mã nguồn về #{target_dir}!#{RESET}"
        { status: :success, action: :cloned }
      else
        puts "  #{RED}✖ Lỗi khi clone mã nguồn từ #{git_url}!#{RESET}"
        { status: :failed, error: "git clone failed" }
      end
    end
  end

  def print_banner
    puts ""
    puts "#{BOLD}#{CYAN}====================================================================#{RESET}"
    puts "#{BOLD}#{CYAN}       ĐỒNG BỘ MÃ NGUỒN CÁC DỰ ÁN VỀ .WORKSPACE_CODE               #{RESET}"
    puts "#{BOLD}#{CYAN}====================================================================#{RESET}"
    puts "#{DIM}  Nguồn danh sách: #{APPS_JSON_PATH}#{RESET}"
    puts "#{DIM}  Thư mục đích   : #{WORKSPACE_CODE_DIR}#{RESET}"
    puts ""
  end

  def print_summary(total, success_list, failed_list, skipped_list)
    puts "\n#{BOLD}====================================================================#{RESET}"
    puts "#{BOLD}📊 TỔNG KẾT TIẾN TRÌNH ĐỒNG BỘ MÃ NGUỒN:#{RESET}"
    puts "   Tổng số apps xử lý: #{BOLD}#{total}#{RESET}"
    puts "   #{GREEN}✔ Thành công       : #{success_list.size}#{RESET}"
    puts "   #{RED}✖ Thất bại         : #{failed_list.size}#{RESET}"
    puts "   #{YELLOW}⚠️ Bỏ qua          : #{skipped_list.size}#{RESET}"
    puts "#{BOLD}====================================================================#{RESET}"

    unless success_list.empty?
      puts "\n#{GREEN}✨ Danh sách thành công:#{RESET}"
      success_list.each do |item|
        action_text = item[:action] == :cloned ? "Clone mới" : "Pull mới"
        puts "   #{GREEN}✔#{RESET} #{BOLD}#{item[:key]}#{RESET} [#{action_text}] -> #{DIM}#{item[:dir]}#{RESET}"
      end
    end

    unless skipped_list.empty?
      puts "\n#{YELLOW}⚠️  Danh sách bỏ qua:#{RESET}"
      skipped_list.each do |item|
        puts "   #{YELLOW}⚠️#{RESET}  #{item[:key]}: #{item[:reason]}"
      end
    end

    unless failed_list.empty?
      puts "\n#{RED}✖ Danh sách thất bại:#{RESET}"
      failed_list.each do |item|
        puts "   #{RED}✖#{RESET} #{BOLD}#{item[:key]}#{RESET}: #{item[:error]} (Thư mục: #{item[:dir]})"
      end
    end
    puts ""
  end
end

WorkspaceCodeSync.new.run if __FILE__ == $0
