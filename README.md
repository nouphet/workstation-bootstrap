# 開発環境セットアップガイド

インフラ自動化・AI CLI・開発ツールを一括インストールするためのスクリプトと、各ツールの解説です。

## スクリプト一覧

| ファイル | 対象環境 | 実行方法 |
|---|---|---|
| `setup-devtools.sh` | Ubuntu 22.04 / 24.04 (WSL2含む) | `chmod +x setup-devtools.sh && ./setup-devtools.sh` |
| `setup-devtools.ps1` | Windows 11 (PowerShell + winget) | 管理者PowerShellで実行（後述） |

両スクリプトとも **冪等** に設計されています。既にインストール済みのツールはスキップされるため、何度実行しても安全です。実行後にバージョンサマリと手動設定のリマインダーが表示されます。

---

## 実行手順

### Linux / WSL

```bash
chmod +x setup-devtools.sh
./setup-devtools.sh
```

sudo 権限のある一般ユーザーで実行してください（root 直接実行は不可）。

### Windows 11 (PowerShell)

**手順1:** PowerShell を **管理者として** 起動する（右クリック → 管理者として実行）

**手順2:** 実行ポリシーを現在のセッションだけ緩める

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

> このコマンドは現在のウィンドウにのみ影響します。ウィンドウを閉じれば元に戻るため安全です。

**手順3:** スクリプトを実行する

```powershell
.\setup-devtools.ps1
```

#### 実行ポリシーについて

Windows は既定でスクリプト実行がブロックされています。毎回 `Bypass` を設定するのが面倒な場合は、ユーザー単位で恒久的に許可できます。

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

`RemoteSigned` はインターネットからダウンロードしたスクリプトには署名が必要、ローカルで作成したスクリプトはそのまま実行可能、というポリシーです。実運用上はこの設定が一般的です。

---

## インストールされるツール一覧

### SSH & リモートアクセス

| ツール | 用途 | Linux | Windows |
|---|---|:---:|:---:|
| OpenSSH | SSH 接続 | ✅ | ✅ |
| ssh-audit | SSH サーバー/クライアント設定の監査 | ✅ | - |
| 1Password | SSH Agent 統合（鍵管理） | - | ✅ |
| Teleport (tsh/tctl/tbot) | ゼロトラストのリモートアクセス基盤 | ✅ | ✅ |

### Infrastructure as Code

| ツール | 用途 | Linux | Windows |
|---|---|:---:|:---:|
| Terraform | インフラ定義・プロビジョニング | ✅ | ✅ |
| tflint | Terraform の Linter | ✅ | ✅ |
| terraform-docs | Terraform コードからドキュメント自動生成 | ✅ | ✅ |
| Ansible | 構成管理・サーバーセットアップの自動化 | ✅ | - (※) |
| ansible-lint | Ansible Playbook の Linter | ✅ | - (※) |

> ※ Ansible は Windows ネイティブ非対応のため WSL 側でのみインストールされます。

### コンテナ & クラウド CLI

| ツール | 用途 | Linux | Windows |
|---|---|:---:|:---:|
| Docker | コンテナ管理 | ✅ | ✅ (Desktop) |
| AWS CLI v2 | AWS リソース操作 | ✅ | ✅ |
| AWS SSM Plugin | Session Manager によるサーバー接続 | ✅ | ✅ |

### Git & GitHub

| ツール | 用途 | Linux | Windows |
|---|---|:---:|:---:|
| Git | バージョン管理 | ✅ | ✅ |
| GitHub CLI (gh) | GitHub 操作をターミナルから実行 | ✅ | ✅ |
| Git LFS | 大容量ファイルの Git 管理 | ✅ | ✅ |
| GitHub Desktop | Git GUI クライアント | - | ✅ |
| pre-commit | コミット時の自動チェック | ✅ | - |
| ghq | リポジトリのローカル管理 | ✅ | - |

### AI CLI

| ツール | 用途 | Linux | Windows |
|---|---|:---:|:---:|
| Claude Code | Anthropic の AI コーディングアシスタント | ✅ | ✅ |
| GitHub Copilot CLI | gh 拡張の AI アシスタント | ✅ | ✅ |
| aider | AI ペアプログラミング | ✅ | ✅ |

