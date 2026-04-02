# ssh-key-deploy

SSH 公钥批量导入及密码认证禁用脚本。

## 功能

- 支持为多个用户批量导入 SSH 公钥
- 自动创建 `.ssh` 目录并设置正确权限
- 公钥去重，避免重复导入
- 验证公钥写入成功后才禁用密码登录
- 禁用以下认证方式：
  - `PasswordAuthentication no`
  - `ChallengeResponseAuthentication no`
  - `KbdInteractiveAuthentication no`
  - `PermitRootLogin prohibit-password`（禁止 root 密码登录，允许 pubkey 登录）
- 自动重载 sshd 配置

## 使用方法

```bash
sh key.sh
```

### 输入说明

1. 输入用户名（多个用空格隔开）
2. 输入公钥
3. 确认继续

### 安全机制

- 任意一个用户不存在或公钥导入失败，则**不会**禁用密码登录，避免被锁在外面
- 全部成功后才执行禁用密码登录操作

### 验证

```bash
ssh 用户@主机 -o PubkeyAuthentication=yes -o PasswordAuthentication=no
```
