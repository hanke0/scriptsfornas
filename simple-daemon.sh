#!/bin/bash

set +e

echo_usage() {
	echo "Usage: $0 {start|stop|restart|create|list} <name> [program]"
	echo "Simple process manager."
	echo
	echo "Environment:"
	echo "  RUNUSER:   process runing user."
	echo "  HOMEDIR:   process install home."
	echo "  TZ:        process runing timezone."
	echo "  DEBUG:     open debug mode when it set true."
    echo
    echo "Examples:"
    echo "  $0 create foo /bin/foo.sh   # create a new daemon process name foo, run /bin/foo.sh"
    echo "  $0 start foo                # start the daemon process name foo"
    echo "  $0 stop foo                 # stop the daemon process name foo"
    echo "  $0 restart foo              # restart the daemon process name foo"
    echo "  $0 list                     # list all daemon processes"
    echo "  $0 list -s                  # list all daemon processes in short mode"
    echo "  $0 status foo               # show the status of the daemon process name foo"
}

bad_usage() {
	echo_usage >&2
	exit 1
}

help_check() {
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			echo_usage
			exit 0
			;;
		*)
			shift
			;;
		esac
	done
}

help_check "$@"

runuser="${RUNUSER:-1000}"
tzinfo="${TZ:-Asia/Shanghai}"
homedir="${HOMEDIR:-}"

[[ "$runuser" =~ ^([a-z0-9\\-_]+)(:[a-z0-9\\-_]+)?$ ]] || {
	echo >&2 "runuser is invalid"
	exit 1
}

user=$(echo "$runuser" | cut -d: -f1)
userid=$(id -u "$user")
if [ -z "$userid" ]; then
	echo >&2 "user $user not found"
	exit 1
fi

userhome=$(eval echo "~$(id -un "$userid")")
if [ -z "$userhome" ]; then
	echo >&2 "user home not found"
	exit 1
fi
if [ -z "$homedir" ]; then
	homedir="${userhome}/custom-services"
fi
if [ ! -d "$homedir" ]; then
	mkdir -p "$homedir" || exit 1
fi

good_name() {
	[[ "$name" =~ ^[0-9a-z_]+$ ]]
}

name_check() {
	if ! good_name "$name"; then
		echo >&2 "name is invalid"
		bad_usage
	fi
}

debug() {
	[ "${DEBUG}" = true ] && echo >&2 "$@"
}

init_proc_var() {
	name="$1"
	name_check "$name"
	debug "service user is ${runuser}"
	debug "service home dir is ${homedir}"
	pidfile="${homedir}/$name.pid"
	shfile="${homedir}/$name.sh"
	logfile="${homedir}/$name.log"
	hisfile="${homedir}/$name.his"
	chown "${runuser}" -R "${homedir}"
}

create() {
	local program
	init_proc_var "$1"
	program="$(realpath "$2")"
	if [ ! -x "$program" ]; then
		echo >&2 "program is not executeable: $program"
		bad_usage
	fi
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
	chown "$runuser" "$shfile"
}

getpid_from_pidfile() {
	if [ -f "$pidfile" ]; then
		cat "$pidfile"
	fi
}

start() {
	init_proc_var "$1"
	[ -x "$shfile" ] || {
		echo >&2 "$name not exists, create it first"
		exit 1
	}
	pid=$(getpid_from_pidfile)
	if [ -n "$pid" ]; then
		if pidexist $pid; then
			echo "already running: $pid"
			exit 0
		fi
	fi
	debug "starting: setsid $shfile"
	gosu "$runuser" setsid --fork bash "$shfile"
	code=$?
	debug "started code $code"
	sleep 1
	if ! show_status; then
		echo >&2 "see more logs using"
		echo >&2 "tail -F ${logfile}"
		return 1
	fi
}

pidexist() {
	kill -0 "$1" >/dev/null 2>&1
}

stop() {
	init_proc_var "$1"
	pid=$(getpid_from_pidfile)
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

show_status() {
	pid=$(getpid_from_pidfile)
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

status() {
	init_proc_var "$1"
	show_status "$1"
}

list() {
	local name code
	for name in $(find "${homedir}" -maxdepth 1 -mindepth 1 -name '*.sh' -exec basename {} \;); do
		[ -z "$name" ] && continue
		name="${name%.*}"
        if [ "$1" = "-s" ]; then
            printf '%s ' "$name"
            continue
        fi
		code=running
		if ! "$0" status "$name"; then
			code=stopped
		fi
		echo >&2 "--- $name is $code ---"
	done
    echo
}

action="$1"
shift
case "$action" in
create)
	create "$@"
	;;
start)
	start "$@"
	;;
stop)
	stop "$@"
	;;
status)
	status "$@"
	;;
restart)
	stop "$@"
	start "$@"
	;;
list)
	list "$@"
	;;
*)
	bad_usage
	;;
esac
