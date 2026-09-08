#!/usr/bin/env python3
"""
detect_app_config.py
Quét thông tin ứng dụng CHỈ trong thư mục .workspace_code và sinh JSON cấu hình chuẩn cho fastlane/apps.json.
"""

import argparse
import json
import os
import re
import subprocess
import sys


def find_repo_root():
    cur = os.path.abspath(os.getcwd())
    while cur and cur != os.path.dirname(cur):
        if os.path.isdir(os.path.join(cur, ".workspace_code")) or os.path.isfile(os.path.join(cur, "fastlane", "apps.json")):
            return cur
        cur = os.path.dirname(cur)
    return os.path.abspath(os.getcwd())


def resolve_and_validate_project_dir(app_input):
    repo_root = find_repo_root()
    workspace_code_dir = os.path.realpath(os.path.join(repo_root, ".workspace_code"))

    # Case 1: Tên thư mục trực tiếp (ví dụ: app-QuestFlow)
    direct_path = os.path.realpath(os.path.join(workspace_code_dir, app_input))
    if os.path.isdir(direct_path):
        target_dir = direct_path
    else:
        target_dir = os.path.realpath(os.path.abspath(app_input))

    if not os.path.isdir(target_dir):
        print(f"❌ Lỗi: Không tìm thấy thư mục dự án: {target_dir}", file=sys.stderr)
        print(f"💡 Gợi ý: Hãy đảm bảo dự án đã được đặt trong '{workspace_code_dir}/<app_name>'", file=sys.stderr)
        sys.exit(1)

    # Ràng buộc nghiêm ngặt: Phải nằm bên trong .workspace_code
    try:
        common = os.path.commonpath([workspace_code_dir, target_dir])
        if os.path.realpath(common) != workspace_code_dir or target_dir == workspace_code_dir:
            print(f"❌ Lỗi: Chỉ chấp nhận các dự án nằm bên trong thư mục '.workspace_code'!", file=sys.stderr)
            print(f"   Đường dẫn được cung cấp: {target_dir}", file=sys.stderr)
            print(f"   Thư mục yêu cầu       : {workspace_code_dir}/<app_name>", file=sys.stderr)
            sys.exit(1)
    except ValueError:
        print(f"❌ Lỗi: Thư mục dự án '{target_dir}' không thuộc '{workspace_code_dir}'!", file=sys.stderr)
        sys.exit(1)

    return target_dir


def run_git_cmd(cmd_args, cwd):
    try:
        res = subprocess.run(
            ["git", "-C", cwd] + cmd_args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
        )
        return res.stdout.strip()
    except Exception:
        return None


def detect_git_info(project_dir):
    git_url = run_git_cmd(["remote", "get-url", "origin"], project_dir)
    branch = run_git_cmd(["branch", "--show-current"], project_dir) or "main"
    return git_url, branch


def detect_platforms(project_dir):
    platforms = []
    if os.path.isdir(os.path.join(project_dir, "ios")):
        platforms.append("ios")
    if os.path.isdir(os.path.join(project_dir, "macos")):
        platforms.append("macos")
    if os.path.isdir(os.path.join(project_dir, "android")):
        platforms.append("aos")
    return platforms


