# NexusEnv

多机办公环境管理工具。基于 SSH ControlMaster + SSHFS：一次完成 2FA，后续 `ssh` / `sshfs` / `rsync` 复用连接。

## 适合什么场景

- 管理多台远程服务器
- 需要跳板机 / ProxyJump
- 希望把远程目录挂到本地开发
- 在本地运行 Claude Code，但直接操作远程项目

## 安装

前提：

- `~/.ssh/config` 已配置好目标主机
- Bash 4+

```bash
git clone https://github.com/YOUR_USER/NexusEnv.git ~/NexusEnv
cd ~/NexusEnv
./setup.sh
```

`setup.sh` 会：

1. 安装 SSHFS 依赖
2. 配置 SSH ControlMaster
3. 创建 `~/mnt/`
4. 运行 `nexus init` 生成配置
5. 链接 `nexus` 到 `~/.local/bin/`

如果 `~/.local/bin` 不在 PATH 中，把下面这行加到你的 shell 配置文件（如 `~/.bashrc` 或 `~/.zshrc`）后重新打开终端：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 快速开始

### 1. 初始化

```bash
nexus init
```

初始化时会交互式询问：

- 默认远程用户名
- 连接保持时间 `control_persist`（秒，或 `yes` 表示永久）
- 每台主机的类型：`cloud` / `slurm`
- 需要挂载的额外远程目录

### 2. 连接、挂载、进入

```bash
nexus connect myserver
nexus mount myserver
nexus ssh myserver
nexus status
```

挂载后目录位于：

```text
~/mnt/myserver/home/
~/mnt/myserver/workspace/
~/mnt/myserver/nfs/
```

### 3. Claude Code / Codex

```bash
nexus claude myserver /data/workspace/my-project
nexus codex myserver /data/workspace/my-project
```

- `nexus claude` 会生成 `CLAUDE.md`
- `nexus codex` 会生成 `AGENTS.md`
- 远程项目路径既可以写绝对路径，也可以写 `~/...`
- 生成位置优先是本地挂载的项目目录；只有在无法推导挂载路径时才回退到当前目录
- 如果已推导出挂载路径但项目目录不存在，会直接报错，避免误写到当前目录

### 4. 后续新增主机

```bash
nexus add myserver
nexus add
```

- 传 host：添加指定主机
- 不传：扫描 `~/.ssh/config` 中未配置的主机

### 5. 调整连接保持时间

```bash
nexus set-timeout 43200
nexus set-timeout yes
nexus set-timeout
```

说明：

- 可以填秒数，也可以填 `yes`（永久保持，直到手动断开）
- 默认值是 `14400`（4 小时）
- 新值会在下次 `nexus connect <host>` 时生效
- `nexus disconnect <host>` 会先自动卸载该 host 的挂载，再关闭连接
- 已经存在的连接不会被强制更新；如需立即生效，先 `disconnect` 再 `connect`

## SSHFS 异常恢复

- 远程服务器断开或关机后，操作系统可能仍暂时保留 SSHFS 挂载记录；`nexus status` 会将其标记为“挂载残留，后端不可达”，此时先执行 `nexus umount <host>` 再继续操作
- 若启用了 watcher，成功挂载后会自动启动轮询；只有存在挂载时才运行，若 host 持续不可达超过 `watcher_grace`，会自动卸载对应挂载
- 成功挂载后会记录 restore intent；若之后因为本地重启、睡眠或 watcher 自动卸载导致挂载消失，可用 `nexus restore` 或 `nexus restore <host>` 快速恢复
- 显式 `nexus umount` / `nexus disconnect` 会清除对应的 restore intent；watcher 自动卸载不会清除

## 命令参考

