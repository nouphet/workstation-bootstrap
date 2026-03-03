#!/usr/bin/env bash
#===============================================================================
# setup-devtools.sh
# インフラ自動化・AI CLI・開発ツール 一括セットアップスクリプト
#
# 対象OS: Ubuntu 22.04 / 24.04 (WSL2含む)
# 実行方法: chmod +x setup-devtools.sh && ./setup-devtools.sh
#===============================================================================
set -euo pipefail

# ---------- 色付きログ ----------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
section() { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }

# ---------- 前提チェック ----------
if [[ $EUID -eq 0 ]]; then
  error "root で直接実行しないでください。sudo 権限のある一般ユーザーで実行してください。"
  exit 1
fi

# ---------- バージョン設定 (必要に応じて変更) ----------
TERRAFORM_VERSION="1.10.5"
TERRAGRUNT_VERSION=""  # 空欄 = 最新版を自動取得
TELEPORT_VERSION="17"  # メジャーバージョン (aptリポジトリ用)

# ---------- 共通: パッケージ更新 & 基本ツール ----------
section "1. システム更新 & 基本パッケージ"
sudo apt-get update -y
sudo apt-get install -y \
  curl wget git unzip jq tree make gcc g++ \
  ca-certificates gnupg lsb-release \
  software-properties-common apt-transport-https \
  python3 python3-pip python3-venv python3-full \
  bash-completion direnv

info "基本パッケージ完了"

#===============================================================================
# SSH 関連
#===============================================================================
section "2. SSH 関連"

# OpenSSH (通常プリインストール)
sudo apt-get install -y openssh-client openssh-server
info "OpenSSH インストール完了"

# keychain (ssh-agent セッション再利用)
sudo apt-get install -y keychain
info "keychain インストール完了"

# ssh-audit (SSH設定の監査ツール)
if ! command -v ssh-audit &>/dev/null; then
  pip3 install ssh-audit --break-system-packages 2>/dev/null || pip3 install ssh-audit
  info "ssh-audit インストール完了"
else
  info "ssh-audit 既にインストール済み"
fi

#===============================================================================
# Infrastructure as Code
#===============================================================================
section "3. Infrastructure as Code"

# --- Terraform ---
if ! command -v terraform &>/dev/null; then
  wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    -O /tmp/terraform.zip
  sudo unzip -o /tmp/terraform.zip -d /usr/local/bin/
  rm /tmp/terraform.zip
  info "Terraform ${TERRAFORM_VERSION} インストール完了"
else
  info "Terraform 既にインストール済み: $(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1)"
fi

# --- Terraform関連ツール ---
# tflint (Terraform linter)
if ! command -v tflint &>/dev/null; then
  curl -sL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
  info "tflint インストール完了"
else
  info "tflint 既にインストール済み"
fi

# tfsec → trivy に統合済み (後述のセキュリティセクション参照)

