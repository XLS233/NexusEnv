#!/usr/bin/env bash
# NexusEnv — INI 配置解析库
# 用法: source lib/config.sh
#
# 解析 ~/.config/nexus/config (INI 格式)
# 提供 cfg_get / cfg_get_servers / cfg_get_mount_targets 等函数

# ===== 配置路径 =====
NEXUS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nexus"
NEXUS_CONFIG_FILE="${NEXUS_CONFIG:-$NEXUS_CONFIG_DIR/config}"

# ===== 内部存储 =====
# 使用扁平化 key 存储: _CFG[section.key] = value
declare -gA _CFG=()
_CFG_LOADED=false

# ===== 解析器 =====

# 加载并解析 INI 配置文件
# 用法: cfg_load [config_file]
cfg_load() {
    local file="${1:-$NEXUS_CONFIG_FILE}"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    _CFG=()
    local section=""
    local line_num=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))

        # 去除前后空白
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # 跳过空行和注释
        [[ -z "$line" || "$line" == \#* ]] && continue

        # section 头: [section.name]
        if [[ "$line" =~ ^\[([a-zA-Z0-9._-]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi

        # key = value
        if [[ "$line" =~ ^([a-zA-Z0-9_-]+)[[:space:]]*=[[:space:]]*(.*) ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # 去除 value 尾部注释（# 前有空格才算注释）
            if [[ "$value" =~ ^(.+)[[:space:]]+#.*$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi

            # 去除 value 前后空白
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"

            # 去除引号
            if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi

            # 展开 ~ — 仅对非 server section 的本地路径展开
            # server section 下的路径是远程路径，~ 由远程 shell 解析
            if [[ "$section" != server.* ]]; then
                if [[ "$value" == "~/"* ]]; then
                    value="$HOME/${value:2}"
                elif [[ "$value" == "~" ]]; then
                    value="$HOME"
                fi
            fi

            if [[ -n "$section" ]]; then
                _CFG["${section}.${key}"]="$value"
            else
                _CFG["$key"]="$value"
            fi
            continue
        fi

        # 无法解析的行
        echo "nexus: 配置解析警告: 第 ${line_num} 行无法解析: $line" >&2
    done < "$file"

    _CFG_LOADED=true
    return 0
}

# ===== 查询函数 =====

# 获取配置值
# 用法: cfg_get <section> <key> [default]
# 示例: cfg_get general default_user "$(whoami)"
cfg_get() {
    local section="$1" key="$2" default="${3:-}"
    local full_key="${section}.${key}"
    echo "${_CFG[$full_key]:-$default}"
}

# 获取 server 的远程路径
# 用法: cfg_get_path <server> <target>
# 示例: cfg_get_path myserver home -> ~
cfg_get_path() {
    local server="$1" target="$2"
    cfg_get "server.${server}" "$target"
}

# 获取所有已配置的服务器名
# 用法: cfg_get_servers -> "myserver internal cloudvm"
cfg_get_servers() {
    local servers=()
    local seen=()
    for key in "${!_CFG[@]}"; do
        if [[ "$key" =~ ^server\.([^.]+)\. ]]; then
            local name="${BASH_REMATCH[1]}"
            # 去重
            local found=false
            for s in "${seen[@]}"; do
                [[ "$s" == "$name" ]] && { found=true; break; }
            done
            if ! $found; then
                seen+=("$name")
                servers+=("$name")
            fi
        fi
    done
    echo "${servers[*]}"
}

# 获取服务器的挂载目标列表
# 用法: cfg_get_mount_targets <server> -> "home workspace nfs"
cfg_get_mount_targets() {
    local server="$1"
    local targets=()
    for key in "${!_CFG[@]}"; do
        if [[ "$key" =~ ^server\.${server}\.(.+)$ ]]; then
            local field="${BASH_REMATCH[1]}"
            # 排除非路径字段
            case "$field" in
                default_mounts|ssh_workdir|depends|type) continue ;;
                *)
                    local val="${_CFG[$key]}"
                    # 只有以 / 开头的值才是路径
                    if [[ "$val" == /* ]]; then
                        targets+=("$field")
                    fi
                    ;;
            esac
        fi
    done
    echo "${targets[*]}"
}

# 获取服务器默认挂载目标
# 用法: cfg_get_default_mounts <server> -> "home workspace"
cfg_get_default_mounts() {
    local server="$1"
    local raw
    raw="$(cfg_get "server.${server}" default_mounts "home")"
    # 逗号分隔转空格分隔
    echo "$raw" | tr ',' ' ' | tr -s ' '
}

# 获取服务器依赖
# 用法: cfg_get_depends <server> -> "myserver" 或 ""
cfg_get_depends() {
    local server="$1"
    cfg_get "server.${server}" depends ""
}

# 检查服务器是否已配置
# 用法: cfg_has_server <server> -> 0 (存在) 或 1 (不存在)
cfg_has_server() {
    local server="$1"
    [[ -n "${_CFG["server.${server}.type"]:-}" ]]
}

# 获取服务器类型
# 用法: cfg_get_type <server> -> "cloud" 或 "slurm"
cfg_get_type() {
    local server="$1"
    cfg_get "server.${server}" type "cloud"
}

# 获取服务器 ssh 工作目录
# 用法: cfg_get_ssh_workdir <server> -> "/data/workspace"
cfg_get_ssh_workdir() {
    local server="$1"
    local default_home
    default_home="$(cfg_get_path "$server" home)"
    cfg_get "server.${server}" ssh_workdir "$default_home"
}

# ===== 通用配置 =====

# 获取挂载根目录
cfg_mount_base() {
    cfg_get general mount_base "$HOME/mnt"
}

# 获取 socket 目录
cfg_socket_dir() {
    cfg_get general socket_dir "$HOME/.ssh/sockets"
}

# 获取 ControlPersist 超时（秒）
cfg_control_persist() {
    cfg_get general control_persist 14400
}

# ===== 确保配置已加载 =====

# 检查配置是否存在并加载
# 返回 0 = 成功, 1 = 配置文件不存在
cfg_ensure_loaded() {
    if $_CFG_LOADED; then
        return 0
    fi
    if [[ ! -f "$NEXUS_CONFIG_FILE" ]]; then
        return 1
    fi
    cfg_load
}

# ===== 配置写入 =====

# 生成配置文件
# 用法: cfg_write_config <output_file> [default_user] [control_persist]
cfg_write_config() {
    local output="$1"
    shift
    local user="${1:-$(whoami)}"
    local control_persist="${2:-14400}"

    mkdir -p "$(dirname "$output")"

    cat > "$output" <<HEADER
# NexusEnv 配置文件
# 由 nexus init 自动生成于 $(date '+%Y-%m-%d %H:%M:%S')
# 编辑后立即生效（无需重启）

[general]
default_user = ${user}
mount_base = ~/mnt
socket_dir = ~/.ssh/sockets
control_persist = ${control_persist}

HEADER

    return 0
}

# 追加一个 server section 到配置文件
# 用法: cfg_append_server <file> <name> <user> [depends] [type] [extra_mount...]
# extra_mount 格式: "name=path"，如 "workspace=/data/work"
# type: cloud 或 slurm（默认 cloud）
cfg_append_server() {
    local file="$1" name="$2" user="$3" depends="${4:-}" type="${5:-cloud}"
    shift; shift; shift; shift 2>/dev/null || true; shift 2>/dev/null || true

    local default_mounts="home"
    local extra_lines=""
    local ssh_workdir="~"

    for entry in "$@"; do
        local mname="${entry%%=*}" mpath="${entry#*=}"
        extra_lines+="${mname} = ${mpath}\n"
        default_mounts+=", ${mname}"
        # 第一个额外目标作为 ssh_workdir
        [[ "$ssh_workdir" == "~" ]] && ssh_workdir="$mpath"
    done

    {
        echo "[server.${name}]"
        echo "type = ${type}"
        echo "home = ~"
        [[ -n "$extra_lines" ]] && printf "%b" "$extra_lines"
        echo "default_mounts = ${default_mounts}"
        echo "ssh_workdir = ${ssh_workdir}"
        echo "depends = ${depends}"
        echo ""
    } >> "$file"
}