### モニタリング & Observability

| ツール | 用途 | Linux | Windows |
|---|---|:---:|:---:|
| Grafana Alloy | ログ・メトリクス収集エージェント | ✅ | - |

### セキュリティ & 静的解析

| ツール | 用途 | Linux | Windows |
|---|---|:---:|:---:|
| Trivy | 脆弱性スキャン（コンテナ / IaC） | ✅ | ✅ |
| sops | シークレットファイルの暗号化管理 | ✅ | ✅ |
| age | モダンな暗号化エンジン（sops と連携） | ✅ | ✅ |

### エディタ & ターミナル

| ツール | 用途 | Linux | Windows |
|---|---|:---:|:---:|
| VS Code | コードエディタ | - | ✅ |
| Windows Terminal | モダンなターミナル | - | ✅ |

### ユーティリティ

| ツール | 用途 | Linux | Windows |
|---|---|:---:|:---:|
| jq | JSON プロセッサ | ✅ | ✅ |
| yq | YAML プロセッサ | ✅ | ✅ |
| fzf | ファジーファインダー（あいまい検索） | ✅ | ✅ |
| bat | シンタックスハイライト付き cat | ✅ | ✅ |
| ripgrep (rg) | 高速 grep | ✅ | ✅ |
| fd | 高速 find | ✅ | ✅ |
| direnv | ディレクトリ単位の環境変数自動設定 | ✅ | - |
| fnm | Node.js バージョン管理 | - | ✅ |
| WinSCP | SCP/SFTP GUI クライアント | - | ✅ |

---

## 各ツール解説

なじみのないツールについて、実際の使用場面とともに解説します。

### Git LFS (Large File Storage)

大きなファイル（画像、動画、バイナリなど）を Git リポジトリで効率的に扱うための拡張です。通常の Git は大きなファイルの履歴をすべて保持するのでリポジトリが肥大化しますが、LFS はポインタだけをリポジトリに置き、実体を別ストレージに保管します。

ドキュメントにスクリーンショットを大量に含むリポジトリや、機械学習のモデルファイルを管理する場合に使います。普通のコードリポジトリだけなら不要です。

### ghq

リポジトリのローカル管理ツールです。`ghq get <repo-url>` とすると `~/ghq/github.com/org/repo` のようにホスト名・組織名・リポジトリ名のディレクトリ構造で自動的にクローンしてくれます。

fzf と組み合わせて `ghq list | fzf` でリポジトリを素早く切り替えるのが典型的な使い方です。複数リポジトリを扱うようになると便利ですが、数個程度なら手動の `git clone` で十分です。

### Trivy

脆弱性スキャナーです。コンテナイメージ、Terraform コード、Dockerfile などをスキャンして既知の脆弱性や設定ミスを検出します。

Terraform を書いた後に `trivy config .` を実行すると、「S3バケットの暗号化が無効」「セキュリティグループが 0.0.0.0/0 で開いている」のような問題をデプロイ前に発見できます。CI/CD に組み込むのが理想ですが、手元でのチェックにも使えます。

### sops + age

セットで使うシークレット管理ツールです。Terraform 変数や Ansible の設定には API キーやパスワードを含むことがありますが、それをそのまま Git に入れるわけにはいきません。

- **age** → 暗号化エンジン（鍵ペアの生成と暗復号）
- **sops** → age を使って YAML や JSON ファイルの「値だけ」を暗号化するツール

キー名はそのまま読めるので diff が効き、Git で安全に管理できるのがポイントです。

```yaml
# sops で暗号化済みの例（キー名はそのまま、値だけ暗号化）
db_password: ENC[AES256_GCM,data:xxxxx...]
api_key:     ENC[AES256_GCM,data:yyyyy...]
```

Terraform / Ansible のシークレットを安全に Git 管理したくなった段階で導入すればよく、最初はなくても問題ありません。

### yq

jq の YAML 版です。jq が JSON を加工するように、yq は YAML ファイルをコマンドラインで読み書きできます。

