# Component Dependency Graph

```mermaid
graph TD
    InteractiveMenu["scripts/interactive_menu.rb"] -->|invokes| Makefile["Makefile"]
    Makefile -->|runs CLI| FastlaneCLI["Fastlane CLI Engine"]
    
    FastlaneCLI --> Fastfile["fastlane/Fastfile"]
    Fastfile --> LanesIOS["lanes/ios.rb"]
    Fastfile --> LanesMac["lanes/macos.rb"]
    
    LanesIOS --> AppleRegHelper["helpers/apple_registration_helper.rb"]
    LanesMac --> AppleRegHelper
    Fastfile --> AppleRegHelper

    AppleRegHelper --> AppConfigHelper["helpers/app_config_helper.rb"]
    AppleRegHelper --> APIKeyHelper["helpers/api_key_helper.rb"]
    AppleRegHelper --> Spaceship["Spaceship::ConnectAPI"]
    AppleRegHelper --> ProduceAction["Fastlane::Actions::ProduceAction"]

    AppConfigHelper --> AppsJSON["fastlane/apps.json"]
    APIKeyHelper --> ASCKey[".p8 API Key / Env"]
```

## Dependency Rules
1. **Unidirectional flow**: High-level CLI entrypoints call Fastlane, which calls helpers. Helpers do not call entrypoints.
2. **Helper re-use**: Both `ios.rb` and `macos.rb` depend on `apple_registration_helper.rb` to prevent duplicate Spaceship code.
3. **Configuration isolation**: `apps.json` remains the single data model source.
