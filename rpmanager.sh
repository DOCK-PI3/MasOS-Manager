#!/bin/bash
# rpmanager.sh
###############
#
# The RetroPie-Manager's manager.
#
# This script MUST be in the same directory RetroPie-Manager's directory.
# If it's installed in "/opt/retropie/supplementary/retropie-manager/",
# and only in this case, the user can make symbolic links to it. Otherwise,
# the symbolic links won't work.
#
# The RetroPie-Manager can not be started directly by the root user, but
# but if you need it (ex.: on boot), use the --user option. The user must
# be a RetroPie user (must have a RetroPie directory tree in its homedir).
# If it's called in a "sudo environment", it's OK, the sudo user will start
# the service.
#
# If the --log option is used, the log messages will be saved in
# "/opt/retropie/supplementary/retropie-manager/logs" ($rpmanager_dir/logs)
# with an appropriate file name
#
# Execute it with --help to see the available options.
#

# global variables ##########################################################

rpmanager_dir=$(dirname $0)

usage="$(basename $0) OPTIONS"

help_message="Usage: $usage

The OPTIONS are:

-h|--help           print this message and exit

--start             start the RetroPie-Manager

--stop              stop the RetroPie-Manager

--isrunning         show if RetroPie-Manager is running and the
                    listening port and exit

--log               save the log messages (optional, default: not save log
                    messages, only works with --start)

-u|--user USER      start RetroPie-Manager as USER (only available for
                    privileged users, only works with --start, USER must 
                    be a RetroPie user)

The --start and --stop options are, obviously, mutually exclusive. If the
user uses both, only the first works."

# default TCP port to listen
port=8000

# the default is not save log files
log_command="&> /dev/null"

# getting the caller username
user="$SUDO_USER"
[[ -z "$user" ]] && user=$(id -un)



##############################################################################
# Set the user that will start the RetroPie-Manager. Only privileged users
# can use this function. The user MUST have a RetroPie directory tree in
# its homedir.
#
# Globals:
#   user
# Arguments:
#   $1  a valid RetroPie user name
# Returns:
#   0, if a the user is setted correctly
#   non-zero, otherwise
##############################################################################
function set_user() {
    if [[ $(id -u) -ne 0 ]]; then
        echo "Error: only privileged users (ex.: root) can use --user option." >&2
        return 1
    fi

    if [[ ! -d "/home/$1/RetroPie/" ]]; then
        echo "Error: the user '$1' is not a RetroPie user." >&2
        return 1
    fi

    user="$1"
    return 0
}


##############################################################################
# Check if RetroPie-Manager is running. If positive, fill the $port global
# variable with current listening port.
#
# Globals:
#   port
# Arguments:
#   None
# Returns:
#   0, if RetroPie-Manager is running
#   non-zero, otherwise
##############################################################################
function is_running() { 
    local return_value

    pgrep -f 'python.*manage\.py.*runserver' &>/dev/null
    return_value=$?

    if [[ "$return_value" != "0" ]]; then
        return $return_value
    fi

    # ok... maybe there is a more elegant way to obtain the current
    # listening port, but let's use this way for a while.
    port=$(
        ps ax \
        | grep -m 1 -o 'python.*manage\.py.*runserver.*--noreload' \
        | grep -o '0.0.0.0:[^ ]*' \
        | cut -d: -f2
    )
    return $return_value
}


