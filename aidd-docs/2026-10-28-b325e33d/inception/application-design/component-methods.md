# Component Methods & Interfaces

## 1. `fastlane/helpers/git_workspace_helper.rb`

### Method: `configure_electron_version!(workspace_dir, version_name, build_number = nil)`
- **Parameters**:
  - `workspace_dir` (String): Absolute or relative path to the app's workspace root.
  - `version_name` (String): Semantic version string to inject (e.g. `"1.0.1"`).
  - `build_number` (String, optional): Build number or epoch timestamp.
- **Return**: `Boolean` — `true` if updated successfully, `false` otherwise.
- **Behavior & Logic**:
  ```ruby
  def configure_electron_version!(workspace_dir, version_name, build_number = nil)
    return false if version_name.nil? || version_name.to_s.strip.empty?
    package_json_path = File.join(workspace_dir, "package.json")
    return false unless File.exist?(package_json_path)

    begin
      pkg_data = JSON.parse(File.read(package_json_path))
      old_version = pkg_data["version"]
      pkg_data["version"] = version_name.to_s.strip
      
      File.write(package_json_path, JSON.pretty_generate(pkg_data) + "\n")
      UI.success("📝 Đã cập nhật version: #{old_version} -> #{version_name} trong #{File.basename(package_json_path)}")
      true
    rescue => e
      UI.error("⚠️ Không thể cập nhật version vào package.json: #{e.message}")
      false
    end
  end
  ```

---

## 2. `fastlane/lanes/standalone.rb`

### Method: `mac_build(options)` / `win_build(options)` / `linux_build(options)`
- **Updates**:
  Immediately after `workspace_dir` is prepared and `version_name` is resolved:
  ```ruby
  if is_electron_app?(app_info, workspace_dir)
    configure_electron_version!(workspace_dir, version_name, build_number)
    # Build command generation:
    version_arg = (version_name && !version_name.empty?) ? " -c.extraMetadata.version=#{version_name}" : ""
    build_cmd = if scripts["build:mac"]
                  "#{pkg_mgr} run build:mac --#{version_arg}"
                elsif scripts["build"]
                  "#{pkg_mgr} run build && npx electron-builder --mac#{version_arg}"
                else
                  "npx electron-builder --mac#{version_arg}"
                end
  ```

---

## 3. `.workspace_code/web-clone/src/main/menu.ts`

### Function: `setupAppMenu(iconPath?: string): void`
- **Updates**:
  ```typescript
  app.setAboutPanelOptions({
    applicationName: 'Web Clone',
    applicationVersion: app.getVersion(),
    version: app.getVersion(),
    copyright: 'Copyright © 2026 Web Clone. All rights reserved.',
    credits: 'Multi-Session Browser Platform',
    authors: ['Web Clone Team'],
    website: 'https://example.com',
    iconPath
  })
  ```
