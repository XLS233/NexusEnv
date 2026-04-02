# Remote project — {PROJECT_NAME}

This project is mounted locally through NexusEnv SSHFS and runs on a cloud server with sudo access.

## Environment

- Server: {HOST}
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

This server has sudo access, so package installation and service management can be done remotely when needed. Common examples:

```bash
# Install dependencies
ssh {HOST} "cd {REMOTE_PATH} && pip install -r requirements.txt"

# Manage system packages
ssh {HOST} "sudo apt update && sudo apt install -y <package>"

# Run tests
ssh {HOST} "cd {REMOTE_PATH} && pytest"

# Manage services
ssh {HOST} "sudo systemctl restart <service>"
ssh {HOST} "sudo systemctl status <service>"

# Docker
ssh {HOST} "cd {REMOTE_PATH} && docker compose up -d"
ssh {HOST} "docker ps"

# Logs
ssh {HOST} "tail -f {REMOTE_PATH}/logs/app.log"
ssh {HOST} "sudo journalctl -u <service> -f"
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
- This server has sudo access, so confirm before destructive operations such as `rm -rf` or stopping services