# terraform-docs (ドキュメント自動生成)
if ! command -v terraform-docs &>/dev/null; then
  TFDOCS_VERSION=$(curl -s https://api.github.com/repos/terraform-docs/terraform-docs/releases/latest | jq -r '.tag_name')
  curl -sLo /tmp/terraform-docs.tar.gz \
    "https://github.com/terraform-docs/terraform-docs/releases/download/${TFDOCS_VERSION}/terraform-docs-${TFDOCS_VERSION}-linux-amd64.tar.gz"
  tar -xzf /tmp/terraform-docs.tar.gz -C /tmp/ terraform-docs
  sudo mv /tmp/terraform-docs /usr/local/bin/
  rm /tmp/terraform-docs.tar.gz
  info "terraform-docs インストール完了"
else
  info "terraform-docs 既にインストール済み"
fi

# --- Terragrunt ---
if ! command -v terragrunt &>/dev/null; then
  if [[ -n "$TERRAGRUNT_VERSION" ]]; then
    TG_VER="$TERRAGRUNT_VERSION"
  else
    TG_VER=$(curl -s https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest | jq -r '.tag_name' | tr -d 'v')
  fi
  curl -sLo /tmp/terragrunt \
    "https://github.com/gruntwork-io/terragrunt/releases/download/v${TG_VER}/terragrunt_linux_amd64"
  sudo install -m 0755 /tmp/terragrunt /usr/local/bin/terragrunt
  rm /tmp/terragrunt
  info "Terragrunt ${TG_VER} インストール完了"
else
  info "Terragrunt 既にインストール済み: $(terragrunt --version 2>/dev/null | head -1)"
fi

# --- Ansible ---
if ! command -v ansible &>/dev/null; then
  sudo apt-get install -y pipx
  pipx install --include-deps ansible
  pipx ensurepath
  info "Ansible インストール完了 (pipx)"
else
  info "Ansible 既にインストール済み: $(ansible --version | head -1)"
fi

# Ansible に boto3/botocore を追加 (AWS SSM 接続プラグインに必要)
if command -v ansible &>/dev/null; then
  if ! pipx runpip ansible show boto3 &>/dev/null 2>&1; then
    pipx inject ansible boto3 botocore
    info "boto3/botocore を Ansible 環境に追加完了 (SSM 接続用)"
  else
    info "boto3 は Ansible 環境に既にインストール済み"
  fi
fi

# ansible-lint
if ! command -v ansible-lint &>/dev/null; then
  pipx install ansible-lint
  info "ansible-lint インストール完了"
else
  info "ansible-lint 既にインストール済み"
fi

#===============================================================================
# コンテナ & クラウド CLI
#===============================================================================
section "4. コンテナ & クラウド CLI"

# --- Docker ---
# WSL2 では Docker Desktop (Windows側) を使用するため無効化
# if ! command -v docker &>/dev/null; then
#   curl -fsSL https://get.docker.com | sudo sh
#   sudo usermod -aG docker "$USER"
#   info "Docker インストール完了 (次回ログインで docker グループ有効)"
# else
#   info "Docker 既にインストール済み: $(docker --version)"
# fi
warn "Docker: WSL2 では Docker Desktop の WSL Integration を使用してください"

# --- AWS CLI v2 ---
if ! command -v aws &>/dev/null; then
  curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -qo /tmp/awscliv2.zip -d /tmp/
  sudo /tmp/aws/install
  rm -rf /tmp/awscliv2.zip /tmp/aws
  info "AWS CLI v2 インストール完了"
else
  info "AWS CLI 既にインストール済み: $(aws --version 2>&1 | head -1)"
fi

# --- AWS Session Manager Plugin ---
if ! command -v session-manager-plugin &>/dev/null; then
  curl -sL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
    -o /tmp/session-manager-plugin.deb
  sudo dpkg -i /tmp/session-manager-plugin.deb || sudo apt-get install -f -y
  rm /tmp/session-manager-plugin.deb
  info "AWS SSM Plugin インストール完了"
else
  info "AWS SSM Plugin 既にインストール済み"
fi

# #===============================================================================
# # リモートアクセス
# #===============================================================================
# section "5. リモートアクセス (Teleport)"

# if ! command -v tsh &>/dev/null; then
#   # Teleport公式リポジトリ追加
#   sudo curl -fsSL https://apt.releases.teleport.dev/gpg \
#     -o /usr/share/keyrings/teleport-archive-keyring.asc
#   echo "deb [signed-by=/usr/share/keyrings/teleport-archive-keyring.asc] \
#     https://apt.releases.teleport.dev/$(lsb_release -cs) stable/v${TELEPORT_VERSION}" \
#     | sudo tee /etc/apt/sources.list.d/teleport.list > /dev/null
#   sudo apt-get update -y
#   sudo apt-get install -y teleport
#   info "Teleport v${TELEPORT_VERSION} (tsh / tctl / tbot) インストール完了"
# else
#   info "Teleport 既にインストール済み: $(tsh version 2>/dev/null || echo 'installed')"
# fi

#===============================================================================
# Git & GitHub 関連
#===============================================================================
section "6. Git & GitHub"

# --- GitHub CLI (gh) ---
if ! command -v gh &>/dev/null; then
  (type -p wget >/dev/null || sudo apt-get install wget -y) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt-get update -y \
    && sudo apt-get install gh -y
  info "GitHub CLI (gh) インストール完了"
else
  info "GitHub CLI 既にインストール済み: $(gh --version | head -1)"
fi

# --- Git関連ツール ---
sudo apt-get install -y git-lfs
git lfs install --system 2>/dev/null || true
info "git-lfs インストール完了"

# pre-commit
if ! command -v pre-commit &>/dev/null; then
  pipx install pre-commit 2>/dev/null || pip3 install pre-commit --break-system-packages
  info "pre-commit インストール完了"
else
  info "pre-commit 既にインストール済み"
fi

# ghq (リポジトリ管理)
if ! command -v ghq &>/dev/null; then
  GHQ_VERSION=$(curl -s https://api.github.com/repos/x-motemen/ghq/releases/latest | jq -r '.tag_name' | tr -d 'v')
  wget -q "https://github.com/x-motemen/ghq/releases/download/v${GHQ_VERSION}/ghq_linux_amd64.zip" \
    -O /tmp/ghq.zip
  unzip -o /tmp/ghq.zip -d /tmp/ghq
  sudo mv /tmp/ghq/ghq_linux_amd64/ghq /usr/local/bin/
  rm -rf /tmp/ghq.zip /tmp/ghq
  info "ghq インストール完了"
else
  info "ghq 既にインストール済み"
fi

#===============================================================================
# AI CLI ツール
#===============================================================================
section "7. AI CLI ツール"

# --- Node.js (AI CLIの前提) ---
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
  info "Node.js $(node --version) インストール完了"
else
  info "Node.js 既にインストール済み: $(node --version)"
fi

# --- Claude Code (Anthropic) ---
if ! command -v claude &>/dev/null; then
  sudo npm install -g @anthropic-ai/claude-code
  info "Claude Code インストール完了"
else
  info "Claude Code 既にインストール済み"
fi

# --- Gemini CLI (Google) --- 無効化
# if ! command -v gemini &>/dev/null; then
#   sudo npm install -g @google/gemini-cli
#   info "Gemini CLI インストール完了"
# else
#   info "Gemini CLI 既にインストール済み"
# fi

# --- GitHub Copilot CLI ---
# gh extension
if ! gh extension list 2>/dev/null | grep -q copilot; then
  gh extension install github/gh-copilot 2>/dev/null || warn "GitHub Copilot CLI: gh auth login 後に再実行してください"
else
  info "GitHub Copilot CLI 既にインストール済み"
fi

# --- aider (AI pair programming) ---
if ! command -v aider &>/dev/null; then
  pipx install aider-chat 2>/dev/null || pip3 install aider-chat --break-system-packages
  info "aider インストール完了"
else
  info "aider 既にインストール済み"
fi

# --- Amazon Q CLI (旧 CodeWhisperer CLI) ---
warn "Amazon Q CLI: 公式サイトから手動インストールを推奨 → https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line.html"

#===============================================================================
# モニタリング & Observability
#===============================================================================
section "8. モニタリング & Observability"

# --- Grafana Alloy (旧 Grafana Agent) ---
if ! command -v alloy &>/dev/null; then
  sudo mkdir -p /etc/apt/keyrings/
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    | sudo tee /etc/apt/sources.list.d/grafana.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y alloy
  info "Grafana Alloy インストール完了"
else
  info "Grafana Alloy 既にインストール済み"
fi

#===============================================================================
# セキュリティ & 静的解析
#===============================================================================
section "9. セキュリティ & 静的解析"

# --- Trivy (コンテナ/IaC脆弱性スキャン, tfsec統合) ---
if ! command -v trivy &>/dev/null; then
  sudo apt-get install -y wget apt-transport-https gnupg
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
    | sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y trivy
  info "Trivy インストール完了 (IaCスキャン: trivy config .)"
else
  info "Trivy 既にインストール済み"
fi

#===============================================================================
# 便利ツール
#===============================================================================
section "10. 便利ツール"

# --- fzf (ファジーファインダー) ---
if ! command -v fzf &>/dev/null; then
  sudo apt-get install -y fzf
  info "fzf インストール完了"
else
  info "fzf 既にインストール済み"
fi

# --- bat (catの高機能版) ---
if ! command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
  sudo apt-get install -y bat
  # Ubuntu では batcat としてインストールされる
  mkdir -p ~/.local/bin
  ln -sf /usr/bin/batcat ~/.local/bin/bat 2>/dev/null || true
  info "bat インストール完了 (batcat → bat エイリアス作成)"
else
  info "bat 既にインストール済み"
fi

# --- ripgrep (高速grep) ---
if ! command -v rg &>/dev/null; then
  sudo apt-get install -y ripgrep
  info "ripgrep インストール完了"
else
  info "ripgrep 既にインストール済み"
fi

# --- fd (高速find) ---
if ! command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  sudo apt-get install -y fd-find
  ln -sf /usr/bin/fdfind ~/.local/bin/fd 2>/dev/null || true
  info "fd インストール完了"
else
  info "fd 既にインストール済み"
fi

# --- yq (YAML/JSONプロセッサ) ---
if ! command -v yq &>/dev/null; then
  YQ_VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r '.tag_name')
  sudo wget -q "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    -O /usr/local/bin/yq
  sudo chmod +x /usr/local/bin/yq
  info "yq インストール完了"
else
  info "yq 既にインストール済み"
fi

# --- age (モダンな暗号化ツール - sopsと連携) ---
if ! command -v age &>/dev/null; then
  sudo apt-get install -y age
  info "age インストール完了"
else
  info "age 既にインストール済み"
fi

# --- sops (シークレット管理) ---
if ! command -v sops &>/dev/null; then
  SOPS_VERSION=$(curl -s https://api.github.com/repos/getsops/sops/releases/latest | jq -r '.tag_name')
  curl -sLo /tmp/sops "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64"
  sudo mv /tmp/sops /usr/local/bin/sops
  sudo chmod +x /usr/local/bin/sops
  info "sops インストール完了 (Terraform/Ansible シークレット管理用)"
else
  info "sops 既にインストール済み"
fi

#===============================================================================
# シェル設定 (プロンプト)
#===============================================================================
section "11. シェル設定"

# --- カスタムプロンプト (.bashrc) ---
# 終了コード表示 + タイムスタンプ + 改行プロンプト
PROMPT_MARKER_BEGIN="# >>> prompt-config >>>"
PROMPT_MARKER_END="# <<< prompt-config <<<"

if ! grep -qF "$PROMPT_MARKER_BEGIN" ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc << 'PROMPT_BLOCK'

# >>> prompt-config >>>
# Custom prompt configuration for Bash
# Features:
#   - Red background on non-zero exit code
#   - Timestamp [yyyy-mm-dd HH:mm:ss] at end of first line
#   - Newline before command input

__prompt_command() {
    local exit_code=$?
    local red_bg="\[\033[41m\]"
    local reset="\[\033[0m\]"
    local green="\[\033[01;32m\]"
    local blue="\[\033[01;34m\]"

    if [ $exit_code -ne 0 ]; then
        local error_indicator="${red_bg} $exit_code ${reset} "
    else
        local error_indicator=""
    fi

    PS1="${debian_chroot:+($debian_chroot)}${green}\u@\h${reset}:${blue}\w${reset}[\D{%Y-%m-%d %H:%M:%S}]\n${error_indicator}\$ "
}
PROMPT_COMMAND=__prompt_command
# <<< prompt-config <<<
PROMPT_BLOCK
  info "カスタムプロンプト設定を ~/.bashrc に追加"
else
  info "カスタムプロンプト設定は既に ~/.bashrc に存在"
fi

#===============================================================================
# インストール結果サマリ
#===============================================================================
section "インストール結果サマリ"

# PATHを再読み込み
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

declare -A TOOLS=(
  # カテゴリ: SSH
  ["ssh"]="ssh -V 2>&1 | head -1"
  ["ssh-audit"]="pip3 show ssh-audit 2>/dev/null | grep -i version | head -1 || echo 'not found'"
  ["keychain"]="keychain --version 2>&1 | grep -oP 'keychain \S+' || echo 'not found'"
  # カテゴリ: IaC
  ["terraform"]="terraform version 2>/dev/null | head -1 || echo 'not found'"
  ["tflint"]="tflint --version 2>/dev/null | head -1 || echo 'not found'"
  ["terraform-docs"]="terraform-docs version 2>/dev/null || echo 'not found'"
  ["terragrunt"]="terragrunt --version 2>/dev/null | head -1 || echo 'not found'"
  ["ansible"]="ansible --version 2>/dev/null | head -1 || echo 'not found'"
  ["ansible-lint"]="ansible-lint --version 2>/dev/null | head -1 || echo 'not found'"
  # カテゴリ: コンテナ & クラウド
  # ["docker"]="docker --version 2>/dev/null || echo 'not found'"
  ["aws"]="aws --version 2>/dev/null || echo 'not found'"
  ["ssm-plugin"]="session-manager-plugin --version 2>/dev/null || echo 'not found'"
  # カテゴリ: リモートアクセス
  # ["tsh (Teleport)"]="tsh version 2>/dev/null || echo 'not found'"
  # カテゴリ: Git & GitHub
  ["git"]="git --version 2>/dev/null || echo 'not found'"
  ["gh"]="gh --version 2>/dev/null | head -1 || echo 'not found'"
  ["git-lfs"]="git lfs version 2>/dev/null || echo 'not found'"
  ["pre-commit"]="pre-commit --version 2>/dev/null || echo 'not found'"
  ["ghq"]="ghq --version 2>/dev/null || echo 'not found'"
  # カテゴリ: AI CLI
  ["claude"]="claude --version 2>/dev/null || echo 'not found'"
  # ["gemini"]="gemini --version 2>/dev/null || echo 'not found'"
  ["aider"]="aider --version 2>/dev/null | head -1 || echo 'not found'"
  # カテゴリ: モニタリング
  ["alloy"]="alloy --version 2>/dev/null | head -1 || echo 'not found'"
  # カテゴリ: セキュリティ
  ["trivy"]="trivy --version 2>/dev/null | head -1 || echo 'not found'"
  # カテゴリ: ユーティリティ
  ["jq"]="jq --version 2>/dev/null || echo 'not found'"
  ["yq"]="yq --version 2>/dev/null || echo 'not found'"
  ["fzf"]="fzf --version 2>/dev/null || echo 'not found'"
  ["bat"]="batcat --version 2>/dev/null | head -1 || bat --version 2>/dev/null | head -1 || echo 'not found'"
  ["ripgrep"]="rg --version 2>/dev/null | head -1 || echo 'not found'"
  ["fd"]="fdfind --version 2>/dev/null | head -1 || fd --version 2>/dev/null | head -1 || echo 'not found'"
  ["sops"]="sops --version --disable-version-check 2>/dev/null || echo 'not found'"
  ["age"]="age --version 2>/dev/null || echo 'not found'"
  ["direnv"]="direnv version 2>/dev/null || echo 'not found'"
  ["node"]="node --version 2>/dev/null || echo 'not found'"
)

echo ""
printf "%-20s %s\n" "ツール" "バージョン"
printf "%-20s %s\n" "────────────────────" "──────────────────────────────────"
while IFS= read -r tool; do
  version=$(eval "${TOOLS[$tool]}" 2>/dev/null | head -1 || true)
  [[ -z "$version" ]] && version="not found"
  printf "%-20s %s\n" "$tool" "$version"
done < <(printf '%s\n' "${!TOOLS[@]}" | sort)

#===============================================================================
# セットアップ後の手動設定リマインダー
#===============================================================================
section "次のステップ (手動設定)"

cat << 'REMINDER'
┌─────────────────────────────────────────────────────────────────┐
│ 以下は手動で設定してください:                                   │
│                                                                 │
│ 1. SSH鍵生成 (Ed25519推奨)                                      │
│    ssh-keygen -t ed25519 -C "your@email.com"                    │
│                                                                 │
│ 2. GitHub CLI 認証                                              │
│    gh auth login                                                │
│                                                                 │
│ 3. AWS CLI 設定                                                 │
│    aws configure                                                │
│    (または ~/.aws/credentials にプロファイル設定)               │
│                                                                 │
│ 4. AI CLI の APIキー設定                                         │
│    export ANTHROPIC_API_KEY="sk-ant-..."  # Claude Code         │
│    export OPENAI_API_KEY="sk-..."         # aider等             │
│                                                                 │
│ 5. Grafana Cloud トークン設定                                    │
│    → alloy の設定ファイルに記載                                 │
│                                                                 │
│ 6. 1Password SSH Agent (Windows側)                              │
│    → WSLの ~/.ssh/config に IdentityAgent 設定                  │
│                                                                 │
│ 7. direnv フック追加                                             │
│    echo 'eval "$(direnv hook bash)"' >> ~/.bashrc               │
│                                                                 │
│ 8. シェル再起動                                                  │
│    exec $SHELL -l                                               │
└─────────────────────────────────────────────────────────────────┘
REMINDER

info "セットアップ完了！ シェルを再起動してください: exec \$SHELL -l"
