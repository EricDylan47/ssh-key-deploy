#!/bin/bash

set -e

echo "=== SSH Public Key Import & Password Auth Disable ==="
echo

# 1. 输入用户名
read -r -p "请输入用户名（多个用空格隔开）: " -a USERS
if [[ ${#USERS[@]} -eq 0 ]] || [[ -z "${USERS[0]}" ]]; then
    echo "错误：未输入任何用户名"
    exit 1
fi

# 2. 输入公钥
read -r -p "请输入公钥: " PUBKEY
PUBKEY=$(echo "$PUBKEY" | tr -d '"' | tr -d "'")
if [[ -z "$PUBKEY" ]]; then
    echo "错误：未输入公钥"
    exit 1
fi

echo
echo "=== 将要为以下用户导入公钥 ==="
printf '%s\n' "${USERS[@]}"
echo

read -r -p "确认继续？(y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "已取消"
    exit 0
fi

# 3. 导入公钥到各用户
for USER in "${USERS[@]}"; do
    echo ">>> 处理用户: $USER"

    # 检查用户是否存在
    if ! id "$USER" &>/dev/null; then
        echo "    用户 $USER 不存在，跳过"
        continue
    fi

    # 获取用户家目录
    HOME_DIR=$(getent passwd "$USER" | cut -d: -f6)
    SSH_DIR="$HOME_DIR/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    # 创建 .ssh 目录
    if [[ ! -d "$SSH_DIR" ]]; then
        mkdir -p "$SSH_DIR"
        echo "    创建目录: $SSH_DIR"
    fi

    # 确认为用户所有
    chown "$USER:$USER" "$SSH_DIR"

    # 追加公钥（避免重复）
    if grep -qF "$PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
        echo "    公钥已存在，跳过"
    else
        echo "$PUBKEY" >> "$AUTH_KEYS"
        echo "    公钥已追加到 $AUTH_KEYS"
    fi

    # 设置权限
    chmod 700 "$SSH_DIR"
    chmod 600 "$AUTH_KEYS"
    chown "$USER:$USER" "$AUTH_KEYS"
    echo "    权限已设置 (700 for .ssh, 600 for authorized_keys)"
    echo
done

# 4. 禁用 SSH 密码认证
echo "=== 禁用 SSH 密码认证 ==="
SSHD_CONF="/etc/ssh/sshd_config"
SSHD_CONF_D="/etc/ssh/sshd_config.d"

disable_password_auth() {
    local CONF_FILE="$1"
    if [[ ! -f "$CONF_FILE" ]]; then
        return
    fi

    # 注释掉现有的 PasswordAuthentication
    sed -i 's/^PasswordAuthentication yes/#PasswordAuthentication yes/' "$CONF_FILE"
    sed -i 's/^#*PasswordAuthentication no/PasswordAuthentication no/' "$CONF_FILE"
    sed -i 's/^ChallengeResponseAuthentication yes/#ChallengeResponseAuthentication yes/' "$CONF_FILE"
    sed -i 's/^#*ChallengeResponseAuthentication no/ChallengeResponseAuthentication no/' "$CONF_FILE"
    sed -i 's/^KbdInteractiveAuthentication yes/#KbdInteractiveAuthentication yes/' "$CONF_FILE"
    sed -i 's/^#*KbdInteractiveAuthentication no/KbdInteractiveAuthentication no/' "$CONF_FILE"

    echo "    已更新: $CONF_FILE"
}

if [[ -d "$SSHD_CONF_D" ]]; then
    for f in "$SSHD_CONF_D"/*.conf; do
        disable_password_auth "$f"
    done
fi
disable_password_auth "$SSHD_CONF"

# 检查配置是否已正确设置
if grep -r "^PasswordAuthentication yes" "$SSHD_CONF" "$SSHD_CONF_D"/ 2>/dev/null | grep -v "^#"; then
    echo "    警告：仍有 PasswordAuthentication yes 未被禁用，请手动检查"
else
    echo "    密码认证已禁用"
fi

# 5. 重载 sshd 配置
if command -v systemctl &>/dev/null; then
    systemctl reload sshd 2>/dev/null && echo "    sshd 已重载 (systemctl)"
elif command -v service &>/dev/null; then
    service sshd reload 2>/dev/null && echo "    sshd 已重载 (service)"
else
    echo "    无法自动重载 sshd，请手动执行: systemctl reload sshd 或 service sshd reload"
fi

echo
echo "=== 完成 ==="
echo "建议验证：ssh 用户@主机 -o PubkeyAuthentication=yes -o PasswordAuthentication=no"
