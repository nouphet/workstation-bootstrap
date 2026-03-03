#Requires -Version 5.1
#===============================================================================
# setup-devtools.ps1
# Windows 11 インフラ自動化・AI CLI・開発ツール 一括セットアップ (winget ベース)
#
# 実行方法:
#   1. PowerShell を管理者として起動
#   2. Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   3. .\setup-devtools.ps1
#===============================================================================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ---------- 色付きログ ----------
function Write-Info    { param($msg) Write-Host "[✓] $msg" -ForegroundColor Green }
function Write-Warn    { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err     { param($msg) Write-Host "[✗] $msg" -ForegroundColor Red }
function Write-Section { param($msg) Write-Host "`n━━━ $msg ━━━" -ForegroundColor Cyan }

# ---------- 前提チェック ----------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Err "管理者権限で実行してください (右クリック → 管理者として実行)"
    exit 1
}

# winget 存在チェック
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Err "winget が見つかりません。Microsoft Store から 'アプリ インストーラー' を更新してください。"
    exit 1
}

# ---------- winget ヘルパー ----------
function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name,
        [string]$Source = "winget",
        [string]$Override = ""
    )

    # インストール済みチェック
    $installed = winget list --id $Id --accept-source-agreements 2>&1
    if ($installed -match $Id) {
        Write-Info "$Name 既にインストール済み"
        return
    }

    Write-Host "    $Name をインストール中..." -ForegroundColor Gray
    $args = @("install", "--id", $Id, "--source", $Source, "--accept-package-agreements", "--accept-source-agreements", "--silent")
    if ($Override -ne "") {
        $args += @("--override", $Override)
    }
    & winget @args
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
        # -1978335189 = already installed (race condition)
        Write-Info "$Name インストール完了"
    }
    else {
        Write-Warn "$Name インストールに問題が発生した可能性があります (exit: $LASTEXITCODE)"
    }
}

#===============================================================================
# 1. Git & GitHub
#===============================================================================
Write-Section "1. Git & GitHub"

Install-WingetPackage -Id "Git.Git"             -Name "Git"
Install-WingetPackage -Id "GitHub.cli"          -Name "GitHub CLI (gh)"
Install-WingetPackage -Id "GitHub.GitLFS"       -Name "Git LFS"
Install-WingetPackage -Id "GitHub.GitHubDesktop" -Name "GitHub Desktop"

#===============================================================================
# 2. SSH & リモートアクセス
#===============================================================================
Write-Section "2. SSH & リモートアクセス"

# OpenSSH Client (Windows 標準機能の有効化)
$sshCapability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
if ($sshCapability.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name 'OpenSSH.Client~~~~0.0.1.0'
    Write-Info "OpenSSH Client 有効化完了"
}
else {
    Write-Info "OpenSSH Client 既に有効"
}

# 1Password (SSH Agent 統合用)
Install-WingetPackage -Id "AgileBits.1Password" -Name "1Password (SSH Agent)"

# Teleport (tsh)
Install-WingetPackage -Id "Gravitational.Teleport" -Name "Teleport (tsh)"

#===============================================================================
# 3. Infrastructure as Code
#===============================================================================
Write-Section "3. Infrastructure as Code"

Install-WingetPackage -Id "Hashicorp.Terraform" -Name "Terraform"

# tflint
if (-not (Get-Command tflint -ErrorAction SilentlyContinue)) {
    Write-Host "    tflint をインストール中..." -ForegroundColor Gray
    $tflintUrl = (Invoke-RestMethod "https://api.github.com/repos/terraform-linters/tflint/releases/latest").assets |
        Where-Object { $_.name -match "windows_amd64.zip" } |
        Select-Object -First 1 -ExpandProperty browser_download_url
    $tflintZip = "$env:TEMP\tflint.zip"
    $tflintDir = "$env:ProgramFiles\tflint"
    Invoke-WebRequest -Uri $tflintUrl -OutFile $tflintZip
    New-Item -ItemType Directory -Path $tflintDir -Force | Out-Null
    Expand-Archive -Path $tflintZip -DestinationPath $tflintDir -Force
    Remove-Item $tflintZip
    # PATH追加
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($machinePath -notlike "*$tflintDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$machinePath;$tflintDir", "Machine")
    }
    Write-Info "tflint インストール完了"
}
else {
    Write-Info "tflint 既にインストール済み"
}

