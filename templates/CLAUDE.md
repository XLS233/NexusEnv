# 远程项目 — {PROJECT_NAME}

这是一个通过 NexusEnv SSHFS 挂载到本地的远程项目。

## 环境

- 服务器: {HOST}
- 远程路径: {REMOTE_PATH}
- 本地挂载点: ~/mnt/{HOST}/{TARGET}/...

## 操作方式

### 文件读写

当前目录已通过 SSHFS 挂载，直接使用 Read/Edit/Write 工具操作文件即可，改动会实时同步到远程服务器。

### 执行命令

本地 shell 命令会在本机执行，**不会**在远程服务器上运行。需要在远程执行的命令（编译、测试、运行服务等）必须通过 SSH：

```bash
ssh {HOST} "cd {REMOTE_PATH} && <command>"
```

常见场景：

```bash
# 安装依赖
ssh {HOST} "cd {REMOTE_PATH} && pip install -r requirements.txt"

# 运行测试
ssh {HOST} "cd {REMOTE_PATH} && pytest"

# 查看日志
ssh {HOST} "tail -f {REMOTE_PATH}/logs/app.log"

# 检查进程
ssh {HOST} "ps aux | grep my_service"
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
- 不要在本地运行需要远程环境的命令（如依赖远程 GPU、远程数据库等）
