# Functional Design Plan - Unit 2: uow-release-publisher

## 1. Functional Design Checklist
- [x] Step 1: Model Release Publishing & Asset Aggregation Flow (`business-logic-model.md`)
- [x] Step 2: Formalize Gating Rules & Failure Handling (`business-rules.md`)
- [x] Step 3: Define Domain Entities & Release Metadata (`domain-entities.md`)

## 2. Design Questions & Auto-Resolved Choices

### Question 1: Gating Evaluation Condition (Rule 2)
How should the workflow evaluate whether all requested platforms succeeded?
A) Comprehensive multi-branch conditional in job `if`:
   ```yaml
   if: |
     always() &&
     inputs.release == true &&
     (needs.pre-check.result == 'success') &&
     (inputs.platform != 'all' || (needs.build-macos.result == 'success' && needs.build-windows.result == 'success' && needs.build-linux.result == 'success')) &&
     (inputs.platform != 'macos' || needs.build-macos.result == 'success') &&
     (inputs.platform != 'windows' || needs.build-windows.result == 'success') &&
     (inputs.platform != 'linux' || needs.build-linux.result == 'success')
   ```
B) Rely on default `needs` behavior without explicit platform checking
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A (Auto-selected recommendation: Explicit conditional expression guarantees that when `platform: all` is selected, every single platform must succeed; if a specific platform like `macos` is selected, only that platform is required to succeed).

---

### Question 2: Artifact Download & Extraction Method
How should the multiple platform artifacts be downloaded and structured for `gh release create`?
A) Use `actions/download-artifact@v4` with `path: downloaded_artifacts`, then aggregate all `.dmg`, `.exe`, `.AppImage` files into a flat `release_assets/` folder
B) Download artifacts into separate directories and execute multiple `gh release upload` commands
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A (Auto-selected recommendation: Aggregating all binaries into a single directory before running `gh release create` attaches all assets in one atomic release transaction).
