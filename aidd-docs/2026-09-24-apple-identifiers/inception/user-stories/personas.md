# User Personas

## Persona 1: Alex - Mobile DevOps & Release Engineer
- **Role**: Lead DevOps Engineer managing build pipelines, signing credentials, and App Store deployments.
- **Goals**:
  - Automate the onboarding of newly added apps into the Apple ecosystem.
  - Run one command to verify all identifiers and apps across both iOS and macOS before running Match or release lanes.
  - Avoid tedious manual clicking in the Apple Developer Portal and App Store Connect web consoles.
- **Pain Points**:
  - Manually checking if bundle IDs or apps exist is slow and prone to human error.
  - Existing scripts crash or halt when an identifier is already registered.

## Persona 2: Minh - Flutter Application Developer
- **Role**: Contributor developing new apps or features in Flutter.
- **Goals**:
  - Quickly register their new app bundle ID and App Store Connect app using the CLI menu without needing in-depth knowledge of Fastlane syntax or Spaceship APIs.
  - Verify that everything is ready for signing and TestFlight deployment.
- **Pain Points**:
  - Complex command arguments; prefers interactive prompts (`menu.sh` / `scripts/interactive_menu.rb`).

## Persona 3: CI/CD Pipeline Bot (GitHub Actions / Local Agent)
- **Role**: Automated headless execution system.
- **Goals**:
  - Execute idempotent batch registration commands (`make register-apps APP=all`) without interactive prompts.
  - Parse non-zero exit codes only when fatal system errors occur, while receiving structured log outputs and summary tables.
