#!/usr/bin/env bash

###############################################
# © Copyright Marc Jorge <git@thewolfx41.dev> #
# Licensed under GNU GPLv3                    #
###############################################


# Color Constants
C_NC='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;96m'

# Script Metadata
_UNIX_SCRIPT_AUTHOR_='Marc Jorge'
_UNIX_SCRIPT_VERSION_='1.0'

# Server Task Definitions on SSH port 53
declare -A VAR_SERVERS_53=(
  ["super.server.local"]="full_apt yarn_global_upgrade upgrade_node_exporter restart_nginx restart_grafana restart_loki restart_prometheus"
)

# Server Task Definitions on SSH port 22
declare -A VAR_SERVERS_22=(
  ["super.server.v2.local"]="full_apt restart_php_fpm restart_nginx"
)

function _spinner() {
    local on_success="DONE"
    local on_fail="FAIL"
    local nc="\033[0m"
    local color

    case $1 in
        start)
            let column=$(tput cols)-${#2}-8
            echo -ne "${2}"
            printf "%${column}s"
            sp='|/-\'
            delay=${SPINNER_DELAY:-0.15}
            while :; do
                for (( i=0; i<${#sp}; i++ )); do
                    echo -ne "\b${sp:$i:1}"
                    sleep $delay
                done
            done
            ;;
        stop)
            kill $3 > /dev/null 2>&1
            echo -en "\b["
            color=$([[ $2 -eq 0 ]] && echo "${C_GREEN}" || echo "${C_RED}")
            echo -en "${color}${on_success}${nc}]"
            echo
            ;;
        *)
            echo "Invalid argument, try {start/stop}"
            exit 1
            ;;
    esac
}

function start_spinner {
    _spinner "start" "$1" &
    _sp_pid=$!
    disown
}

function stop_spinner {
    _spinner "stop" $? $_sp_pid
    unset _sp_pid
}

# Task Functions
function run_ssh_command() {
    ssh -T "root@$1" -p "$2" <<EOL > /dev/null 2>&1
$3
EOL
}

function full_apt() {
    start_spinner "Updating dependencies"
    run_ssh_command "$1" "$2" '
        export DEBIAN_FRONTEND=noninteractive &&
        apt update &&
        apt -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade &&
        apt -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade &&
        apt -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" full-upgrade &&
        apt -y autoremove
    '
    stop_spinner
}

function yarn_global_upgrade() {
    start_spinner "Updating NPM dependencies"
    run_ssh_command "$1" "$2" 'yarn global upgrade'
    stop_spinner
}

function service_restart() {
    start_spinner "Restarting $3"
    run_ssh_command "$1" "$2" "systemctl restart $3.service"
    stop_spinner
}

function upgrade_node_exporter() {
    start_spinner "Upgrading Node Exporter"
    run_ssh_command "$1" "$2" "
        cd /tmp &&
        find /tmp -name 'node_exporter*' -exec rm -rf {} + &&
        LATEST_VERSION_NODE_EXPORTER=$(git ls-remote --refs --sort='version:refname' --tags https://github.com/prometheus/node_exporter | cut -d/ -f3 | tail -n1 | grep -Po -m 1 '(\d\.\d(?:\.\d)?)') &&
        if test -f /usr/local/bin/node_exporter; then
            LOCAL_VERSION_NODE_EXPORTER=\$(node_exporter --version | grep -Po -m 1 '(\d\.\d(?:\.\d)?)') &&
            if [ '$LOCAL_VERSION_NODE_EXPORTER' != '$LATEST_VERSION_NODE_EXPORTER' ]; then
                mkdir /tmp/node_exporter &&
                curl -O -L 'https://github.com/prometheus/node_exporter/releases/download/v$LATEST_VERSION_NODE_EXPORTER/node_exporter-$LATEST_VERSION_NODE_EXPORTER.linux-amd64.tar.gz' &&
                tar -xzf 'node_exporter-$LATEST_VERSION_NODE_EXPORTER.linux-amd64.tar.gz' -C /tmp/node_exporter --strip-components=1 &&
                systemctl stop node_exporter.service &&
                cp /tmp/node_exporter/node_exporter /usr/local/bin &&
                systemctl start node_exporter.service &&
                rm -rf /tmp/node_exporter*
            fi
        fi
    "
    stop_spinner
}

function process_servers() {
    local -n servers=$1
    local port=$2

    for server in "${!servers[@]}"; do
        echo -e "${C_YELLOW}Updating:${C_NC} ${C_CYAN}$server${C_NC}"
        IFS=' ' read -r -a tasks <<< "${servers[$server]}"
        for task in "${tasks[@]}"; do
            case $task in
                "full_apt") full_apt "$server" "$port" ;;
                "yarn_global_upgrade") yarn_global_upgrade "$server" "$port" ;;
                "upgrade_node_exporter") upgrade_node_exporter "$server" "$port" ;;
                "restart_nginx") service_restart "$server" "$port" "nginx" ;;
                "restart_grafana") service_restart "$server" "$port" "grafana-server" ;;
                "restart_loki") service_restart "$server" "$port" "loki" ;;
                "restart_prometheus") service_restart "$server" "$port" "prometheus" ;;
                "restart_redis") service_restart "$server" "$port" "redis-server" ;;
                "restart_php_fpm") service_restart "$server" "$port" "php7.4-fpm" ;;
                *) ;;
            esac
        done
        if [ "$REBOOT" = true ]; then
            reboot_server "$server" "$port"
        fi
        echo -e "${C_RED}----------------------------------${C_NC}"
    done
}

function reboot_server() {
    start_spinner "Rebooting Server"
    run_ssh_command "$1" "$2" 'shutdown -r now "Reboot from server-patcher script"'
    stop_spinner
}

REBOOT=false
for arg in "$@"; do
    if [ "$arg" == "--reboot" ]; then
        REBOOT=true
        break
    fi
done

cat << "EOF"
   _____
  / ____|
 | (___   ___ _ ____   _____ _ __
  \___ \ / _ \ '__\ \ / / _ \ '__|
  ____) |  __/ |   \ V /  __/ |
 |_____/ \___|_|    \_/ \___|_|
 |  __ \    | |     | |
 | |__) |_ _| |_ ___| |__   ___ _ __
 |  ___/ _` | __/ __| '_ \ / _ \ '__|
 | |  | (_| | || (__| | | |  __/ |
 |_|   \__,_|\__\___|_| |_|\___|_|

EOF
echo -e "[$_UNIX_SCRIPT_AUTHOR_] # (v$_UNIX_SCRIPT_VERSION_)\n\n"

process_servers VAR_SERVERS_53 53
process_servers VAR_SERVERS_22 22

exit 0

