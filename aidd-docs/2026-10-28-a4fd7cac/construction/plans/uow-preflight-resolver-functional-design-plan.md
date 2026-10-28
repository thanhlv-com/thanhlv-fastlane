# Functional Design Plan - Unit 1: uow-preflight-resolver

## 1. Functional Design Checklist
- [x] Step 1: Model Business Logic & Data Flow (`business-logic-model.md`)
- [x] Step 2: Formalize Business Rules & Validation (`business-rules.md`)
- [x] Step 3: Define Domain Entities & Output Schemas (`domain-entities.md`)

## 2. Design Questions & Auto-Resolved Choices

### Question 1: GitHub CLI Version Query Scope
Should the duplicate release check query tags via REST API or GitHub CLI (`gh release view`)?
A) Use `gh release view <tag> --repo <target-repo>` using GitHub CLI, checking both `v${VERSION}` and `${VERSION}`
B) Direct curl against GitHub REST API endpoint
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A (Auto-selected recommendation: `gh` CLI is standard on GitHub-hosted runners, automatically handles GitHub API headers, pagination, and exits cleanly with non-zero if the release is not found).

---

### Question 2: Error Reporting Mechanism
When a duplicate release is detected, how should the error be communicated?
A) Output GitHub Actions error annotation (`echo "::error::..."`) and immediately exit 1 to halt the job
B) Silent exit without error
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A (Auto-selected recommendation: GitHub Actions workflow error annotation highlights the exact root cause directly in the GitHub summary UI for developers).