Ansible、Docker Compose、Kubernetes、Grafana Alloy の設定など YAML を扱う場面が多いため、値の取り出しや書き換えに使います。

```bash
# 設定ファイルから特定の値を取得
yq '.server.port' config.yaml

# 値を書き換え
yq -i '.server.port = 8080' config.yaml
```

### fzf

あいまい検索（ファジーファインダー）です。パイプで渡したリストをインタラクティブに絞り込めます。

インストール後すぐに **Ctrl+R のコマンド履歴検索** が置き換わるので、体感で一番便利さを感じやすいツールです。そのほか何にでも組み合わせられます。

```bash
# コマンド履歴をあいまい検索 (Ctrl+R)
# リポジトリを選んで移動
cd $(ghq list -p | fzf)
# Git ブランチを選択
git switch $(git branch | fzf)
```

### bat

`cat` の上位互換で、シンタックスハイライトと行番号付きでファイルを表示します。

```bash
bat main.tf        # Terraform コードが色付きで表示される
bat config.yaml    # YAML もハイライトされる
```

### ripgrep (rg)

`grep` の高速版です。デフォルトで `.gitignore` を尊重し、再帰検索が高速なので、プロジェクト内の文字列検索に使います。

```bash
# Terraform ファイル群から AMI ID を一括検索
rg "ami-" terraform/
# 特定の拡張子だけ検索
rg "password" -t yaml
```

### fd

`find` の高速版で、ripgrep と同様に `.gitignore` を尊重します。

```bash
# Terraform ファイルを一覧
fd "\.tf$"
# 特定ディレクトリ配下の YAML ファイルを探す
fd -e yaml ansible/
```

### fnm (Fast Node Manager)

Node.js のバージョン管理ツールです。プロジェクトごとに異なる Node.js バージョンが必要な場合に切り替えます。

```powershell
fnm install 22
fnm use 22
node --version  # v22.x.x
```

Node.js を一つのバージョンしか使わないなら不要です。

### direnv

ディレクトリごとに環境変数を自動設定するツールです。プロジェクトフォルダに `.envrc` ファイルを置いておくと、そのディレクトリに入った時に自動で環境変数がセットされ、出ると元に戻ります。

```bash
# ~/projects/youwire/.envrc
export AWS_PROFILE=youwire-prod
export TF_VAR_environment=production

# ディレクトリに入ると自動で反映される
cd ~/projects/youwire/    # → AWS_PROFILE=youwire-prod が有効
cd ~                      # → 元に戻る
```

Terraform 用の AWS プロファイル切り替えや API キーの設定を、プロジェクトごとに自動化するのに便利です。

---

## セットアップ後の手動設定

スクリプト実行後、以下の設定を手動で行ってください。

### 1. SSH 鍵生成

```bash
ssh-keygen -t ed25519 -C "your@email.com"
```

### 2. 1Password SSH Agent (Windows 側)

1Password → 設定 → 開発者 → SSH Agent をオンにし、WSL 側の `~/.ssh/config` に IdentityAgent を設定します。

### 3. GitHub CLI 認証

```bash
gh auth login
```

### 4. AWS CLI 設定

```bash
aws configure
```

### 5. Teleport クラスタ接続

```bash
tsh login --proxy=<your-cluster>:443
```

### 6. AI CLI の API キー設定

```bash
# Linux / WSL (.bashrc に追記)
export ANTHROPIC_API_KEY="sk-ant-..."   # Claude Code
export OPENAI_API_KEY="sk-..."          # aider 等
```

```powershell
# Windows (永続化)
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-ant-...", "User")
[Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-...", "User")
```

### 7. direnv フック追加 (Linux / WSL)

```bash
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
```

### 8. VS Code 推奨拡張機能 (Windows)

```powershell
code --install-extension hashicorp.terraform
code --install-extension ms-vscode-remote.remote-wsl
code --install-extension github.copilot
code --install-extension ms-python.python
```

### 9. シェル再起動

```bash
exec $SHELL -l    # Linux / WSL
```

Windows は PowerShell / ターミナルを再起動してください。
