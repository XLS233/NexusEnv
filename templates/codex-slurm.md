# Remote project — {PROJECT_NAME}

This project is mounted locally through NexusEnv SSHFS and runs on a Slurm cluster.

## Environment

- Server: {HOST} (login node)
- Remote path: {REMOTE_PATH}
- Local mount: {LOCAL_MOUNT}

## How to work

### File operations

This directory is already mounted through SSHFS. Read and edit files directly in the local working tree; changes are applied to the remote server immediately.

### Running commands

Local shell commands run on your machine, not on the remote server. Any command that must run remotely should go through SSH:

```bash
ssh {HOST} "cd {REMOTE_PATH} && <command>"
```

### Important: login node vs compute node

- **Login node**: use it for lightweight work such as file operations, job submission, and status checks
- **Compute node**: use Slurm for GPU jobs, training, or memory-heavy tasks

Do not run GPU training or other heavy workloads directly on the login node.

### Slurm workflow

```bash
# Submit a batch job
ssh {HOST} "cd {REMOTE_PATH} && sbatch train.slurm"

# Start an interactive GPU session for debugging
ssh {HOST} "cd {REMOTE_PATH} && srun --gres=gpu:1 --pty bash -c '<command>'"

# Check the queue
ssh {HOST} "squeue -u \$(whoami)"

# Cancel a job
ssh {HOST} "scancel <job_id>"

# Inspect job details
ssh {HOST} "sacct -j <job_id> --format=JobID,JobName,State,ExitCode,Elapsed"

# View cluster resources
ssh {HOST} "sinfo"
```

### Safe login-node tasks

```bash
# Install Python dependencies
ssh {HOST} "cd {REMOTE_PATH} && pip install -r requirements.txt"

# Run lightweight tests
ssh {HOST} "cd {REMOTE_PATH} && pytest tests/unit/"

# Tail logs
ssh {HOST} "tail -f {REMOTE_PATH}/logs/train.log"

# Check GPU visibility if available
ssh {HOST} "nvidia-smi"

# Manage conda environments
ssh {HOST} "conda activate myenv && conda list"
```

### Connection check

Before running remote commands, verify the SSH connection:

```bash
ssh -O check {HOST}
```

If the connection is down, ask the user to run `nexus connect {HOST}` first.

## Notes

- SSH ControlMaster persistence is controlled by the NexusEnv `control_persist` setting; if the connection expires, ask the user to run `nexus connect {HOST}` again
- SSHFS mounts depend on the SSH connection; if it drops, file operations may fail with I/O errors
- Login nodes usually do not have sudo access; prefer conda, pip, or module-based installs
- Long-running jobs should go through `sbatch` or `srun`, not a plain SSH session
- Large I/O on shared storage may be slow, so be careful with data-heavy workflows
