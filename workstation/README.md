# workstation - Ansible ワークステーションセットアップ

WSL2 Ubuntu (22.04 / 24.04) 向けの開発環境を Ansible で一括セットアップする。

元の `setup-devtools.sh` を Ansible ロールに移植したもの。

## 前提条件

Ansible 自体は事前にシェルで入れておく (bootstrap):

```bash
sudo apt update && sudo apt install -y pipx
pipx install --include-deps ansible
pipx ensurepath
exec $SHELL -l
```

`community.general` コレクション (pipx, npm モジュール用):

```bash
ansible-galaxy collection install community.general
```

## 使い方

```bash
cd workstation

# 全ロール実行
ansible-playbook -i inventory.yml setup.yml --ask-become-pass

# ドライラン (変更せず確認のみ)
ansible-playbook -i inventory.yml setup.yml --ask-become-pass --check

# カテゴリ指定実行 (例: base と ssh だけ)
ansible-playbook -i inventory.yml setup.yml --ask-become-pass --tags "base,ssh"
```

### 利用可能なタグ

| タグ | 内容 |
|------|------|
| `base` | curl, jq, tree, python3, direnv, pipx 等の基本パッケージ |
| `ssh` | openssh, keychain, ssh-audit |
| `iac` | terraform, tflint, terraform-docs, terragrunt, ansible, ansible-lint |
| `cloud_cli` | AWS CLI v2, SSM Plugin |
| `git` | gh, git-lfs, pre-commit, ghq, gh-copilot |
| `ai_cli` | Node.js 22.x, Claude Code, aider |
| `security` | Trivy |
| `monitoring` | Grafana Alloy |
| `utils` | fzf, bat, ripgrep, fd, yq, sops, age |
| `shell_config` | .bashrc カスタムプロンプト設定 |

## ファイル構成

```
workstation/
├── README.md
├── inventory.yml              # localhost (connection: local)
├── setup.yml                  # メインPlaybook
└── roles/
    ├── base/tasks/main.yml
    ├── ssh/tasks/main.yml
    ├── iac/
    │   ├── defaults/main.yml        # terraform_version, terragrunt_version
    │   └── tasks/main.yml
    ├── cloud_cli/tasks/main.yml
    ├── git/tasks/main.yml
    ├── ai_cli/tasks/main.yml
    ├── security/tasks/main.yml
    ├── monitoring/tasks/main.yml
    ├── utils/tasks/main.yml
    └── shell_config/
        ├── defaults/main.yml        # マーカー文字列
        ├── templates/prompt-config.bash.j2
        └── tasks/main.yml
```

## 設計ポイント

### 冪等性

元スクリプトの `command -v` チェックを `ansible.builtin.command` + `register` + `when: rc != 0` で再現。
既にインストール済みのツールはスキップされる。

### インストールパターン

| パターン | 対象ツール |
|----------|-----------|
| apt パッケージ | curl, jq, fzf, bat, ripgrep, fd, age, openssh, keychain, git-lfs |
| apt リポジトリ追加 → apt | gh, trivy, alloy |
| バイナリ直接ダウンロード | terraform, terragrunt, terraform-docs, ghq, yq, sops |
| pipx | ansible, ansible-lint, pre-commit, aider |
| npm global | Claude Code |
| pip3 | ssh-audit |
| インストールスクリプト | tflint, Node.js (NodeSource) |

### バージョン管理

`iac/defaults/main.yml` で Terraform / Terragrunt のバージョンを指定可能。
Terragrunt は空文字にすると GitHub API から最新版を自動取得する。

### 移植対象外

元スクリプトでコメントアウト済みの以下は移植していない:

- Docker (WSL2 では Docker Desktop の WSL Integration を使用)
- Teleport
- Gemini CLI
- Amazon Q CLI (手動インストール推奨)
