# Inter-Unit Interfaces

## 1. Interface: `configure_electron_version!`
- **Supplier**: UOW-01 (`git_workspace_helper.rb`)
- **Consumer**: UOW-02 (`standalone.rb`)
- **Protocol**: Direct Ruby Method Invocation
- **Contract**:
  ```ruby
  def configure_electron_version!(workspace_dir, version_name, build_number = nil)
    # Returns true on successful JSON write, false on error
  end
  ```
- **Error Handling**: Catches `StandardError`, logs `UI.error`, returns `false`.

---

## 2. Interface: `setupAppMenu`
- **Supplier**: UOW-03 (`web-clone/src/main/menu.ts`)
- **Consumer**: `web-clone/src/main/index.ts`
- **Protocol**: TypeScript Function Call
- **Contract**:
  ```typescript
  export function setupAppMenu(iconPath?: string): void
  ```
- **Behavior**: Retrieves `app.getVersion()` and passes it to `app.setAboutPanelOptions`.
