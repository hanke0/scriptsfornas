#!/usr/bin/env bash

set -e
set -o pipefail

usage="
Usage: ${0##*/} [OPTION]... command -- <exec> [OPTION]...
Starting a simple daemon useing init style.

COMMAND
    start
    stop
    status
    restart
    reload
    force-reload

OPTION:
    -b --basedir=DIR          base directory of pidfile and (logfile default to /var).
    -p --pidfile=FILE         set pid file(default to \$basedir/run.\$basenameofexec.pid)
    -l --logout=FILE          set log output file(default to \$basedir/log/\$basenameofexec.log)
    -s --signal=SIGNAL        signal number to kill a process(default to 15 SIGTERM)
    -w --workdir=DIR          working directory (default to exec directory).
    -n --name=STRING          daemon name (default to \$basenameofexec)
"

. "$(dirname "$(realpath "$0")")/base-for-all.sh"

getopt_from_usage "$usage" "$@"
require_basic_commands

pidofproc() {
    local pidfile pid pattern status
    pidfile="$1"
    pattern="$2"

    if [ -n "${pidfile:-}" ]; then
        if [ -r "$pidfile" ]; then
            read -r pid<"$pidfile"
            if [ -n "${pid:-}" ]; then
                if $(kill -0 "${pid:-}" 2>/dev/null); then
                    echo "$pid"
                    return 0
                elif ps "${pid:-}" >/dev/null 2>&1; then
                    echo "$pid"
                    return 0 # program is running, but not owned by this user
                else
                    return 1 # program is dead and /var/run pid file exists
                fi
            fi
        else
            return 4 # pid file not readable, hence status is unknown.
        fi
    fi
    pid="$(ps -ef | grep -v grep | grep "$pattern" | awk '{print $2}')"
    echo "*** $pid"
    if [ -z "$pid" ]; then
        return 3 # program is not running
    fi
    xargs <<<"$pid"
    return 0
}

COMMAND="${PARAMS[0]}"
PARAMS=("${PARAMS[@]:1}")
EXECNAME="${PARAMS[0]}"
BASEEXEC="${EXECNAME##*/}"
if [ -z "$EXECNAME" ] || [ -z "$BASEEXEC" ]; then
    echo "execute command must provided"
    exit 1
fi
if [ -z "$NAME" ]; then
    NAME="$BASEEXEC"
fi
if ! option_has_set BASEDIR; then
    BASEDIR="/var"
fi
if ! option_has_set WORKDIR; then
    WORKDIR="$(dirname "$EXECNAME")"
fi
if ! option_has_set PIDFILE; then
    PIDFILE="$BASEDIR/run/$NAME.pid"
fi
if [ -z "$LOGOUT" ]; then
    LOGOUT="$BASEDIR/log/$NAME.log"
fi
if [ -z "$SIGNAL" ]; then
    SIGNAL=SIGTERM
fi

start_daemon() {
    local status pid cmd execargs i

    pid="$(pidofproc "$PIDFILE" "${PARAMS[*]}" || true)"
    if [ -n "$pid" ]; then
        echo "$NAME is running $pid"
        return 0
    fi

    for i in "${PARAMS[@]}"; do
        execargs+="'$i' "
    done

    # https://stackoverflow.com/questions/58905011/is-it-possible-to-include-a-nohup-command-inside-a-bash-script
    cmd="cd '$WORKDIR'; trap '' HUP; nohup $execargs >'$LOGOUT' 2>&1 </dev/null & echo \$! >'$PIDFILE';"
    /bin/bash -c "$cmd"
}

stop_daemon() {
    local pid
    pid="$(pidofproc "$PIDFILE" "$PATTERN" || true)"
    if [ -z "$pid" ]; then
        return 0
    fi
    kill -$SIGNAL $pid
}

status_daemon() {
    local status
    status=0
    pidofproc "$PIDFILE" "$NAME" >/dev/null || status=$?
    if [ "$status" = 0 ]; then
        echo "$NAME is running"
        return 0
    elif [ "$status" = 4 ]; then
        echo "could not access PID file for $NAME"
        return $status
    else
        echo "$NAME is not running"
        return $status
    fi
}

case "$COMMAND" in
start)
    start_daemon
    ;;
stop)
    stop_daemon
    ;;
restart)
    stop_daemon
    sleep 2
    start_daemon
    ;;
status)
    status_daemon
    ;;
*)
    echo "Usage: $0 {start|stop|status|restart}"
    exit 2
    ;;
esac
