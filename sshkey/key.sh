#!/bin/sh

set -e

echo "=== SSH Public Key Import & Password Auth Disable ==="
echo

# 1. 输入用户名
printf '%s' "请输入用户名（多个用空格隔开）: "
read -r USERS
if [ -z "$USERS" ]; then
    echo "错误：未输入任何用户名"
    exit 1
fi
# 转换为位置参数
set -- $USERS

# 2. 输入公钥
printf '%s' "请输入公钥: "
read -r PUBKEY
PUBKEY=$(echo "$PUBKEY" | tr -d '"' | tr -d "'")
if [ -z "$PUBKEY" ]; then
    echo "错误：未输入公钥"
    exit 1
fi

echo
echo "=== 将要为以下用户导入公钥 ==="
for user in "$@"; do
    echo "$user"
done
echo

printf '%s' "确认继续？(y/n): "
read -r CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "已取消"
    exit 0
fi

# 3. 导入公钥到各用户
ALL_SUCCESS=true
for USER in "$@"; do
    echo ">>> 处理用户: $USER"

    # 检查用户是否存在
    if ! id "$USER" >/dev/null 2>&1; then
        echo "    [失败] 用户 $USER 不存在"
        ALL_SUCCESS=false
        continue
    fi

    # 获取用户家目录
    HOME_DIR=$(getent passwd "$USER" | cut -d: -f6)
    SSH_DIR="$HOME_DIR/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    # 创建 .ssh 目录
    if [ ! -d "$SSH_DIR" ]; then
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

    # 验证公钥是否写入成功
    if grep -qF "$PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
        echo "    [成功] 用户 $USER 公钥导入完成"
    else
        echo "    [失败] 用户 $USER 公钥写入失败"
        ALL_SUCCESS=false
    fi
    echo
done

