# Workstation Bootstrap

[![GitHub](https://img.shields.io/badge/repo-workstation--bootstrap-blue?logo=github)](https://github.com/nouphet/workstation-bootstrap)

[日本語版 README はこちら](README_ja.md)

One-shot setup scripts for infrastructure automation, AI CLI, and developer tools.

```bash
git clone https://github.com/nouphet/workstation-bootstrap.git
cd workstation-bootstrap
```

## Scripts

| File | Target | How to run |
|---|---|---|
| `setup-devtools.sh` | Ubuntu 22.04 / 24.04 (incl. WSL2) | `chmod +x setup-devtools.sh && ./setup-devtools.sh` |
| `setup-devtools.ps1` | Windows 11 (PowerShell + winget) | Run as Administrator (see below) |

Both scripts are **idempotent** — already-installed tools are skipped, so it is safe to run them repeatedly. A version summary and manual-setup reminders are displayed on completion.

---

## Usage

### Linux / WSL

```bash
chmod +x setup-devtools.sh
./setup-devtools.sh
```

Run as a regular user with sudo privileges (do not run as root directly).

### Windows 11 (PowerShell)

**Step 1:** Open PowerShell **as Administrator** (right-click → Run as administrator)

**Step 2:** Temporarily relax the execution policy for the current session

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

> This only affects the current window. Closing the window reverts the policy.

**Step 3:** Run the script

```powershell
.\setup-devtools.ps1
```

#### About Execution Policy

Windows blocks script execution by default. To permanently allow scripts for the current user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

`RemoteSigned` requires downloaded scripts to be signed but allows locally created scripts to run freely — a common production setting.

---

## Installed Tools

### SSH & Remote Access

| Tool | Purpose | Linux | Windows |
|---|---|:---:|:---:|
| OpenSSH | SSH connectivity | ✅ | ✅ |
| ssh-audit | SSH server/client configuration audit | ✅ | - |
| 1Password | SSH Agent integration (key management) | - | ✅ |
| Teleport (tsh/tctl/tbot) | Zero-trust remote access platform | ✅ | ✅ |

### Infrastructure as Code

| Tool | Purpose | Linux | Windows |
|---|---|:---:|:---:|
| Terraform | Infrastructure definition & provisioning | ✅ | ✅ |
| Terragrunt | Terraform wrapper (multi-account / DRY) | ✅ | - |
| tflint | Terraform linter | ✅ | ✅ |
| terraform-docs | Auto-generate docs from Terraform code | ✅ | ✅ |
| Ansible | Configuration management & server automation | ✅ | - (*) |
| ansible-lint | Ansible playbook linter | ✅ | - (*) |

> (*) Ansible does not support Windows natively; install on WSL side only.

### Containers & Cloud CLI

| Tool | Purpose | Linux | Windows |
|---|---|:---:|:---:|
| Docker | Container management | ✅ | ✅ (Desktop) |
| AWS CLI v2 | AWS resource operations | ✅ | ✅ |
| AWS SSM Plugin | Session Manager server connectivity | ✅ | ✅ |

### Git & GitHub

| Tool | Purpose | Linux | Windows |
|---|---|:---:|:---:|
| Git | Version control | ✅ | ✅ |
| GitHub CLI (gh) | GitHub from the terminal | ✅ | ✅ |
| Git LFS | Large file storage for Git | ✅ | ✅ |
| GitHub Desktop | Git GUI client | - | ✅ |
| pre-commit | Automated checks on commit | ✅ | - |
| ghq | Local repository manager | ✅ | - |

### AI CLI

| Tool | Purpose | Linux | Windows |
|---|---|:---:|:---:|
| Claude Code | Anthropic AI coding assistant | ✅ | ✅ |
| Gemini CLI | Google AI coding assistant | ✅ | ✅ |
| GitHub Copilot CLI | gh extension AI assistant | ✅ | ✅ |
| aider | AI pair programming | ✅ | ✅ |

### Monitoring & Observability

| Tool | Purpose | Linux | Windows |
|---|---|:---:|:---:|
| Grafana Alloy | Log & metrics collection agent | ✅ | - |

### Security & Static Analysis

| Tool | Purpose | Linux | Windows |
|---|---|:---:|:---:|
| Trivy | Vulnerability scanning (container / IaC) | ✅ | ✅ |
| sops | Encrypted secret file management | ✅ | ✅ |
| age | Modern encryption engine (used with sops) | ✅ | ✅ |

### Editors & Terminals

| Tool | Purpose | Linux | Windows |
|---|---|:---:|:---:|
| VS Code | Code editor | - | ✅ |
| Windows Terminal | Modern terminal emulator | - | ✅ |

### Utilities

| Tool | Purpose | Linux | Windows |
|---|---|:---:|:---:|
| jq | JSON processor | ✅ | ✅ |
| yq | YAML processor | ✅ | ✅ |
| fzf | Fuzzy finder | ✅ | ✅ |
| bat | Syntax-highlighted cat | ✅ | ✅ |
| ripgrep (rg) | Fast grep | ✅ | ✅ |
| fd | Fast find | ✅ | ✅ |
| direnv | Per-directory environment variables | ✅ | - |
| fnm | Node.js version manager | - | ✅ |
| WinSCP | SCP/SFTP GUI client | - | ✅ |

---

## Post-Setup Manual Configuration

After running the script, complete the following steps manually.

### 1. Generate SSH key

```bash
ssh-keygen -t ed25519 -C "your@email.com"
```

### 2. 1Password SSH Agent (Windows)

Enable SSH Agent in 1Password → Settings → Developer, then configure `IdentityAgent` in WSL `~/.ssh/config`.

### 3. GitHub CLI authentication

```bash
gh auth login
```

### 4. AWS CLI configuration

```bash
aws configure
```

### 5. Teleport cluster login

```bash
tsh login --proxy=<your-cluster>:443
```

### 6. AI CLI API keys

```bash
# Linux / WSL (add to .bashrc)
export ANTHROPIC_API_KEY="sk-ant-..."   # Claude Code
export GEMINI_API_KEY="..."             # Gemini CLI
export OPENAI_API_KEY="sk-..."          # aider etc.
```

```powershell
# Windows (permanent)
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-ant-...", "User")
[Environment]::SetEnvironmentVariable("GEMINI_API_KEY", "...", "User")
[Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-...", "User")
```

### 7. direnv hook (Linux / WSL)

```bash
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
```

### 8. VS Code recommended extensions (Windows)

```powershell
code --install-extension hashicorp.terraform
code --install-extension ms-vscode-remote.remote-wsl
code --install-extension github.copilot
code --install-extension ms-python.python
```

### 9. Restart shell

```bash
exec $SHELL -l    # Linux / WSL
```

On Windows, restart PowerShell / Terminal.
