# 远程项目 — {PROJECT_NAME}

这是一个通过 NexusEnv SSHFS 挂载到本地的远程项目，运行在一台有 sudo 权限的云服务器上。

## 环境

- 服务器: {HOST}
- 远程路径: {REMOTE_PATH}
- 本地挂载点: {LOCAL_MOUNT}

## 操作方式

### 文件读写

当前目录已通过 SSHFS 挂载，直接使用 Read/Edit/Write 工具操作文件即可，改动会实时同步到远程服务器。

### 执行命令

本地 shell 命令在本机执行，**不会**在远程服务器上运行。所有需要远程执行的命令必须通过 SSH：

```bash
ssh {HOST} "cd {REMOTE_PATH} && <command>"
```

这台服务器有 sudo 权限，可以直接安装软件包和管理服务。常见操作：

```bash
# 安装依赖
ssh {HOST} "cd {REMOTE_PATH} && pip install -r requirements.txt"

# 系统包管理
ssh {HOST} "sudo apt update && sudo apt install -y <package>"

# 运行测试
ssh {HOST} "cd {REMOTE_PATH} && pytest"

# 启动/管理服务
ssh {HOST} "sudo systemctl restart <service>"
ssh {HOST} "sudo systemctl status <service>"

# Docker 操作
ssh {HOST} "cd {REMOTE_PATH} && docker compose up -d"
ssh {HOST} "docker ps"

# 查看日志
ssh {HOST} "tail -f {REMOTE_PATH}/logs/app.log"
ssh {HOST} "sudo journalctl -u <service> -f"
```

### 连接检查

执行远程命令前，先确认 SSH 连接可用：

```bash
ssh -O check {HOST}
```

如果连接已断开，提示用户运行 `nexus connect {HOST}` 重新建立连接。

## 注意事项

- SSH ControlMaster 连接默认 4 小时超时，超时后需用户重新 `nexus connect`
- SSHFS 挂载依赖 SSH 连接，连接断开后文件操作会报错（I/O error）
- 有 sudo 权限，执行破坏性操作（rm -rf、systemctl stop 等）前务必确认
