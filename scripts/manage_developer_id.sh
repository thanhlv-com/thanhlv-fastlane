#!/usr/bin/env bash
# ==============================================================================
# DEVELOPER ID APPLICATION MANAGEMENT TOOL (macOS Standalone Code Signing)
# ==============================================================================
# Hỗ trợ tạo CSR, kiểm tra, đóng gói .p12 và đồng bộ chứng chỉ Developer ID
# vào apple-certificates-keystore thông qua Fastlane Match.
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Thư mục lưu trữ credentials mặc định
DEFAULT_WORK_DIR="$PROJECT_ROOT/.workspace/developer_id"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# In thông điệp định dạng
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# Hiển thị banner
banner() {
  echo -e "${CYAN}====================================================================${NC}"
  echo -e "${CYAN}   🛠️  Apple Developer ID Certificate Management Tool${NC}"
  echo -e "${CYAN}====================================================================${NC}"
}

# Hiển thị hướng dẫn
usage() {
  banner
  cat <<EOF
Sử dụng:
  ./scripts/manage_developer_id.sh <lệnh> [tham số]

Các lệnh khả dụng:
  create-csr [thư_mục]
      Tạo Private Key RSA 2048-bit và file CSR (Certificate Signing Request)
      chuẩn để upload lên Apple Developer Portal.
      Mặc định lưu vào: $DEFAULT_WORK_DIR

  import <file_cer> [file_key] [mật_khẩu_p12]
      Kiểm tra cặp Key & Cert, xác thực mục đích Code Signing, đóng gói .p12
      và tự động đẩy lên Keystore (apple-certificates-keystore).

  verify
      Kiểm tra toàn diện trạng thái chứng chỉ:
      - macOS Keychain Identities (-v -p codesigning)
      - App Store Connect API (danh sách certs trên Apple Developer)
      - Cấu trúc Git Keystore hiện hành.

  export-base64 <file_p12>
      Xuất chuỗi Base64 của file .p12 và tự động sao chép vào Clipboard (pbcopy)
      dùng để cấu hình GitHub Actions Secret / Workflow Input.

Ví dụ:
  ./scripts/manage_developer_id.sh create-csr
  ./scripts/manage_developer_id.sh import ~/Downloads/developerID_application.cer
  ./scripts/manage_developer_id.sh verify
EOF
  exit 1
}