##############################################################################
# Starts the RetroPie-Manager service. It gives an error if it's called
# directly by the root user, but if it's called by an "sudo environment",
# RetroPie-Manager is started by the sudo user.
#
# Globals:
#   log_command
#   user
# Arguments:
#   None
# Returns:
#   1, if it's unable to start RetroPie-Manager
#   0, if RetroPie-Manager is successfully started
##############################################################################
function start_service() {
    if is_running; then
        echo "Nothing done. RetroPie-Manager is already running and listening at $port." >&2
        return 1
    fi

    local startcmd="${rpmanager_dir}/bin/python \
                      ${rpmanager_dir}/manage.py \
                      runserver 0.0.0.0:$port \
                      --settings=project.settings_production \
                      --noreload \
                      $log_command"

    # RetroPie-Manager should not be started directly by the root user,
    # but we can deal if it's called by a "sudo environment" or with
    # the --user option.
    if [[ $(id -u) -eq 0 ]]; then
        if [[ $(id -u "$user") -eq 0 ]]; then
            echo "Error: RetroPie-Manager can't be started directly by root!" >&2
            echo "Try to use '--user' option" >&2
            return 1
        fi
        startcmd="su -c '$startcmd' $user"
    fi

    echo "Starting RetroPie-Manager..."
    eval $startcmd &>/dev/null &
    sleep 3
    if is_running; then
        echo "RetroPie-Manager is running and listening at port $port"
        return 0
    else
        echo "Error: It seems that RetroPie-Manager had some problem to start!" >&2
        return 1
    fi
}


##############################################################################
# Stops the RetroPie-Manager service if it's running.
#
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0, if RetroPie-Manager process is successfully killed
#   1, if unable to kill RetroPie-Manager
#   2, if RetroPie-Manager wasn't running from the start
##############################################################################
function stop_service() {
    if is_running; then
        echo "Stopping RetroPie-Manager..."
        sudo kill -9 $(pgrep -f 'python.*manage\.py.*runserver')
        sleep 1
        if is_running; then
            echo "Error: Unable to kill RetroPie-Manager process." >&2
            return 1
        else
            echo "RetroPie-Manager has been stopped."
            return 0
        fi
    fi

    echo "Nothing done. RetroPie-Manager wasn't running." >&2
    return 2
}


# starting point #############################################################

# OBS.: the double [[ ]] test style doesn't work with '-a' or '-o' option.
if [ ! -x "$rpmanager_dir/bin/python" -a ! -f "$rpmanager_dir/manage.py" ]; then
    rpmanager_dir="/opt/retropie/supplementary/retropie-manager"
    if [[ ! -d "$rpmanager_dir" ]]; then
        echo "Error: $(basename $0) MUST be in the RetroPie-Manager's directory" >&2
        exit 1
    fi
fi


if [[ -z "$1" ]]; then
    echo "Error: missing arguments" >&2
    echo "$help_message" >&2
    exit 1
fi


# the following variables work like flags. they are used to deal with 
# the command line options.
f_start=0
f_stop=0

while [[ "$1" ]]; do
    case "$1" in

    -h|--help)
        echo "$help_message"
        exit 0
    ;;

    --isrunning)
        if is_running; then
            echo "RetroPie-Manager is running and listening at port $port"
            exit 0
        else
            echo "RetroPie-Manager is not running"
            exit 1
        fi
    ;;

    --start)
        if [[ "$f_stop" = "0" ]]; then
            f_start=1
        else
            echo "Warning: ignoring '--start' option" >&2
            f_start=0
        fi
    ;;

    --stop)
        if [[ "$f_start" = "0" ]]; then
            f_stop=1
        else
            echo "Warning: ignoring '--stop' option" >&2
            f_stop=0
        fi
    ;;

    --log)
        if [[ "$f_start" = "0" ]]; then
            echo "Warning: ignoring '--log' option" >&2
            shift
            continue
        fi
        log_dir="${rpmanager_dir}/logs"
        mkdir -p "$log_dir"
        log_command="&> ${log_dir}/rpmanager-$(date +%Y-%m-%d-%H%M%S).log"
    ;;

    -u|--user)
        if [[ "$f_start" = "0" ]]; then
            echo "Error: the '--user' option is used with '--start' only" >&2
            exit 1
        fi
        shift
        set_user "$1" || exit $?
    ;;

    *)  echo "Invalid option: $1" >&2
        exit 1
    ;;
    esac

    # shifting for the next option
    shift
done

[[ "$f_start" = "1" ]] && {
    start_service
    exit $?
}

[[ "$f_stop" = "1" ]] && {
    stop_service
    exit $?
}
