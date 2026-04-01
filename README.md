# NexusEnv

多机办公环境管理工具。通过 SSH ControlMaster 复用连接 + SSHFS 挂载远程文件系统，一次 2FA 认证后即可自由操作多台服务器。

## 功能

- **连接管理** — SSH ControlMaster 复用，一次认证多次使用
- **跳板机支持** — 自动检测 ProxyJump 依赖，递归建立连接链
- **文件挂载** — SSHFS 挂载远程目录到本地 `~/mnt/<host>/<target>/`
- **多目标挂载** — 每个服务器可配置多个远程路径（home、workspace、nfs 等）
- **配置驱动** — INI 格式配置文件，新增服务器只需编辑配置
- **交互式初始化** — 扫描 `~/.ssh/config` 自动生成配置，支持自定义挂载路径
- **健康检查** — 连接状态监测 + 延迟测量 + 无效 socket 自动清理

## 安装

### 前置条件

- `~/.ssh/config` 中已配置好你的服务器 Host
- Bash 4.0+

### 安装步骤

```bash
git clone https://github.com/YOUR_USER/NexusEnv.git ~/NexusEnv
cd ~/NexusEnv
./setup.sh
```

setup.sh 会自动完成：

1. 安装 SSHFS 依赖（macOS: macFUSE + sshfs-mac，Linux: apt/yum/dnf）
2. 配置 SSH ControlMaster（追加到 `~/.ssh/config`）
3. 创建挂载点目录 `~/mnt/`
4. 运行 `./nexus init` 交互式生成配置文件
5. 链接 `nexus` 到 `~/.local/bin/`

安装后确保 `~/.local/bin` 在 PATH 中：

```bash
# 添加到 ~/.zshrc 或 ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"
```

## 快速开始

### 1. 初始化配置

```bash
./nexus init
```

交互式引导你完成配置：

```
远程默认用户名 [john]: john

扫描 ~/.ssh/config 中的 Host...

添加 myserver 到 nexus 配置? [Y/n] Y
  默认已添加 home = ~ (远程 home 目录)
  如需挂载其他远程目录（如工作目录、共享存储等），请逐个添加:

  挂载名称 (如 workspace、nfs，直接回车跳过): workspace
  远程路径 (如 /data/john/workspace): /data/workspace
  + workspace = /data/workspace (将挂载到 ~/mnt/myserver/workspace/)

  挂载名称 (如 workspace、nfs，直接回车跳过):
  ✓ 已添加 myserver (user=john)
```

- `home = ~` 自动添加，`~` 会在挂载时解析为远程服务器的实际 home 路径
- 挂载名称和远程路径分两步输入，更清晰
- 可以添加任意多个额外挂载目标，直接回车跳过即完成当前服务器

### 2. 连接并使用

```bash
./nexus connect myserver     # 建立 SSH 连接（完成 2FA 认证）
./nexus mount myserver       # 挂载远程文件到本地
./nexus ssh myserver         # SSH 到服务器（自动 cd 到工作目录）
./nexus status               # 查看所有连接和挂载状态
```

### 3. 挂载后的目录结构

```
~/mnt/myserver/
├── home/                  ← 远程 home 目录
├── workspace/             ← 远程 /data/workspace
└── nfs/                   ← 远程 /nfs_shared/data（如有配置）
```

挂载后远程文件就像本地文件一样操作，可以直接用编辑器打开。

## 命令参考

| 命令 | 说明 |
|------|------|
| `./nexus connect <host>` | 建立 SSH 连接（需要 2FA） |
| `./nexus disconnect <host>` | 关闭 SSH 连接 |
| `./nexus ssh <host> [cmd...]` | SSH 到服务器，支持交互式或单条命令 |
| `./nexus mount <host> [target]` | SSHFS 挂载远程目录 |
| `./nexus umount <host> [target]` | 卸载 SSHFS 挂载 |
| `./nexus status` | 查看所有连接和挂载状态 |
| `./nexus health` | 连接健康检查（含延迟测量） |
| `./nexus sync <host>` | 同步 NexusEnv 到远程服务器 |
| `./nexus init` | 扫描 SSH 配置并生成 nexus 配置 |
| `./nexus setup` | 运行完整安装流程 |

### 挂载选项

```bash
./nexus mount myserver              # 挂载 default_mounts 中的目标
./nexus mount myserver workspace    # 只挂载 workspace
./nexus mount myserver all          # 挂载所有已配置目标
./nexus mount myserver /tmp         # 挂载自定义远程绝对路径
```

## 配置文件

路径：`~/.config/nexus/config`（INI 格式，由 `./nexus init` 交互生成，也可手动编辑）

