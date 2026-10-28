# Application Design Plan

## 1. Design Execution Checklist
- [x] Step 1: Define Components & Responsibilities (`components.md`)
- [x] Step 2: Define Component Methods & Script Signatures (`component-methods.md`)
- [x] Step 3: Define Services & Orchestration Patterns (`services.md`)
- [x] Step 4: Map Component Dependencies & Data Flow (`component-dependency.md`)

## 2. Design Decisions & Questions

### Question 1: Script Implementation for `apps.json` Parsing and URL Conversion
How should the dynamic repository resolution and URL parsing be implemented inside the workflow jobs?
A) Inline Node.js script using native `fs` and regex to parse `apps.json`, resolve `release_download` vs `git_url`, extract `owner` and `repo`, and emit GitHub Actions outputs (`>> $GITHUB_OUTPUT`)
B) External bash script requiring jq
C) Python script requiring python installation
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A (Auto-selected recommendation: Node.js is already guaranteed available across all GitHub Actions runners and handles robust JSON parsing and regex without external package dependencies).

---

### Question 2: GitHub CLI Authentication & API Call Method
How should the pre-flight release check and final release publishing authenticate against GitHub?
A) Use `actions/create-github-app-token@v1` passing the dynamically parsed `owner` from the target repository, and export as `GH_TOKEN: ${{ steps.app_token.outputs.token }}` for `gh release` CLI commands
B) Use default `GITHUB_TOKEN`
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A (Auto-selected recommendation: Dynamically generating the GitHub App Token using the target repo's owner grants seamless cross-repo access to both `thanhlv-com` and `Web-Clone-app` organizations).
