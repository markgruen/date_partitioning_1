#!/bin/bash
#
# run benchmarks test suite
#

function usage {
   echo "Usage: $0 [--first-engine=ENGINE] [--sleep-time=SLEEP] [--outfile|-o FILE]" 1>&2
   exit 1
}

SHORT=ho:
LONG=first-engine:,sleep-time:,outfile:

OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")

if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# set initial values

FIRST=innodb
SLEEP=60
FILE="testout_$(date +"%Y%m%d_%H:%M:%S")"

while true ; do
    case "$1" in
        --first-engine ) FIRST="$2"; shift 2;;
        --sleep-time ) SLEEP="$2"; shift 2;;
        --outfile|-o ) FILE="$2"; shift 2;;
        -- ) shift; break ;;
        * ) usage ;;
    esac
done

echo "
FIRST: $FIRST
SLEEP: $SLEEP
FILE: $FILE"

function innodb
{
echo "----------- INNODB --------------"
./run_part_sysbench.sh --threads 1 --read-pct 60 --engine innodb "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100 --engine innodb "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100  --point-select-pct=100 --engine innodb "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 60 --engine innodb "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100 --engine innodb "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100  --point-select-pct=100 --engine innodb "$FILE"
sleep "$SLEEP"
}

function tokudb
{
echo "----------- TOKUDB --------------"
./run_part_sysbench.sh --threads 1 --read-pct 60 --engine tokudb "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100 --engine tokudb "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 1 --read-pct 100 --point-select-pct=100 --engine tokudb "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 60 --engine tokudb "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100 --engine tokudb "$FILE"
sleep "$SLEEP"
./run_part_sysbench.sh --threads 3 --read-pct 100 --point-select-pct=100 --engine tokudb "$FILE"
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