# ============================================================
# 4. 禁用 SSH 密码认证（仅当所有用户都成功导入公钥时执行）
# ============================================================
# 如需启用密码登录禁用功能，请取消注释以下代码块
# ------------------------------------------------------------
# DISABLE_PASSWORD_AUTH=true
#
# if [ "$ALL_SUCCESS" = true ] && [ "$DISABLE_PASSWORD_AUTH" = true ]; then
#     echo "=== 禁用 SSH 密码认证 ==="
# SSHD_CONF="/etc/ssh/sshd_config"
# SSHD_CONF_D="/etc/ssh/sshd_config.d"
#
# disable_password_auth() {
#     CONF_FILE="$1"
#     if [ ! -f "$CONF_FILE" ]; then
#         return
#     fi
#
#     # 注释掉现有的 PasswordAuthentication yes 相关配置
#     sed -i 's/^PasswordAuthentication yes/#PasswordAuthentication yes/' "$CONF_FILE"
#     sed -i 's/^# PasswordAuthentication yes/#PasswordAuthentication yes/' "$CONF_FILE"
#     sed -i 's/^ChallengeResponseAuthentication yes/#ChallengeResponseAuthentication yes/' "$CONF_FILE"
#     sed -i 's/^# ChallengeResponseAuthentication yes/#ChallengeResponseAuthentication yes/' "$CONF_FILE"
#     sed -i 's/^KbdInteractiveAuthentication yes/#KbdInteractiveAuthentication yes/' "$CONF_FILE"
#     sed -i 's/^# KbdInteractiveAuthentication yes/#KbdInteractiveAuthentication yes/' "$CONF_FILE"
#
#     # 确保有 PasswordAuthentication no（追加到文件末尾如果没有的话）
#     if ! grep -qE '^PasswordAuthentication no' "$CONF_FILE" && \
#        ! grep -qE '^# PasswordAuthentication no' "$CONF_FILE"; then
#         echo "PasswordAuthentication no" >> "$CONF_FILE"
#         echo "    已追加 PasswordAuthentication no 到: $CONF_FILE"
#     else
#         # 将注释掉的 PasswordAuthentication no 取消注释
#         sed -i 's/^# PasswordAuthentication no/PasswordAuthentication no/' "$CONF_FILE"
#         echo "    已更新: $CONF_FILE"
#     fi
#
#     # 同样处理 ChallengeResponseAuthentication 和 KbdInteractiveAuthentication
#     if ! grep -qE '^ChallengeResponseAuthentication no' "$CONF_FILE" && \
#        ! grep -qE '^# ChallengeResponseAuthentication no' "$CONF_FILE"; then
#         echo "ChallengeResponseAuthentication no" >> "$CONF_FILE"
#     fi
#     sed -i 's/^# ChallengeResponseAuthentication no/ChallengeResponseAuthentication no/' "$CONF_FILE"
#
#     if ! grep -qE '^KbdInteractiveAuthentication no' "$CONF_FILE" && \
#        ! grep -qE '^# KbdInteractiveAuthentication no' "$CONF_FILE"; then
#         echo "KbdInteractiveAuthentication no" >> "$CONF_FILE"
#     fi
#     sed -i 's/^# KbdInteractiveAuthentication no/KbdInteractiveAuthentication no/' "$CONF_FILE"
#
#     # 禁止 root 密码登录（允许 pubkey 登录，禁止密码登录）
#     sed -i 's/^PermitRootLogin yes/#PermitRootLogin yes/' "$CONF_FILE"
#     sed -i 's/^# PermitRootLogin yes/PermitRootLogin yes/' "$CONF_FILE"
#     sed -i 's/^PermitRootLogin prohibit-password/#PermitRootLogin prohibit-password/' "$CONF_FILE"
#     sed -i 's/^# PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' "$CONF_FILE"
#     if ! grep -qE '^PermitRootLogin' "$CONF_FILE"; then
#         echo "PermitRootLogin prohibit-password" >> "$CONF_FILE"
#         echo "    已追加 PermitRootLogin prohibit-password 到: $CONF_FILE"
#     else
#         sed -i 's/^# PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' "$CONF_FILE"
#         echo "    已更新: $CONF_FILE"
#     fi
# }
#
# if [ -d "$SSHD_CONF_D" ]; then
#     for f in "$SSHD_CONF_D"/*.conf; do
#         disable_password_auth "$f"
#     done
# fi
# disable_password_auth "$SSHD_CONF"
#
# # 检查配置是否已正确设置
# # 只要存在未注释的 PasswordAuthentication yes 就是不安全的
# if grep -rE '^PasswordAuthentication yes' "$SSHD_CONF" "$SSHD_CONF_D"/ 2>/dev/null | grep -v '^#'; then
#     echo "    警告：仍有 PasswordAuthentication yes 未被禁用，请手动检查"
# elif ! grep -rE '^PasswordAuthentication no' "$SSHD_CONF" "$SSHD_CONF_D"/ 2>/dev/null | grep -v '^#' >/dev/null; then
#     echo "    警告：未找到有效的 PasswordAuthentication no 配置，请手动检查"
# else
#     echo "    密码认证已禁用"
# fi
#
# # 检查 PermitRootLogin
# if grep -rE '^PermitRootLogin' "$SSHD_CONF" "$SSHD_CONF_D"/ 2>/dev/null | grep -v '^#' | grep -qvE '(prohibit-password|no)$'; then
#     echo "    警告：root 密码登录未被禁止，请手动检查 PermitRootLogin"
# elif grep -rE '^PermitRootLogin (prohibit-password|no)$' "$SSHD_CONF" "$SSHD_CONF_D"/ 2>/dev/null | grep -v '^#' >/dev/null; then
#     echo "    root 密码登录已禁止"
# fi
# else
#     echo "=== 跳过禁用密码认证 ==="
#     echo "原因：有用户导入公钥失败，为避免锁住，不禁用密码登录"
# fi
#
# # 5. 重载 sshd 配置
# if command -v systemctl >/dev/null 2>&1; then
#     systemctl reload sshd 2>/dev/null && echo "    sshd 已重载 (systemctl)"
# elif command -v service >/dev/null 2>&1; then
#     service sshd reload 2>/dev/null && echo "    sshd 已重载 (service)"
# else
#     echo "    无法自动重载 sshd，请手动执行: systemctl reload sshd 或 service sshd reload"
# fi

echo
echo "=== 完成 ==="
echo "建议验证：ssh 用户@主机 -o PubkeyAuthentication=yes -o PasswordAuthentication=no"
