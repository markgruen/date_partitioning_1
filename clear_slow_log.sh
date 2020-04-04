#!/bin/bash
#
# clear slow query logs
#

function usage {
   echo "Usage: $0 [--all | -a ]" 1>&2
   exit 1
}

SHORT=a
LONG=all

OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")

if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# set initial values

ALL=false

while true ; do
    case "$1" in
        --all | -a) ALL=true; shift 1;;
        -- ) shift; break ;;
        * ) usage ;;
    esac
done

WDIR=$(pwd)
_PATH=$WDIR

if [ "$ALL" == true ]; then
    ls -l $_PATH/data//mysqlsandbox1-slow.log*
    rm $_PATH/data//mysqlsandbox1-slow.log*
else
    ls -l $_PATH/data//mysqlsandbox1-slow.log
    rm $_PATH/data//mysqlsandbox1-slow.log
fi



$_PATH/use -e 'select @@global.long_query_time into @lqt_save; set global long_query_time=2000; select sleep(2); FLUSH LOGS; select sleep(2); set global long_query_time=@lqt_save;'

ls -l $_PATH/data//mysqlsandbox1-slow.log
