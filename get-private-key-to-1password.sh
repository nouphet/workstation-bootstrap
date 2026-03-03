# 1. SSH Keyテンプレートを生成
op item template get "SSH Key" > /tmp/ssh_key_template.json

# 2. テンプレートを編集して秘密鍵を埋め込む
cat > /tmp/ssh_key_import.json <<'EOF'
{
  "title": "WSL SSH Key | GeekFeed PC GM180QAE",
  "category": "SSH_KEY",
  "fields": [
    {
      "id": "private_key",
      "type": "CONCEALED",
      "purpose": "NOTES",
      "label": "private key",
      "value": "PRIVATE_KEY_PLACEHOLDER"
    },
    {
      "id": "public_key",
      "type": "STRING",
      "label": "public key",
      "value": "PUBLIC_KEY_PLACEHOLDER"
    }
  ]
}
EOF

# 3. プレースホルダーを実際の鍵で置換
PRIVATE_KEY=$(cat ~/.ssh/id_ed25519 | jq -sR .)
PUBLIC_KEY=$(cat ~/.ssh/id_ed25519.pub | jq -sR .)

jq --argjson priv "$PRIVATE_KEY" --argjson pub "$PUBLIC_KEY" \
  '(.fields[] | select(.id == "private_key") | .value) = $priv | 
   (.fields[] | select(.id == "public_key") | .value) = $pub' \
  /tmp/ssh_key_import.json > /tmp/ssh_key_final.json

# 4. 1Passwordに登録
op item create --template /tmp/ssh_key_final.json

# 5. 一時ファイル削除
rm /tmp/ssh_key_*.json
