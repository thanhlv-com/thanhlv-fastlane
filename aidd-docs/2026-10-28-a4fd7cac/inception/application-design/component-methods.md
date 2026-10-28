# Component Methods & Script Signatures

## 1. Pre-Flight Resolver Methods (`CMP-PREFLIGHT-RESOLVER`)

### Method: `resolveAppAndTargetRepo(appKey, inputVersion)`
- **Runtime**: Node.js 22 (inline script in GHA step)
- **Input**:
  - `appKey`: String (e.g. `"web-clone"`)
  - `inputVersion`: String (e.g. `"1.0.3"` or `""`)
- **Processing Logic**:
  ```javascript
  const fs = require('fs');
  const apps = JSON.parse(fs.readFileSync('fastlane/apps.json', 'utf8'));
  const app = apps[appKey];
  if (!app) throw new Error(`App '${appKey}' not found in apps.json`);

  const version = (inputVersion && inputVersion.trim() !== "") ? inputVersion.trim() : (app.version || "1.0.0");
  const rawUrl = (app.release_download && app.release_download.trim() !== "") 
    ? app.release_download.trim() 
    : app.git_url.trim();

  // Convert git@github.com:owner/repo.git or https://github.com/owner/repo.git to owner/repo
  const match = rawUrl.match(/github\.com[:/]([^/]+)\/([^/.]+)(?:\.git)?$/);
  if (!match) throw new Error(`Could not parse GitHub repo from URL: ${rawUrl}`);

  const owner = match[1];
  const repoName = match[2];
  const targetRepo = `${owner}/${repoName}`;
  const releaseTag = `v${version}`;

  return { version, targetRepo, owner, repoName, releaseTag, appName: app.app_name || appKey };
  ```
- **Outputs**: Sets GHA step outputs: `version`, `target_repo`, `target_owner`, `release_tag`, `app_name`.

---

### Method: `verifyNoDuplicateRelease(targetRepo, releaseTag, version, ghToken)`
- **Runtime**: Bash / GitHub CLI (`gh`)
- **Input**: `targetRepo`, `releaseTag`, `version`, `ghToken`
- **Processing Logic**:
  ```bash
  export GH_TOKEN="$TOKEN"
  # Check standard tag vX.Y.Z
  if gh release view "$RELEASE_TAG" --repo "$TARGET_REPO" >/dev/null 2>&1; then
    echo "::error::❌ LỖI: Bản release cho version $VERSION (tag: $RELEASE_TAG) đã tồn tại trên repo $TARGET_REPO! Vui lòng nâng version trước khi tạo release mới."
    exit 1
  fi
  # Defensively check raw tag X.Y.Z
  if gh release view "$VERSION" --repo "$TARGET_REPO" >/dev/null 2>&1; then
    echo "::error::❌ LỖI: Bản release cho version $VERSION (tag: $VERSION) đã tồn tại trên repo $TARGET_REPO! Vui lòng nâng version trước khi tạo release mới."
    exit 1
  fi
  echo "✅ Xác thực thành công: Không có bản release nào trùng lặp trên $TARGET_REPO cho version $VERSION."
  ```
- **Error Condition**: Exits with code 1, immediately halting the pipeline.

---

## 2. Release Publisher Methods (`CMP-RELEASE-PUBLISHER`)

### Method: `aggregateArtifacts(downloadPath, targetAssetDir)`
- **Runtime**: Bash
- **Input**: Directory with downloaded GHA artifacts
- **Processing Logic**:
  ```bash
  mkdir -p release_assets
  find ./downloaded_artifacts -type f \( -name "*.dmg" -o -name "*.exe" -o -name "*.AppImage" \) -exec cp -f {} release_assets/ \;
  echo "📦 Danh sách file đính kèm release:"
  ls -lh release_assets/
  ```

---

### Method: `publishGitHubRelease(targetRepo, releaseTag, releaseTitle, releaseNotes, assetDir, ghToken)`
- **Runtime**: GitHub CLI (`gh`)
- **Processing Logic**:
  ```bash
  export GH_TOKEN="$TOKEN"
  gh release create "$RELEASE_TAG" "$ASSET_DIR"/* \
    --repo "$TARGET_REPO" \
    --title "$RELEASE_TITLE" \
    --notes "$RELEASE_NOTES"
  ```
- **Outputs**: Emits created release URL and notifies Telegram.
