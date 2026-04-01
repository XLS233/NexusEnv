# PROJECT_NAME

位于 **SERVER_NAME** 服务器的远程项目。

## 环境信息

- **服务器**: SERVER_NAME
- **远程路径**: REMOTE_PATH
- **本地挂载**: ~/mnt/SERVER_NAME/workspace/...

## 执行规则

1. **编辑文件** - 通过 SSHFS 挂载，直接使用 Read/Edit 工具
2. **执行命令** - 通过 SSH 复用连接：
   ```bash
   ssh SERVER_NAME "cd REMOTE_PATH && <command>"
   ```
3. **GPU 训练** - 使用 Slurm 调度：
   ```bash
   ssh SERVER_NAME "cd REMOTE_PATH && sbatch train.slurm"
   ssh SERVER_NAME "squeue -u YOUR_USER"
   ```

## 操作前检查

执行远程操作前，先确认连接状态：
```bash
nexus status
```
如果未连接，提示用户运行 `nexus connect SERVER_NAME`

## 注意事项

- GPU 节点：计算任务使用 `sbatch` 或 `srun`，登录节点仅用于轻量任务
- 数据目录：根据实际环境修改
- 连接超时 4 小时，超时后需重新 `nexus connect`