# terraform-docs
if (-not (Get-Command terraform-docs -ErrorAction SilentlyContinue)) {
    Write-Host "    terraform-docs をインストール中..." -ForegroundColor Gray
    $tfdocsUrl = (Invoke-RestMethod "https://api.github.com/repos/terraform-docs/terraform-docs/releases/latest").assets |
        Where-Object { $_.name -match "windows-amd64.zip" } |
        Select-Object -First 1 -ExpandProperty browser_download_url
    $tfdocsZip = "$env:TEMP\terraform-docs.zip"
    $tfdocsDir = "$env:ProgramFiles\terraform-docs"
    Invoke-WebRequest -Uri $tfdocsUrl -OutFile $tfdocsZip
    New-Item -ItemType Directory -Path $tfdocsDir -Force | Out-Null
    Expand-Archive -Path $tfdocsZip -DestinationPath $tfdocsDir -Force
    Remove-Item $tfdocsZip
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($machinePath -notlike "*$tfdocsDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$machinePath;$tfdocsDir", "Machine")
    }
    Write-Info "terraform-docs インストール完了"
}
else {
    Write-Info "terraform-docs 既にインストール済み"
}

# Ansible は WSL 側で使用 (Windows ネイティブ非対応)
Write-Warn "Ansible: Windows ネイティブ非対応 → WSL 側のスクリプトでインストール済み"

#===============================================================================
# 4. コンテナ & クラウド CLI
#===============================================================================
Write-Section "4. コンテナ & クラウド CLI"

Install-WingetPackage -Id "Docker.DockerDesktop"   -Name "Docker Desktop"
Install-WingetPackage -Id "Amazon.AWSCLI"          -Name "AWS CLI v2"
Install-WingetPackage -Id "Amazon.SessionManagerPlugin" -Name "AWS SSM Plugin"

#===============================================================================
# 5. ランタイム & パッケージマネージャー
#===============================================================================
Write-Section "5. ランタイム & パッケージマネージャー"

Install-WingetPackage -Id "OpenJS.NodeJS.LTS"  -Name "Node.js LTS"
Install-WingetPackage -Id "Python.Python.3.12" -Name "Python 3.12"

# pipx (Python CLIツール管理)
if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
    Write-Host "    pipx をインストール中..." -ForegroundColor Gray
    pip install --user pipx 2>$null
    python -m pipx ensurepath 2>$null
    Write-Info "pipx インストール完了"
}
else {
    Write-Info "pipx 既にインストール済み"
}

#===============================================================================
# 6. AI CLI ツール
#===============================================================================
Write-Section "6. AI CLI ツール"

# Claude Code
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "    Claude Code をインストール中..." -ForegroundColor Gray
    npm install -g @anthropic-ai/claude-code 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "Claude Code インストール完了"
    }
    else {
        Write-Warn "Claude Code: npm のPATH反映後に再試行 → npm install -g @anthropic-ai/claude-code"
    }
}
else {
    Write-Info "Claude Code 既にインストール済み"
}

# Gemini CLI
if (-not (Get-Command gemini -ErrorAction SilentlyContinue)) {
    Write-Host "    Gemini CLI をインストール中..." -ForegroundColor Gray
    npm install -g @google/gemini-cli 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "Gemini CLI インストール完了"
    }
    else {
        Write-Warn "Gemini CLI: npm のPATH反映後に再試行 → npm install -g @google/gemini-cli"
    }
}
else {
    Write-Info "Gemini CLI 既にインストール済み"
}

# GitHub Copilot CLI (gh extension)
$copilotInstalled = gh extension list 2>$null | Select-String "copilot"
if (-not $copilotInstalled) {
    Write-Host "    GitHub Copilot CLI をインストール中..." -ForegroundColor Gray
    gh extension install github/gh-copilot 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "GitHub Copilot CLI インストール完了"
    }
    else {
        Write-Warn "GitHub Copilot CLI: gh auth login 後に再実行してください"
    }
}
else {
    Write-Info "GitHub Copilot CLI 既にインストール済み"
}

# aider
if (-not (Get-Command aider -ErrorAction SilentlyContinue)) {
    Write-Host "    aider をインストール中..." -ForegroundColor Gray
    pipx install aider-chat 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "aider インストール完了"
    }
    else {
        pip install aider-chat 2>$null
        Write-Info "aider インストール完了 (pip)"
    }
}
else {
    Write-Info "aider 既にインストール済み"
}

#===============================================================================
# 7. セキュリティ & 静的解析
#===============================================================================
Write-Section "7. セキュリティ & 静的解析"

