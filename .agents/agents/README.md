# Antigravity Subagents Directory

Thư mục này chứa danh sách các **Subagents** chuyên trách của dự án `thanhlv-fastlane`.

## Quy ước cấu trúc khi tạo thêm Agent mới

Mỗi Agent sẽ gồm một cặp:
1. **`<agent_name>.md`**: File định nghĩa Persona, mục tiêu, giới hạn và quy trình làm việc (Antigravity sẽ quét trực tiếp file này).
2. **`<agent_name>/`**: Thư mục con cùng tên chứa toàn bộ helper scripts, templates hoặc công cụ hỗ trợ riêng của Agent đó.

```text
.agents/agents/
├── README.md
│
├── fastlane_add_app.md              # File Persona cho Subagent fastlane_add_app
└── fastlane_add_app/                # Thư mục công cụ riêng của fastlane_add_app
    └── detect_app_config.py
```

### Cách tạo một Agent mới (ví dụ: `release_verifier`)
1. Tạo file `.agents/agents/release_verifier.md`:
   ```markdown
   ---
   name: release_verifier
   description: "Kiểm tra tính sẵn sàng trước khi release ứng dụng lên Store."
   mainAgent: false
   subagent: true
   commandExecutionPolicy: auto
   ---
   # Release Verifier Persona
   ...
   ```
2. (Tuỳ chọn) Nếu Agent cần script tự động, tạo thư mục:
   ```text
   .agents/agents/release_verifier/
   └── check_certs.sh
   ```
