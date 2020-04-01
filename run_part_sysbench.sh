#!/bin/bash
#
# run benchmarks
#

function usage {
   echo "Usage: $0 [--threads=THREADS] [--read_pct=READ_PCT] [--engine=ENGINE] [--point-select-pct=POINT_SELECT_PCT]
   [--test-iterations=N] [--run-time=T] [--wait-time=W] [--outfile|-o FILE]" 1>&2
   exit 1
}

SHORT=ho:
LONG=threads:,read-pct:,engine:,point-select-pct:,test-iterations:,run-time:,wait-time:,outfile:

OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")

if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# set initial values

THREADS=1
READ_PCT=60
ENGINE=innodb
POINT_SELECT_PCT=0
TEST_ITERATIONS=3
RUN_TIME=300
WAIT_TIME=60
OUTFILE="test_out_${ro}_${ENGINE}_${THREADS}"
TEE="tee"

while true ; do
    case "$1" in
        --threads ) THREADS="$2"; shift 2;;
        --read-pct ) READ_PCT="$2"; shift 2;;
        --engine ) ENGINE="$2"; shift 2;;
        --point-select-pct ) POINT_SELECT_PCT="$2"; shift 2;;
        --test-iterations ) TEST_ITERATIONS="$2"; shift 2;;
        --run-time ) RUN_TIME="$2"; shift 2;;
        --wait-time ) WAIT_TIME="$2"; shift 2;;
        --outfile|-o) OUTFILE="$2"; TEE="tee -a"; shift 2;;
        -- ) shift; break ;;
        * ) usage ;;
    esac
done

echo "# STARTUP PARAMETERS threads: $THREADS read_pct: $READ_PCT point_select_pct: $POINT_SELECT_PCT engine: $ENGINE test_iterations: $TEST_ITERATIONS run-time: $RUN_TIME wait_time: $WAIT_TIME outfile: $OUTFILE"
#exit 0

# added to ease adding more app parameters
write_pct=$(( 100-$READ_PCT ))
read_pct=$READ_PCT


if [ "$read_pct" -lt 0 -o "$read_pct" -gt 100 ]; then
    echo "ERROR: read_pct = $read_pct is an invalid value"
    exit -1
fi

if [[ "$read_pct" -eq 100 ]]; then
    ro="ro"
else
    ro="rw"
fi



(
echo "show create table big;" | ./use test
for i in $(seq 1 $TEST_ITERATIONS)
do
    echo "########### PARTITION RW ${read_pct} ${write_pct}"
    echo "THREAD: $THREADS"
    echo "READ/WRITE: ${read_pct}:${write_pct}"
    echo "PARTITIONED: YES"
    echo "COMPRESSED: NO"
    echo "POINT_SELECT_PCT: $POINT_SELECT_PCT"
    echo "ENGINE: $ENGINE"
    date '+START: %Y-%m-%d %H:%M:%S'

    sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=5728 --mysql-host=127.0.0.1 --mysql-db=test --time=$RUN_TIME --report-interval=5 \
    --end-date='2019-11-01 00:00:00' \
    --threads=$THREADS \
    --point_select_id=$POINT_SELECT_PCT \
    --histogram=on \
    --read_pct=$read_pct run

    date '+END: %Y-%m-%d %H:%M:%S'
    sleep $WAIT_TIME
done

echo "PREPARING FOR NON PARTITION"
echo "rename table big to _big_part, _big_nonpart to big;" | ./use -vvv test
echo "show create table big;" | ./use test
for i in $(seq 1 $TEST_ITERATIONS)
do
    echo "########### NON PARTITION RW ${read_pct} ${write_pct}"
    echo "THREAD: $THREADS"
    echo "READ/WRITE: ${read_pct}:${write_pct}"
    echo "PARTITIONED: NO"
    echo "COMPRESSED: NO"
    echo "POINT_SELECT_PCT: $POINT_SELECT_PCT"
    echo "ENGINE: $ENGINE"
    date '+START: %Y-%m-%d %H:%M:%S'

    sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=5728 --mysql-host=127.0.0.1 --mysql-db=test --time=$RUN_TIME --report-interval=5 \
    --end-date='2019-11-01 00:00:00' \
    --threads=$THREADS \
    --point_select_id=$POINT_SELECT_PCT \
    --histogram=on \
    --read_pct=$read_pct run

    date '+END: %Y-%m-%d %H:%M:%S'
    sleep $WAIT_TIME
done

if [[ "$ENGINE" == "innodb" ]]; then
    echo "PREPARING FOR PARTITION COMPRESSED"
    echo "rename table big to _big_nonpart, _big_comp to big;" | ./use -vvv test
    echo "show create table big;" | ./use test
    for i in $(seq 1 $TEST_ITERATIONS)
    do
        echo "########### PARTITION COMPRESSED RW ${read_pct} ${write_pct}"
        echo "THREAD: $THREADS"
        echo "READ/WRITE: ${read_pct}:${write_pct}"
        echo "PARTITIONED: YES"
        echo "COMPRESSED: YES"
        echo "POINT_SELECT_PCT: $POINT_SELECT_PCT"
        echo "ENGINE: $ENGINE"
        date '+START: %Y-%m-%d %H:%M:%S'

        sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=5728 --mysql-host=127.0.0.1 --mysql-db=test --time=$RUN_TIME --report-interval=5 \
        --end-date='2019-11-01 00:00:00' \
        --threads=$THREADS \
        --point_select_id=$POINT_SELECT_PCT \
        --histogram=on \
        --read_pct=$read_pct run

        date '+END: %Y-%m-%d %H:%M:%S'
        sleep $WAIT_TIME
    done

    echo "PREPARING FOR NON PARTITION COMPRESSED"
    echo "rename table big to _big_comp, _big_comp_nonpart to big;" | ./use -vvv test
    echo "show create table big;" | ./use test
    for i in $(seq 1 $TEST_ITERATIONS)
    do
        echo "########### NON PARTITION COMPRESSED RW ${read_pct} ${write_pct}"
        echo "THREAD: $THREADS"
        echo "READ/WRITE: ${read_pct}:${write_pct}"
        echo "PARTITIONED: NO"
        echo "COMPRESSED: YES"
        echo "POINT_SELECT_PCT: $POINT_SELECT_PCT"
        echo "ENGINE: $ENGINE"
        date '+START: %Y-%m-%d %H:%M:%S'

        sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=5728 --mysql-host=127.0.0.1 --mysql-db=test --time=$RUN_TIME --report-interval=5 \
        --end-date='2019-11-01 00:00:00' \
        --threads=$THREADS \
        --point_select_id=$POINT_SELECT_PCT \
        --histogram=on \
        --read_pct=$read_pct run

        date '+END: %Y-%m-%d %H:%M:%S'
        sleep $WAIT_TIME
    done
    echo "RESETTING BIG TO PARTITIONED"
    echo "rename table big to _big_comp_nonpart, _big_part to big;" | ./use -vvv test
else
    echo "RESETTING BIG TO PARTITIONED"
    echo "rename table big to _big_nonpart, _big_part to big;" | ./use -vvv test
fi
) | $TEE $OUTFILE
