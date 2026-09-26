# Application Components Design

## 1. Components Overview

```mermaid
classDiagram
    class AppleRegistrationHelper {
        +verify_and_register_apple_app(app_key, app_info, platform, options) Hash
        +verify_or_create_portal_bundle_id(bundle_id, app_name, platform_code) String
        +verify_or_create_asc_app(bundle_id, app_name, platform_name, api_key) String
        +batch_verify_and_register(apps_data, target_platform, options) Array
        +render_registration_summary_table(results) void
    }

    class FastlaneLanes {
        +ios:register_app(options)
        +mac:register_app(options)
        +root:register_apps(options)
    }

    class InteractiveCLI {
        +handle_sync_certs()
        +handle_register_apple_apps()
    }

    class MakefileTargets {
        +register-app-ios
        +register-app-mac
        +register-apps
    }

    InteractiveCLI --> MakefileTargets : executes
    MakefileTargets --> FastlaneLanes : runs
    FastlaneLanes --> AppleRegistrationHelper : delegates
    AppleRegistrationHelper --> SpaceshipConnectAPI : calls
    AppleRegistrationHelper --> FastlaneProduce : calls
```

### Component 1: `AppleRegistrationHelper` (`fastlane/helpers/apple_registration_helper.rb`)
- **Responsibility**: Encapsulates all query and mutation logic communicating with Apple Developer Portal and App Store Connect.
- **Key Characteristics**:
  - Stateless helper methods.
  - Safe error recovery (captures name collisions and API warnings without crashing batch runs).
  - Terminal output formatting with status emojis (`[EXISTS]`, `[CREATED]`, `[FAILED]`).

### Component 2: `FastlaneLanes` (`fastlane/lanes/ios.rb`, `macos.rb`, `Fastfile`)
- **Responsibility**: Defines the Fastlane user-facing interface, validates parameters, and orchestrates executions.

### Component 3: `InteractiveCLI` (`scripts/interactive_menu.rb`)
- **Responsibility**: Provides prompt-driven interaction in terminal for human operators.

### Component 4: `MakefileTargets` (`Makefile`)
- **Responsibility**: Standardizes CLI command invocations for developers and automated CI scripts.
