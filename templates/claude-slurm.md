# 远程项目 — {PROJECT_NAME}

这是一个通过 NexusEnv SSHFS 挂载到本地的远程项目，运行在 Slurm 集群上。

## 环境

- 服务器: {HOST}（登录节点）
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

### 重要：登录节点 vs 计算节点

- **登录节点**（通过 SSH 直接访问）：仅用于轻量操作（文件管理、提交任务、查看状态）
- **计算节点**（通过 Slurm 调度）：所有 GPU 计算、训练、大内存任务必须通过 Slurm 提交

**严禁在登录节点运行 GPU 训练、大规模数据处理等计算密集型任务。**

### Slurm 任务管理

```bash
# 提交批处理任务
ssh {HOST} "cd {REMOTE_PATH} && sbatch train.slurm"

# 提交交互式 GPU 任务（如调试）
ssh {HOST} "cd {REMOTE_PATH} && srun --gres=gpu:1 --pty bash -c '<command>'"

# 查看任务队列
ssh {HOST} "squeue -u \$(whoami)"

# 取消任务
ssh {HOST} "scancel <job_id>"

# 查看任务详情
ssh {HOST} "sacct -j <job_id> --format=JobID,JobName,State,ExitCode,Elapsed"

# 查看可用资源
ssh {HOST} "sinfo"
```

### 登录节点可执行的操作

```bash
# 安装 Python 依赖
ssh {HOST} "cd {REMOTE_PATH} && pip install -r requirements.txt"

# 运行轻量测试（不需要 GPU）
ssh {HOST} "cd {REMOTE_PATH} && pytest tests/unit/"

# 查看训练日志
ssh {HOST} "tail -f {REMOTE_PATH}/logs/train.log"

# 检查 GPU 使用情况（如果登录节点可见）
ssh {HOST} "nvidia-smi"

# 管理 conda 环境
ssh {HOST} "conda activate myenv && conda list"
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
- 登录节点通常没有 sudo 权限，软件安装使用 conda/pip 或 module load
- 长时间运行的任务必须通过 sbatch 提交，避免因 SSH 断开而丢失
- 共享存储（如 NFS）上的大文件 I/O 可能较慢，注意数据读取策略