# Trivy
if (-not (Get-Command trivy -ErrorAction SilentlyContinue)) {
    Write-Host "    Trivy をインストール中..." -ForegroundColor Gray
    $trivyUrl = (Invoke-RestMethod "https://api.github.com/repos/aquasecurity/trivy/releases/latest").assets |
        Where-Object { $_.name -match "Windows-64bit.zip$" } |
        Select-Object -First 1 -ExpandProperty browser_download_url
    if ($trivyUrl) {
        $trivyZip = "$env:TEMP\trivy.zip"
        $trivyDir = "$env:ProgramFiles\trivy"
        Invoke-WebRequest -Uri $trivyUrl -OutFile $trivyZip
        New-Item -ItemType Directory -Path $trivyDir -Force | Out-Null
        Expand-Archive -Path $trivyZip -DestinationPath $trivyDir -Force
        Remove-Item $trivyZip
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($machinePath -notlike "*$trivyDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$machinePath;$trivyDir", "Machine")
        }
        Write-Info "Trivy インストール完了"
    }
    else {
        Write-Warn "Trivy: ダウンロードURL取得失敗。手動インストールしてください。"
    }
}
else {
    Write-Info "Trivy 既にインストール済み"
}

# sops
Install-WingetPackage -Id "Mozilla.sops" -Name "sops (シークレット管理)"

# age
if (-not (Get-Command age -ErrorAction SilentlyContinue)) {
    Write-Host "    age をインストール中..." -ForegroundColor Gray
    $ageUrl = (Invoke-RestMethod "https://api.github.com/repos/FiloSottile/age/releases/latest").assets |
        Where-Object { $_.name -match "windows-amd64.zip$" } |
        Select-Object -First 1 -ExpandProperty browser_download_url
    if ($ageUrl) {
        $ageZip = "$env:TEMP\age.zip"
        $ageDir = "$env:ProgramFiles\age"
        Invoke-WebRequest -Uri $ageUrl -OutFile $ageZip
        New-Item -ItemType Directory -Path $ageDir -Force | Out-Null
        Expand-Archive -Path $ageZip -DestinationPath $ageDir -Force
        # age は zip 内にサブフォルダがあるため
        $ageExe = Get-ChildItem -Path $ageDir -Recurse -Filter "age.exe" | Select-Object -First 1
        if ($ageExe) {
            $ageExeDir = $ageExe.DirectoryName
            $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($machinePath -notlike "*$ageExeDir*") {
                [Environment]::SetEnvironmentVariable("Path", "$machinePath;$ageExeDir", "Machine")
            }
        }
        Remove-Item $ageZip
        Write-Info "age インストール完了"
    }
    else {
        Write-Warn "age: ダウンロードURL取得失敗。手動インストールしてください。"
    }
}
else {
    Write-Info "age 既にインストール済み"
}

#===============================================================================
# 8. エディタ & ターミナル
#===============================================================================
Write-Section "8. エディタ & ターミナル"

Install-WingetPackage -Id "Microsoft.VisualStudioCode" -Name "VS Code"
Install-WingetPackage -Id "Microsoft.WindowsTerminal"  -Name "Windows Terminal"

#===============================================================================
# 9. 便利ツール
#===============================================================================
Write-Section "9. 便利ツール"

Install-WingetPackage -Id "stedolan.jq"          -Name "jq"
Install-WingetPackage -Id "MikeFarah.yq"         -Name "yq"
Install-WingetPackage -Id "junegunn.fzf"         -Name "fzf"
Install-WingetPackage -Id "sharkdp.bat"          -Name "bat (cat拡張)"
Install-WingetPackage -Id "BurntSushi.ripgrep.MSVC" -Name "ripgrep (rg)"
Install-WingetPackage -Id "sharkdp.fd"           -Name "fd (find拡張)"
Install-WingetPackage -Id "Schniz.fnm"           -Name "fnm (Node.jsバージョン管理)"
Install-WingetPackage -Id "WinSCP.WinSCP"        -Name "WinSCP"

#===============================================================================
# 10. WSL 統合
#===============================================================================
Write-Section "10. WSL 統合"

$wslInstalled = wsl --list --quiet 2>$null
if (-not $wslInstalled) {
    Write-Warn "WSL が未インストールです。以下で有効化できます:"
    Write-Warn "  wsl --install -d Ubuntu-24.04"
}
else {
    Write-Info "WSL インストール済み"
    wsl --list --verbose 2>$null
}