```ini
[general]
default_user = john
mount_base = ~/mnt
socket_dir = ~/.ssh/sockets
control_persist = 14400

[server.myserver]
home = ~
workspace = /data/workspace
nfs = /nfs_shared/data
default_mounts = home, workspace, nfs
ssh_workdir = /data/workspace
depends =

[server.internal]
home = ~
default_mounts = home
ssh_workdir = ~
# 通过 myserver 跳板连接
depends = myserver
```

### 配置字段说明

| 字段 | 说明 |
|------|------|
| `home`, `workspace`, `nfs`, ... | 远程路径（key 即挂载目标名，`~` 表示远程 home） |
| `default_mounts` | `./nexus mount <host>` 无参数时挂载的目标（逗号分隔） |
| `ssh_workdir` | `./nexus ssh` 自动 cd 的目录 |
| `depends` | 连接前需要先连接的跳板机（用于 ProxyJump 场景） |

### 关于 `~` 路径

配置中的 `~` 会在挂载时自动解析为远程服务器的实际 home 路径（通过 `ssh <host> 'echo $HOME'`）。这意味着即使不同服务器的 home 路径不同（如 `/home/john`、`/home/S/john`），配置里统一写 `~` 即可。

## 最佳实践

### 挂载远程项目到本机开发

SSHFS 挂载后，远程文件在本地以普通文件形式存在，可以直接用本地编辑器和工具操作：

```bash
# 1. 连接服务器
./nexus connect myserver

# 2. 挂载远程文件系统
./nexus mount myserver

# 3. 用本地编辑器直接打开远程项目
code ~/mnt/myserver/workspace/my-project
# 或
vim ~/mnt/myserver/workspace/my-project/main.py
```

挂载后的目录结构就像本地文件一样，所有编辑都会实时同步到远程服务器。

### 用本地 Claude Code 开发远程项目

NexusEnv 的核心场景之一：**在本地运行 Claude Code，直接开发挂载到本地的远程项目**。这样既能享受本地 Claude Code 的交互体验，又能操作远程服务器上的代码和环境。

**步骤：**

```bash
# 1. 确保连接和挂载就绪
./nexus connect myserver
./nexus mount myserver

# 2. 在远程项目目录放置 CLAUDE.md（告诉 Claude Code 如何操作远程环境）
cp templates/CLAUDE.md ~/mnt/myserver/workspace/my-project/CLAUDE.md
# 编辑其中的 SERVER_NAME、REMOTE_PATH 等占位符

# 3. 进入挂载目录，启动 Claude Code
cd ~/mnt/myserver/workspace/my-project
claude
```

**CLAUDE.md 模板的作用：**

`templates/CLAUDE.md` 是为远程项目准备的 Claude Code 指令模板。放置在项目目录后，Claude Code 会自动读取，从而知道：

- 文件编辑通过 SSHFS 挂载直接进行（Read/Edit 工具）
- 命令执行需要通过 SSH：`ssh myserver "cd /path && command"`
- GPU 任务需要通过 Slurm 调度（`sbatch`/`srun`）

**实际效果：**

- Claude Code 读写文件 → 直接操作挂载目录，实时同步到远程
- Claude Code 运行命令 → 通过 SSH ControlMaster 复用连接，无需认证
- Claude Code 查看日志/调试 → `ssh myserver "tail -f /path/to/log"`

> **提示**: 编辑 `templates/CLAUDE.md` 中的占位符（`SERVER_NAME`、`REMOTE_PATH`、`YOUR_USER`）为实际值后再放入项目目录。

## 工作原理

```
./nexus connect myserver
  ↓
SSH ControlMaster 建立持久连接 → ~/.ssh/sockets/<user>@<host>-<port>
  ↓
后续所有操作（ssh / sshfs / rsync）自动复用该连接，无需再次认证
  ↓
ControlPersist 保持连接 4 小时（可配置），超时后需重新 connect
```

### 跳板机

配置 `depends = jumphost` 后，`./nexus connect` 会自动先连接跳板机：

```bash
./nexus connect internal
# 自动检测 depends = myserver
# → 先连接 myserver（如果未连接）
# → 再连接 internal
```

## 依赖

- Bash 4.0+（需要关联数组支持）
- OpenSSH（ssh, ssh-keygen）
- SSHFS（macOS: macFUSE + sshfs-mac，Linux: sshfs）
- rsync（仅 `./nexus sync` 需要）

## 平台支持

- macOS（通过 Homebrew 安装依赖）
- Linux（Ubuntu/Debian, CentOS/RHEL, Fedora）

## 项目结构

```
NexusEnv/
├── nexus                 # 主命令行工具
├── setup.sh              # 安装脚本
├── lib/
│   └── config.sh         # INI 配置解析库
├── config/
│   ├── example.conf      # 配置文件示例
│   └── ssh_controlmaster.conf  # SSH ControlMaster 配置模板
└── templates/
    └── CLAUDE.md         # 远程项目 Claude Code 集成模板
```

## License

MIT