# ------------------------------------------------------------------------------
# LỆNH 1: CREATE-CSR
# ------------------------------------------------------------------------------
cmd_create_csr() {
  banner
  local work_dir="${1:-$DEFAULT_WORK_DIR}"
  mkdir -p "$work_dir"

  local key_file="$work_dir/developer_id.key"
  local csr_file="$work_dir/upload_to_apple.certSigningRequest"

  # Đọc thông tin từ fastlane/.env nếu có
  local email="lethanh9398@gmail.com"
  local name="Developer ID Application - lethanh9398"
  local country="VN"

  if [ -f "$PROJECT_ROOT/fastlane/.env" ]; then
    local env_email
    env_email=$(grep -E "^APPLE_ID=" "$PROJECT_ROOT/fastlane/.env" | cut -d'=' -f2- | tr -d '"'\'' ' || true)
    if [ -n "$env_email" ]; then email="$env_email"; fi
  fi

  info "Tạo Private Key RSA 2048-bit..."
  openssl genrsa -out "$key_file" 2048 2>/dev/null
  chmod 600 "$key_file"

  info "Tạo Certificate Signing Request (CSR) cho $email..."
  openssl req -new -key "$key_file" -out "$csr_file" \
    -subj "/emailAddress=$email/CN=$name/C=$country" 2>/dev/null

  success "Đã tạo thành công Private Key và file CSR!"
  echo ""
  echo "📂 Các file đã lưu tại: $work_dir"
  echo "  🔑 Private Key : $key_file"
  echo "  📄 File CSR     : $csr_file"
  echo ""
  echo -e "${YELLOW}👉 CÁC BƯỚC TIẾP THEO:${NC}"
  echo "1. Mở trình duyệt vào Apple Developer Portal:"
  echo "   🌐 https://developer.apple.com/account/resources/certificates/add"
  echo "2. Chọn mục 'Developer ID Application' -> Bấm Continue."
  echo "3. Bấm 'Choose File' -> Chọn file vừa tạo:"
  echo "   $csr_file"
  echo "4. Bấm 'Continue' và 'Download' file chứng chỉ (.cer) về máy."
  echo "5. Sau đó chạy lệnh import:"
  echo "   ./scripts/manage_developer_id.sh import ~/Downloads/developerID_application.cer"
}

# ------------------------------------------------------------------------------
# LỆNH 2: IMPORT
# ------------------------------------------------------------------------------
cmd_import() {
  banner
  local cer_path="$1"
  local key_path="$2"
  local p12_pass="${3:-123123}"

  if [ -z "$cer_path" ] || [ ! -f "$cer_path" ]; then
    error "Vui lòng cung cấp đường dẫn hợp lệ tới file .cer từ Apple!"
    echo "Cách dùng: ./scripts/manage_developer_id.sh import <đường_dẫn_file.cer> [đường_dẫn_key]"
    exit 1
  fi

  # Tự động tìm key tương ứng nếu không truyền vào
  if [ -z "$key_path" ]; then
    if [ -f "$DEFAULT_WORK_DIR/developer_id.key" ]; then
      key_path="$DEFAULT_WORK_DIR/developer_id.key"
    elif [ -f "$PROJECT_ROOT/.workspace/developer_id/developer_id.key" ]; then
      key_path="$PROJECT_ROOT/.workspace/developer_id/developer_id.key"
    elif [ -f "$(dirname "$cer_path")/developer_id.key" ]; then
      key_path="$(dirname "$cer_path")/developer_id.key"
    elif [ -f "$(dirname "$cer_path")/apple_dev_id_private.key" ]; then
      key_path="$(dirname "$cer_path")/apple_dev_id_private.key"
    else
      error "Không tự động tìm thấy file Private Key (.key)!"
      echo "Vui lòng chỉ định rõ: ./scripts/manage_developer_id.sh import $cer_path <đường_dẫn_private.key>"
      exit 1
    fi
  fi

  if [ ! -f "$key_path" ]; then
    error "File Private Key '$key_path' không tồn tại!"
    exit 1
  fi

  info "Kiểm tra Certificate: $cer_path"
  info "Kiểm tra Private Key:  $key_path"

  local tmp_dir
  tmp_dir=$(mktemp -d /tmp/dev_id_pack_XXXXXX)
  trap 'rm -rf "$tmp_dir"' EXIT

  local cer_pem="$tmp_dir/cert.pem"
  openssl x509 -inform der -in "$cer_path" -out "$cer_pem" 2>/dev/null || cp "$cer_path" "$cer_pem"

  # 1. Kiểm tra cặp modulus giữa key và cert
  local key_mod
  local cer_mod
  key_mod=$(openssl rsa -noout -modulus -in "$key_path" 2>/dev/null | openssl md5)
  cer_mod=$(openssl x509 -noout -modulus -in "$cer_pem" 2>/dev/null | openssl md5)

  if [ "$key_mod" != "$cer_mod" ]; then
    error "Private Key và Certificate KHÔNG KHỚP NHAU!"
    echo "  Key Modulus Hash : $key_mod"
    echo "  Cert Modulus Hash: $cer_mod"
    echo "Vui lòng kiểm tra lại bạn đã dùng đúng Private Key khi tạo file CSR này chưa."
    exit 1
  fi
  success "Private Key và Certificate đã KHỚP 100%!"

  # 2. Kiểm tra Purpose Code Signing
  local purpose_out
  purpose_out=$(openssl x509 -in "$cer_pem" -noout -purpose 2>/dev/null || true)
  if echo "$purpose_out" | grep -q "Code signing : Yes"; then
    success "Xác nhận: Chứng chỉ có quyền Code Signing hợp lệ!"
  else
    warn "CẢNH BÁO: Chứng chỉ này không có quyền Code Signing (Code signing : No)!"
    warn "Đây có thể là chứng chỉ S/MIME Email. Vui lòng đảm bảo bạn chọn 'Developer ID Application' trên Apple Portal."
  fi

  # 3. Đóng gói thành .p12 chuẩn macOS (TripleDES + MAC)
  local out_p12="$tmp_dir/developer_id.p12"
  openssl pkcs12 -export -legacy -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES \
    -inkey "$key_path" -in "$cer_pem" -out "$out_p12" -passout "pass:$p12_pass" 2>/dev/null

  success "Đã đóng gói thành công file PKCS#12 tạm: $out_p12"

  # 4. Gọi Fastlane import_developer_id để đẩy lên Keystore Git
  info "Đang nạp chứng chỉ vào Fastlane Match Keystore..."
  cd "$PROJECT_ROOT"
  fastlane standalone import_developer_id p12_path:"$out_p12" p12_password:"$p12_pass"

  # 5. Xuất chuỗi Base64
  if command -v pbcopy >/dev/null 2>&1; then
    base64 -i "$out_p12" | pbcopy
    success "Đã tự động sao chép chuỗi Base64 của file .p12 vào Clipboard!"
    info "Bạn có thể dán (Cmd+V) vào GitHub Action input 'p12_base64' bất cứ lúc nào."
  fi
}

# ------------------------------------------------------------------------------
# LỆNH 3: VERIFY
# ------------------------------------------------------------------------------
cmd_verify() {
  banner
  info "1. Kiểm tra Code Signing Identities trong macOS Keychain:"
  echo "--------------------------------------------------------------------"
  security find-identity -v -p codesigning || true
  echo "--------------------------------------------------------------------"

  info "2. Kiểm tra chứng chỉ trên Apple Developer Portal qua Spaceship API:"
  cd "$PROJECT_ROOT"
  env GEM_HOME=/opt/homebrew/Cellar/fastlane/2.238.0/libexec /opt/homebrew/Cellar/ruby/4.0.6_1/bin/ruby -e '
    require "spaceship"
    key_file = "fastlane/api_keys/AuthKey_FMTTSQML5M.p8"
    if !File.exist?(key_file)
      puts "⚠️  Không tìm thấy API Key tại #{key_file}"
      exit 0
    end
    token = Spaceship::ConnectAPI::Token.create(
      key_id: ENV["ASC_KEY_ID"] || "FMTTSQML5M",
      issuer_id: ENV["ASC_ISSUER_ID"] || "f403c9dc-244e-419e-97fc-bb2c1263ae60",
      key: File.read(key_file),
      in_house: false
    )
    Spaceship::ConnectAPI.token = token
    certs = Spaceship::ConnectAPI.get_certificates.to_models
    dev_ids = certs.select { |c| c.certificate_type.include?("DEVELOPER_ID") }
    puts "Tìm thấy #{dev_ids.length} chứng chỉ Developer ID trên Apple Portal:"
    dev_ids.each do |c|
      puts " - [#{c.id}] #{c.name} | Loại: #{c.certificate_type} | Hạn dùng: #{c.expiration_date} | Serial: #{c.serial_number}"
    end
  ' 2>/dev/null || warn "Không thể kết nối Spaceship API (kiểm tra mạng hoặc API Key)."

  echo ""
  info "3. Kiểm tra file cấu hình Match:"
  if [ -f "$PROJECT_ROOT/fastlane/Matchfile" ]; then
    success "Matchfile tồn tại."
    if grep -q "clone_branch_directly(true)" "$PROJECT_ROOT/fastlane/Matchfile"; then
      success "Matchfile đã bật clone_branch_directly(true)."
    else
      warn "Matchfile chưa bật clone_branch_directly(true)."
    fi
  fi
}

# ------------------------------------------------------------------------------
# LỆNH 4: EXPORT-BASE64
# ------------------------------------------------------------------------------
cmd_export_base64() {
  banner
  local p12_path="$1"
  if [ -z "$p12_path" ] || [ ! -f "$p12_path" ]; then
    error "Vui lòng cung cấp đường dẫn hợp lệ tới file .p12!"
    echo "Cách dùng: ./scripts/manage_developer_id.sh export-base64 <đường_dẫn_file.p12>"
    exit 1
  fi

  if command -v pbcopy >/dev/null 2>&1; then
    base64 -i "$p12_path" | pbcopy
    success "Đã sao chép chuỗi Base64 của '$p12_path' vào Clipboard thành công!"
  else
    base64 -i "$p12_path"
  fi
}

# ------------------------------------------------------------------------------
# ENTRYPOINT
# ------------------------------------------------------------------------------
case "$1" in
  create-csr)
    cmd_create_csr "$2"
    ;;
  import)
    cmd_import "$2" "$3" "$4"
    ;;
  verify)
    cmd_verify
    ;;
  export-base64)
    cmd_export_base64 "$2"
    ;;
  *)
    usage
    ;;
esac
