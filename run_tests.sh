#!/bin/bash
#
# run benchmarks test suite
#

function usage {
   echo "Usage: $0 [--first-engine=ENGINE] [--sleep-time=SLEEP] [--outfile|-o FILE] [--port|-P=N" 1>&2
   exit 1
}

SHORT=ho:P:
LONG=first-engine:,sleep-time:,port:,outfile:

OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")

if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# set initial values

FIRST=innodb
SLEEP=60
PORT=5728
FILE="testout_$(date +"%Y%m%d_%H:%M:%S")"

while true ; do
    case "$1" in
        --first-engine ) FIRST="$2"; shift 2;;
        --sleep-time ) SLEEP="$2"; shift 2;;
        --outfile|-o ) FILE="$2"; shift 2;;
        --port|-P ) PORT="$2"; shift 2;;
        -- ) shift; break ;;
        * ) usage ;;
    esac
done

echo "
# FIRST: $FIRST
# SLEEP: $SLEEP
# PORT: $PORT
# FILE: $FILE"

function innodb
{
echo "----------- INNODB --------------"
echo ./run_part_sysbench.sh --threads 1 --read-pct 60 --engine innodb --port=$PORT --outfile "$FILE"
./run_part_sysbench.sh --threads 1 --read-pct 60 --engine innodb --port=$PORT --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100 --engine innodb --port=$PORT --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100  --point-select-pct=100 --engine innodb --port=$PORT --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 60 --engine innodb --port=$PORT --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100 --engine innodb --port=$PORT --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100  --point-select-pct=100 --engine innodb --port=$PORT --outfile "$FILE"
sleep "$SLEEP"
}

function tokudb
{
echo "----------- TOKUDB --------------"
./run_part_sysbench.sh --threads 1 --read-pct 60 --engine tokudb --port=$PORT --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100 --engine tokudb --port=$PORT --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100 --point-select-pct=100 --engine tokudb --port=$PORT --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 60 --engine tokudb --port=$PORT --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100 --engine tokudb --port=$PORT --outfile "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100 --point-select-pct=100 --engine tokudb --port=$PORT --outfile "$FILE"
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
