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

## 远程项目配置

使用 `nexus claude` 为远程项目自动生成 `CLAUDE.md`：
```bash
nexus claude <host> <remote_project_path>
```

使用 `nexus codex` 为远程项目自动生成 `AGENTS.md`：
```bash
nexus codex <host> <remote_project_path>
```

两者都会根据服务器 type（cloud/slurm）自动选择模板并填充信息。

## 注意事项

- 配置了 `depends` 的服务器需要先连接跳板机
- ControlMaster socket 保持时间由 `control_persist` 配置决定，超时后需重新 connect
- SSHFS 挂载依赖 SSH 连接，连接断开后挂载会失效