| 命令 | 说明 |
|------|------|
| `nexus connect <host>` | 建立 SSH 连接（需要 2FA） |
| `nexus disconnect <host>` | 先卸载该 host 的挂载，再关闭 SSH 连接 |
| `nexus ssh <host> [cmd...]` | SSH 到服务器，支持交互式或单条命令 |
| `nexus mount <host> [target]` | 挂载远程目录 |
| `nexus umount <host> [target]` | 卸载挂载 |
| `nexus status` | 查看连接和挂载状态 |
| `nexus health` | 连接健康检查 |
| `nexus restore` | 恢复所有记录过的挂载 |
| `nexus restore <host>` | 恢复单个 host 的挂载 |
| `nexus restore status` | 查看当前恢复记录 |
| `nexus restore clear [host]` | 清空恢复记录 |
| `nexus watcher <action>` | 管理 stale SSHFS 自动清理 watcher |
| `nexus claude <host> <path>` | 为远程项目生成 CLAUDE.md |
| `nexus codex <host> <path>` | 为远程项目生成 AGENTS.md |
| `nexus sync <host>` | 同步 NexusEnv 到远程服务器 |
| `nexus add [host]` | 添加服务器到已有配置 |
| `nexus set-timeout [seconds]` | 设置连接保持时间（秒或 `yes`） |
| `nexus init` | 扫描 SSH 配置并生成 nexus 配置 |
| `nexus setup` | 运行完整安装流程 |

## 挂载与恢复示例

```bash
nexus mount myserver              # 挂载 default_mounts
nexus mount myserver workspace    # 只挂载某个 target
nexus mount myserver all          # 挂载所有 target
nexus mount myserver /tmp         # 挂载自定义远程绝对路径
nexus restore                     # 恢复之前记录的挂载
nexus restore status              # 查看恢复记录
nexus watcher status              # 查看 watcher 是否运行
nexus watcher stop                # 手动停止 watcher
```

## 配置文件

路径：`~/.config/nexus/config`

```ini
[general]
default_user = john
mount_base = ~/mnt
socket_dir = ~/.ssh/sockets
control_persist = 14400
watcher_enabled = false
watcher_interval = 5
watcher_grace = 10
watcher_state_dir = ~/.local/state/nexus
# 或永久保持连接
# control_persist = yes

[server.myserver]
type = cloud
home = ~
workspace = /data/workspace
default_mounts = home, workspace
ssh_workdir = /data/workspace
depends =
```

字段说明：

| 字段 | 说明 |
|------|------|
| `control_persist` | SSH 主连接保持时间，单位秒；也可设为 `yes` 表示永久保持 |
| `watcher_enabled` | 是否启用自动检测并清理 stale SSHFS 挂载 |
| `watcher_interval` | watcher 轮询间隔（秒） |
| `watcher_grace` | host 持续不可达多久后自动卸载挂载 |
| `watcher_state_dir` | watcher 与 restore 的本地状态目录 |
| `type` | `cloud` 或 `slurm` |
| `home`, `workspace`, `nfs`, ... | 远程路径；`~` 表示远程 home |
| `default_mounts` | `mount` 无参数时默认挂载哪些目标 |
| `ssh_workdir` | `nexus ssh` 默认进入的目录 |
| `depends` | 依赖的跳板机 |

## AI Coding Agent 工作流

远程项目挂载到本地后，可以直接用本地 AI coding agent 开发：

### Claude Code

```bash
nexus connect myserver
nexus mount myserver
nexus claude myserver /data/workspace/my-project
cd ~/mnt/myserver/workspace/my-project
claude
```

### Codex

```bash
nexus connect myserver
nexus mount myserver
nexus codex myserver /data/workspace/my-project
cd ~/mnt/myserver/workspace/my-project
codex
```

此时：

- 文件编辑直接作用于挂载目录
- 命令通过 `ssh myserver "..."` 执行
- 无需重复认证，因为会复用已建立的 ControlMaster 连接

## 工作原理

```text
nexus connect <host>
  -> 建立 ControlMaster 主连接
  -> socket 保存在 ~/.ssh/sockets/
  -> 后续 ssh / sshfs / rsync 自动复用
  -> 超时时间由 control_persist 控制
```

如果配置了：

```ini
depends = jumphost
```

那么 `nexus connect internal` 会先连接跳板机，再连接目标主机。

## 依赖

- Bash 4+
- OpenSSH
- SSHFS
- rsync（仅 `sync` 使用）

## License

MIT
