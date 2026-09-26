# Unit of Work Plan

## 1. Overview
This plan defines the decomposition of construction tasks into testable, discrete Units of Work (UOW).

## 2. Units of Work (UOW)

| Unit ID | Name | Focus | Dependencies | Deliverables |
|---|---|---|---|---|
| **UOW-01** | Apple Registration Helper | Core verification & creation logic using Spaceship ConnectAPI & produce | Existing `api_key_helper.rb`, `app_config_helper.rb` | `fastlane/helpers/apple_registration_helper.rb` |
| **UOW-02** | Fastlane Lanes Update | Update iOS, macOS, and root Fastlane lanes | UOW-01 | `fastlane/lanes/ios.rb`, `fastlane/lanes/macos.rb`, `fastlane/Fastfile` |
| **UOW-03** | Makefile & CLI Menu Integration | Makefile targets and interactive CLI menu choices | UOW-02 | `Makefile`, `scripts/interactive_menu.rb` |
| **UOW-04** | Syntax & Sanity Verification | Code syntax validation, dry run tests, documentation updates | UOW-01, UOW-02, UOW-03 | Fastlane / Ruby test run, updated README |
