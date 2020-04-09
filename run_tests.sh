#!/bin/bash
#
# run benchmarks test suite
#

function usage {
   echo "Usage: $0 [--first-engine=ENGINE] [--sleep-time=SLEEP] [--outfile|-o FILE] [--port|-P=N] [--group-warmup-time=T] [-z]" 1>&2
   exit 1
}

SHORT=ho:P:z
LONG=first-engine:,sleep-time:,port:,outfile:,group-warmup-time:

OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")

if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# set initial values

FIRST=innodb
SLEEP=60
PORT=5728
FILE="testout_$(date +"%Y%m%d_%H:%M:%S")"
WARMUP_TIME=0
COMP=false

while true ; do
    case "$1" in
        --first-engine ) FIRST="$2"; shift 2;;
        --sleep-time ) SLEEP="$2"; shift 2;;
        --outfile|-o ) FILE="$2"; shift 2;;
        --port|-P ) PORT="$2"; shift 2;;
        --group-warmup-time ) WARMUP_TIME="$2"; shift 2;;
        -z ) COMP=true; shift;;
        -- ) shift; break ;;
        * ) usage ;;
    esac
done

if [ "$COMP" == true ]; then
    Z="-z"
else
    Z=""
fi

echo "
# FIRST: $FIRST
# SLEEP: $SLEEP
# PORT: $PORT
# FILE: $FILE"

function innodb
{
echo "----------- INNODB --------------"
./run_part_sysbench.sh --threads 1 --read-pct 60 --engine innodb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100 --engine innodb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100  --point-select-pct=100 --group-warmup-time=$WARMUP_TIME --engine innodb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 60 --engine innodb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100 --engine innodb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100  --point-select-pct=100 --group-warmup-time=$WARMUP_TIME --engine innodb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
}

function tokudb
{
echo "----------- TOKUDB --------------"
./run_part_sysbench.sh --threads 1 --read-pct 60 --engine tokudb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100 --engine tokudb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100 --point-select-pct=100 --group-warmup-time=$WARMUP_TIME --engine tokudb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 60 --engine tokudb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100 --engine tokudb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100 --point-select-pct=100 --group-warmup-time=$WARMUP_TIME --engine tokudb --port=$PORT "$Z" --outfile "$FILE"
sleep "$SLEEP"
}

if [[ "$FIRST" == "innodb" ]]; then
    innodb
    ./big_change_engine.sh tokudb
    tokudb
else
    tokudb
    ./big_change_engine.sh innodb
    innodb
fi
