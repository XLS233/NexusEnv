# NexusEnv - Claude Code 使用指南

本项目管理多台远程服务器的 SSH 连接和文件系统挂载。支持需要 2FA 的服务器。

## 工作方式

用户通过 `nexus connect <host>` 手动建立 SSH 连接（完成2FA），之后 ControlMaster 会复用该连接。你可以：

1. **执行远程命令**: `ssh <host> "command"` — 无需再次认证
2. **读写远程文件**: 挂载后文件位于 `~/mnt/<host>/`，可直接使用 Read/Edit 工具

## 操作前检查

在执行远程操作前，先运行 `nexus status` 确认目标 host 已连接。如果未连接，提示用户：
> 请运行 `nexus connect <host>` 建立连接

## 远程文件操作

SSHFS 挂载后（`nexus mount <host>` 默认挂载配置中的 default_mounts）：
- home: `~/mnt/<host>/`
- 其他目标: `~/mnt/<host>/<target>/`

## 远程项目模板

在远程项目目录中放置 CLAUDE.md 可以让 Claude Code 自动识别远程执行规则：
```bash
cp templates/CLAUDE.md ~/mnt/<host>/workspace/my-project/
# 编辑其中的 SERVER_NAME、REMOTE_PATH 等占位符
```

## 注意事项

- 配置了 `depends` 的服务器需要先连接跳板机
- ControlMaster socket 默认 4 小时超时，超时后需重新 connect
- SSHFS 挂载依赖 SSH 连接，连接断开后挂载会失效
