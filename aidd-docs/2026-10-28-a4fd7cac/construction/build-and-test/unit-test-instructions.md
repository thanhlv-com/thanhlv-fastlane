# Unit Test Instructions - Standalone Release Logic

## 1. Test Scope
Verifies individual components of the standalone release pipeline:
1. `apps.json` schema validation and app entry lookup.
2. Version resolution precedence (`inputs.version` vs `app.version`).
3. Repository URL parsing (SSH and HTTPS formats).
4. `release_download` priority over `git_url`.
5. Release tag generation (`v${version}`).

## 2. Running Unit Tests
Execute the Node.js unit test runner:

```bash
node -e '
const fs = require("fs");
const assert = require("assert");
const apps = JSON.parse(fs.readFileSync("fastlane/apps.json", "utf8"));

function resolveTarget(appKey, inputVer) {
  const app = apps[appKey];
  assert(app, `App ${appKey} must exist`);
  const ver = (inputVer || "").trim() !== "" ? inputVer.trim() : (app.version || "1.0.0");
  const rawUrl = (app.release_download && app.release_download.trim() !== "")
    ? app.release_download.trim()
    : app.git_url.trim();
  const m = rawUrl.match(/github\.com[:/]([^/]+)\/([^/.]+)(?:\.git)?$/);
  assert(m, `URL must match github pattern: ${rawUrl}`);
  return {
    repo: `${m[1]}/${m[2]}`,
    owner: m[1],
    version: ver,
    tag: `v${ver}`
  };
}

// Case 1: App with release_download
const r1 = resolveTarget("web-clone", "1.0.5");
assert.strictEqual(r1.repo, "Web-Clone-app/download");
assert.strictEqual(r1.owner, "Web-Clone-app");
assert.strictEqual(r1.tag, "v1.0.5");

// Case 2: App without release_download (fallback to git_url)
const r2 = resolveTarget("CloudOps", "");
assert.strictEqual(r2.repo, "thanhlv-com/dev-tool");
assert.strictEqual(r2.owner, "thanhlv-com");
assert.strictEqual(r2.tag, "v1.8.0");

console.log("✅ All unit tests PASSED!");
'
```