#===============================================================================
# インストール結果サマリ
#===============================================================================
Write-Section "インストール結果サマリ"

# 現在のセッションの PATH をリフレッシュ
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

$tools = [ordered]@{
    "git"            = { git --version 2>$null }
    "gh"             = { gh --version 2>$null | Select-Object -First 1 }
    "ssh"            = { ssh -V 2>&1 | Select-Object -First 1 }
    "terraform"      = { terraform version 2>$null | Select-Object -First 1 }
    "tflint"         = { tflint --version 2>$null | Select-Object -First 1 }
    "terraform-docs" = { terraform-docs version 2>$null }
    "docker"         = { docker --version 2>$null }
    "aws"            = { aws --version 2>$null }
    "tsh (Teleport)" = { tsh version 2>$null }
    "node"           = { node --version 2>$null }
    "python"         = { python --version 2>$null }
    "claude"         = { claude --version 2>$null }
    "gemini"         = { gemini --version 2>$null }
    "aider"          = { aider --version 2>$null | Select-Object -First 1 }
    "trivy"          = { trivy --version 2>$null | Select-Object -First 1 }
    "sops"           = { sops --version 2>$null }
    "age"            = { age --version 2>$null }
    "jq"             = { jq --version 2>$null }
    "yq"             = { yq --version 2>$null }
    "fzf"            = { fzf --version 2>$null }
    "bat"            = { bat --version 2>$null | Select-Object -First 1 }
    "rg"             = { rg --version 2>$null | Select-Object -First 1 }
    "fd"             = { fd --version 2>$null }
    "code (VS Code)" = { code --version 2>$null | Select-Object -First 1 }
}

Write-Host ""
Write-Host ("{0,-20} {1}" -f "ツール", "バージョン") -ForegroundColor White
Write-Host ("{0,-20} {1}" -f ("─" * 20), ("─" * 40)) -ForegroundColor DarkGray

foreach ($entry in $tools.GetEnumerator()) {
    try {
        $ver = (& $entry.Value) 2>$null
        if ($ver) {
            $verStr = ($ver | Out-String).Trim().Split("`n")[0]
        }
        else {
            $verStr = "not found (PATH再読み込み後に再確認)"
        }
    }
    catch {
        $verStr = "not found"
    }
    Write-Host ("{0,-20} {1}" -f $entry.Key, $verStr)
}

#===============================================================================
# セットアップ後の手動設定リマインダー
#===============================================================================
Write-Section "次のステップ (手動設定)"

$reminder = @"
┌──────────────────────────────────────────────────────────────────────┐
│ 以下は手動で設定してください:                                        │
│                                                                      │
│  1. SSH 鍵生成 (Ed25519推奨)                                         │
│     ssh-keygen -t ed25519 -C "your@email.com"                        │
│                                                                      │
│  2. 1Password SSH Agent 有効化                                       │
│     1Password → 設定 → 開発者 → SSH Agent をオン                    │
│     ~/.ssh/config に IdentityAgent 設定を追加                        │
│                                                                      │
│  3. GitHub CLI 認証                                                  │
│     gh auth login                                                    │
│                                                                      │
│  4. AWS CLI 設定                                                     │
│     aws configure                                                    │
│                                                                      │
│  5. Teleport クラスタ接続                                            │
│     tsh login --proxy=<your-cluster>:443                             │
│                                                                      │
│  6. AI CLI の APIキー設定                                             │
│     $env:ANTHROPIC_API_KEY = "sk-ant-..."   # Claude Code           │
│     $env:OPENAI_API_KEY    = "sk-..."        # aider等              │
│     ※ 永続化は [Environment]::SetEnvironmentVariable() で           │
│                                                                      │
│  7. Docker Desktop                                                   │
│     → WSL2 バックエンド有効化 & リソース割り当て調整                │
│                                                                      │
│  8. VS Code 拡張機能 (推奨)                                          │
│     code --install-extension hashicorp.terraform                     │
│     code --install-extension ms-vscode-remote.remote-wsl             │
│     code --install-extension github.copilot                          │
│     code --install-extension ms-python.python                        │
│                                                                      │
│  9. ターミナル再起動                                                  │
│     PATH 変更を反映するためにターミナルを再起動してください          │
└──────────────────────────────────────────────────────────────────────┘
"@

Write-Host $reminder

Write-Info "セットアップ完了！ ターミナルを再起動してください。"