def detect_android_package(project_dir):
    gradle_kts = os.path.join(project_dir, "android", "app", "build.gradle.kts")
    if os.path.isfile(gradle_kts):
        with open(gradle_kts, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
            m = re.search(r'applicationId\s*=\s*["\']([^"\']+)["\']', content)
            if m:
                return m.group(1)
            m = re.search(r'namespace\s*=\s*["\']([^"\']+)["\']', content)
            if m:
                return m.group(1)

    gradle = os.path.join(project_dir, "android", "app", "build.gradle")
    if os.path.isfile(gradle):
        with open(gradle, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
            m = re.search(r'applicationId\s+["\']([^"\']+)["\']', content)
            if m:
                return m.group(1)
            m = re.search(r'namespace\s+["\']([^"\']+)["\']', content)
            if m:
                return m.group(1)

    manifest = os.path.join(project_dir, "android", "app", "src", "main", "AndroidManifest.xml")
    if os.path.isfile(manifest):
        with open(manifest, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
            m = re.search(r'package\s*=\s*["\']([^"\']+)["\']', content)
            if m:
                return m.group(1)

    return None


def detect_ios_bundle_id(project_dir):
    pbxproj = os.path.join(project_dir, "ios", "Runner.xcodeproj", "project.pbxproj")
    if os.path.isfile(pbxproj):
        with open(pbxproj, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if "PRODUCT_BUNDLE_IDENTIFIER" in line and "Tests" not in line:
                    parts = line.split("=")
                    if len(parts) > 1:
                        val = parts[1].strip().rstrip(";").strip('"').strip("'")
                        if val and not val.startswith("$"):
                            return val

    app_info = os.path.join(project_dir, "macos", "Runner", "Configs", "AppInfo.xcconfig")
    if os.path.isfile(app_info):
        with open(app_info, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if "PRODUCT_BUNDLE_IDENTIFIER" in line:
                    parts = line.split("=")
                    if len(parts) > 1:
                        return parts[1].strip()

    return None


def detect_version(project_dir):
    pubspec = os.path.join(project_dir, "pubspec.yaml")
    if os.path.isfile(pubspec):
        with open(pubspec, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if line.strip().startswith("version:"):
                    raw_ver = line.split(":", 1)[1].strip()
                    ver = raw_ver.split("+")[0].strip()
                    return ver
    return "1.0.0"


def detect_app_name_and_desc(project_dir):
    app_name = None
    description = None

    for doc_name in ["store_release_and_aso_guide.md", "first.md", "README.md"]:
        doc_path = os.path.join(project_dir, "docs", doc_name)
        if not os.path.isfile(doc_path):
            doc_path = os.path.join(project_dir, doc_name)
        if os.path.isfile(doc_path):
            with open(doc_path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()

                m_ios = re.search(r'-\s*(?:\*\*)?iOS[^*:\n]*:(?:\*\*)?\s*`([^`]+)`', content, re.I)
                if m_ios and not app_name:
                    app_name = m_ios.group(1).strip()

                if not app_name:
                    m_title = re.search(r'(?:App Title|Tên ứng dụng)[^:\n]*:\s*`?([^\n`*#]+)`?', content, re.I)
                    if m_title:
                        val = m_title.group(1).strip().strip('*').strip()
                        if val and len(val) > 2:
                            app_name = val

                m_en = re.search(r'-\s*(?:\*\*)?EN[^*:\n]*:(?:\*\*)?\s*`([^`]+)`', content, re.I)
                if m_en and not description:
                    description = m_en.group(1).strip()

                if not description:
                    m_desc = re.search(r'(?:Subtitle|Short Description|Mô tả ngắn)[^:\n]*:\s*`?([^\n`*#]+)`?', content, re.I)
                    if m_desc:
                        val = m_desc.group(1).strip().strip('*').strip()
                        if val and len(val) > 2:
                            description = val

    info_plist = os.path.join(project_dir, "ios", "Runner", "Info.plist")
    if not app_name and os.path.isfile(info_plist):
        with open(info_plist, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
            m = re.search(r'<key>CFBundleDisplayName</key>\s*<string>([^<]+)</string>', content)
            if m:
                app_name = m.group(1).strip()
            else:
                m = re.search(r'<key>CFBundleName</key>\s*<string>([^<]+)</string>', content)
                if m:
                    app_name = m.group(1).strip()

    pubspec = os.path.join(project_dir, "pubspec.yaml")
    if os.path.isfile(pubspec):
        with open(pubspec, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if not app_name and line.strip().startswith("name:"):
                    app_name = line.split(":", 1)[1].strip()
                if not description and line.strip().startswith("description:"):
                    raw_desc = line.split(":", 1)[1].strip().strip('"').strip("'")
                    if raw_desc != "A new Flutter project.":
                        description = raw_desc

    return app_name or os.path.basename(os.path.abspath(project_dir)), description or app_name or ""


def main():
    parser = argparse.ArgumentParser(
        description="Scan project directory STRICTLY inside .workspace_code and generate apps.json entry."
    )
    parser.add_argument(
        "app",
        help="App name or path inside .workspace_code (e.g. 'app-QuestFlow' or '.workspace_code/app-QuestFlow')",
    )
    parser.add_argument("--key", help="App key name for apps.json (defaults to directory name)")
    parser.add_argument("--json", action="store_true", help="Print only raw JSON")
    args = parser.parse_args()

    project_dir = resolve_and_validate_project_dir(args.app)

    app_key = args.key or os.path.basename(project_dir)
    git_url, branch = detect_git_info(project_dir)
    platforms = detect_platforms(project_dir)
    package_name = detect_android_package(project_dir)
    bundle_id = detect_ios_bundle_id(project_dir) or package_name
    package_name = package_name or bundle_id
    version = detect_version(project_dir)
    app_name, description = detect_app_name_and_desc(project_dir)

    config = {
        "app_name": app_name,
        "git_url": git_url or f"git@github.com:thanhlv-com/{app_key}.git",
        "branch": branch,
        "platforms": platforms,
        "bundle_id": bundle_id,
        "package_name": package_name,
        "version": version,
        "obfuscate": True,
        "description": description,
    }

    entry = {app_key: config}
    if args.json:
        print(json.dumps(entry, indent=2, ensure_ascii=False))
    else:
        print(f"=== Cấu hình phát hiện từ .workspace_code/{app_key} ===")
        print(json.dumps(entry, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
