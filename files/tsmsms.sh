#!/bin/sh

INITFILE=/etc/init.d/tsmsms
SERVICE_PID_FILE=/var/run/tsmsms.pid
APP=$0
PAR1=$1
PAR2=$2

usage() {
    echo "Usage: $APP [ COMMAND [ OPTIONS ] ]"
    echo "Without any command Tsmsms will be runned in the foreground without debug mode"
    echo
    echo "Commands are:"
    echo "    start|stop|restart|reload     controlling the daemon"
    echo "    debug                         run in debug mode"
    echo "    help                          show this and exit"
    doexit
}
callinit() {
    [ -x $INITFILE ] || {
        echo "No init file '$INITFILE'"
        return
    }
    RETVAL=$?
}
run() {
    uci set tsmsms.general.debug='0'
    uci commit tsmsms
    exec /usr/bin/lua /usr/lib/lua/tsmsms/app.lua
    RETVAL=$?
}

debug() {
    tsmsms stop
    uci set tsmsms.general.debug='1'
    [ -n "$PAR2" ] || {
        exec /usr/bin/lua /usr/lib/lua/tsmsms/app.lua
    }
    [ -n "$PAR2" ] && {
        uci set tsmsms.general.param=$PAR2
    }
    [ -n "$PAR2" ] || {
        uci delete tsmsms.general.param
    }
    uci commit tsmsms
    sleep 1
    RETVAL=$?
}

doexit() {
    exit $RETVAL
}

[ -n "$INCLUDE_ONLY" ] && return

CMD="$1"
[ -z $CMD ] && {
    run
    doexit
}
shift
# See how we were called.
case "$CMD" in
    start|restart|reload)
echo STARTING $CMD
        callinit $CMD
        ;;
    debug)
        debug
        ;;
    stop)
        uci set tsmsms.general.debug='0'
        uci commit tsmsms
        callinit $CMD
        ;;
    *help|*?)
        usage $0
        ;;
    *)
        RETVAL=1
        usage $0
        ;;
esac

doexit
