#!/bin/bash

set +e

users="${RUNUSER:-hanke:users}"
homedir="${HOMEDIR:-/data/custom-services}"
tzinfo="${TZ:-Asia/Shanghai}"

bad_usage() {
    echo >&2 "Usage: $0 {start|stop|restart|create|list} <name> [program]"
    echo >&2 "Simple process manager."
    echo >&2
    echo >&2 "Environment:"
    echo >&2 "  RUNUSER:   process runing user."
    echo >&2 "  HOMEDIR:   process install home."
    echo >&2 "  TZ:        process runing timezone."
    echo >&2 "  DEBUG:     open debug mode when it set true."
    exit 1
}

[ $# -gt 3 ] && bad_usage
action="$1"
name="$2"
program="$3"
if [ "$action" != "list" ]; then
    [[ "$name" =~ ^[0-9a-z_]+$ ]] || {
        echo >&2 "name is invalid"
        bad_usage
    }
fi

debug() {
    [ "${DEBUG}" = true ] && echo >&2 "$@"
}

debug "service user is ${users}"
debug "service home dir is ${homedir}"
pidfile="${homedir}/$name.pid"
shfile="${homedir}/$name.sh"
logfile="${homedir}/$name.log"
hisfile="${homedir}/$name.his"
chown "${users}" -R "${homedir}"

create() {
    cat >"$shfile" <<EOF
set +e
export TZ=${tzinfo}
export LC_ALL=en_US.utf8
cd /tmp || exit 1
umask 027 || exit 1
trap 'kill -s SIGTERM 0' EXIT
ppid=\$\$
printf '%s' "\$ppid" >'$pidfile'
echo "\$ppid" >'$hisfile'
while true; do
    '${program}' >'$logfile' 2>&1 &
    pid=\$!
    printf '%s' "\$ppid \$pid" >'$pidfile'
    echo "\$pid" >>"$hisfile"
    wait "\$pid"
    sleep 1
done

EOF
    chmod 755 "$shfile"
    chown "$users" "$shfile"
}

start() {
    [ -x "$shfile" ] || {
        echo >&2 "$name not exists, create it first"
        return 1
    }
    pid=$(cat "$pidfile")
    if [ -n "$pid" ]; then
        if pidexist $pid; then
            echo "already running: $pid"
            return
        fi
    fi
    debug "starting: setsid $shfile"
    /docker/bin/gosu "$users" setsid --fork bash "$shfile"
    code=$?
    debug "started code $code"
    sleep 1
    if ! status; then
        echo >&2 "see more logs using"
        echo >&2 "tail -F ${logfile}"
        return 1
    fi
}

pidexist() {
    kill -0 "$1" >/dev/null 2>&1
}

stop() {
    pid=$(cat "$pidfile")
    if [ -n "$pid" ]; then
        if pidexist $pid; then
            echo >&2 "kill $pid"
            kill $pid >/dev/null 2>&1
            timeout 5s tail --pid $(firstpid $pid) -f /dev/null
            return 0
        fi
    fi
}

firstpid() {
    echo "$1"
}

status() {
    pid=$(cat "$pidfile")
    if [ -z "$pid" ]; then
        echo >&2 "stopped"
        return 1
    fi
    if ! pidexist $pid; then
        echo >&2 "stopped"
        return 1
    fi
    ps -o user,pid,ppid,s,etime,start,times,rss,cmd -g $(ps -o sid= -p $(firstpid $pid))
    for p in $pid; do
        if ! pidexist $p; then
            echo >&2 "EXITED  $p"
            return 1
        fi
    done
}

list() {
    local name code
    for name in $(find "${homedir}" -maxdepth 1 -mindepth 1 -name '*.sh' -exec basename {} \;); do
        [ -z "$name" ] && continue
        name="${name%.*}"
        code=running
        if ! "$0" status "$name"; then
            code=stopped
        fi
        echo >&2 "--- $name is $code ---"
    done
}

case "$action" in
create)
    [ -e "$program" ] || {
        echo >&2 "program is not executeable"
        bad_usage
    }
    create
    ;;
start)
    start
    ;;
stop)
    stop
    ;;
status)
    status
    ;;
restart)
    stop
    start
    ;;
list)
    list
    ;;
*)
    bad_usage
    ;;
esac
