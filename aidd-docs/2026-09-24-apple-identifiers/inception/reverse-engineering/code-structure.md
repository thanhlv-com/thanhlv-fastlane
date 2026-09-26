# Code Structure

## Directory Organization

```
thanhlv-fastlane/
├── fastlane/
│   ├── Fastfile                       # Global Fastfile importing helpers & lanes
│   ├── Appfile                        # Default credentials & Apple ID configurations
│   ├── Matchfile                      # Match Git URL and storage mode configuration
│   ├── apps.json                      # Registry of all apps with bundle IDs, platforms, and repos
│   ├── api_keys/                      # Local store for Apple .p8 and Google Play JSON keys
│   ├── helpers/                       # Reusable Ruby helper modules
│   │   ├── api_key_helper.rb          # App Store Connect API Key discovery & Match decryption
│   │   ├── app_config_helper.rb       # Reading apps.json, resolving bundle IDs & versions
│   │   ├── cert_helper.rb             # Local keychain & provisioning profile cleanup
│   │   ├── git_workspace_helper.rb    # Cloning & updating app repos in .workspace
│   │   ├── google_key_helper.rb       # Google Play service account key encryption/decryption
│   │   └── metadata_helper.rb         # Two-way store metadata and screenshot processing
│   └── lanes/                         # Platform-specific lane definitions
│       ├── ios.rb                     # iOS lanes (register_app, sync_certs, build, deploy)
│       ├── macos.rb                   # macOS lanes (register_app, sync_certs, build, deploy)
│       ├── aos.rb                     # Android lanes (build, deploy, metadata)
│       ├── windows.rb                 # Windows lanes
│       └── linux.rb                   # Linux lanes
├── scripts/
│   ├── interactive_menu.rb            # Terminal interactive menu CLI
│   ├── sync_workflow_apps.rb          # Syncs apps into GitHub Actions choice dropdowns
│   └── sync_workspace_code.rb         # Clones all source repos into .workspace_code
├── Makefile                           # Master CLI command aggregator
├── menu.sh                            # Shortcut runner for scripts/interactive_menu.rb
└── .github/workflows/                 # CI/CD automation pipelines
```

## Existing Identifier & App Registration Implementations
- `fastlane/lanes/ios.rb` (`lane :register_app`):
  Calls `produce(api_key: api_key, app_identifier: bundle_id, app_name: app_info["app_name"], skip_itc: false)`.
- `fastlane/lanes/macos.rb` (`lane :register_app`):
  Calls `produce(api_key: api_key, app_identifier: bundle_id, app_name: app_info["app_name"], platform: "osx", skip_itc: false)`.
- `Makefile`:
  Targets `register-app-ios` and `register-app-mac`.
