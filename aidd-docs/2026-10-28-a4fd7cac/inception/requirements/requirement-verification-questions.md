# Requirement Verification Questions - Standalone GitHub Release Pipeline

## Question 1: Release Tag Format & Collision Detection
When creating the GitHub Release on the target repository, what tag format should be used, and how should duplicate detection be handled?

A) Standard Semantic Tagging with 'v' prefix (`v${VERSION}`), checking for existing releases matching either `v${VERSION}` or `${VERSION}`
B) Strict Raw Version string matching (`${VERSION}`) without prefix
C) Dynamic detection matching any existing release tag that resolves to the version
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A (Auto-selected recommendation: Using standard `v${VERSION}` format while defensively checking both `v${VERSION}` and `${VERSION}` ensures clean GitHub release naming while preventing duplicate release collision under either convention).

---

## Question 2: Target Repository Resolution and Token Authorization
How should the target repository URL be parsed, and how should authorization for release creation be managed?

A) Parse the repository URL from `apps.json` (`release_download` if defined, otherwise `git_url`), extract `owner/repo`, and generate a scoped GitHub App Token using `actions/create-github-app-token@v1`
B) Rely on default workflow `GITHUB_TOKEN` without parsing custom repository owners
C) Hardcode the target repository per application in the workflow YAML
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A (Auto-selected recommendation: Dynamically parsing `release_download` / `git_url` from `apps.json` allows full multi-repo flexibility, including repositories under different GitHub organizations such as `Web-Clone-app`, authorized via GitHub App Token).

---

## Question 3: Pre-Flight Duplicate Check Strategy (Fail-Fast Rule)
At what stage should the duplicate release check be executed?

A) Dual-stage verification: An early Pre-Flight check job (`validate-release`) before build jobs start to fail immediately and save runner minutes, plus a final verification in `publish-release`
B) Only at the end in the `publish-release` job after all platforms complete building
C) Only in the fastlane Ruby lane during checkout
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A (Auto-selected recommendation: Implementing an early Pre-Flight validation job avoids wasting up to 60+ minutes of expensive multi-OS runner compute if a release with that version already exists).

---

## Question 4: Platform Success Gating Rule (All Platforms Must Succeed)
How should the "all platforms must succeed before release" rule be enforced?

A) The `publish-release` job requires all jobs requested by `inputs.platform` to have completed with status `success` (`if: !cancelled() && !contains(needs.*.result, 'failure') && !contains(needs.*.result, 'cancelled')`)
B) Run release regardless of build job status and upload whatever succeeded
C) Manual human approval step between build and release
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A (Auto-selected recommendation: Strictly gate the release job so that every platform targeted in the workflow run must succeed. Any failure or cancellation on any targeted platform immediately halts release publishing).

---

## Question 5: Release Metadata & Change Notes Generation
What title and notes should be published with the release?

A) Release title: `<App Name> v<Version> (<Platform/Standalone>)` with automated release notes detailing artifacts, commit SHA, and build timestamp
B) Blank title and empty release notes
C) Git commit message only
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A (Auto-selected recommendation: Structured release title and informative markdown release notes detailing included binary downloads, SHA hashes, and execution provenance).
