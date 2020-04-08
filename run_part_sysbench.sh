#!/bin/bash
#
# run benchmarks
#
# Todo: add --warmup-time for the start of each test series 

function usage {
   echo "Usage: $0 [-P|--port=PORT] [--threads=THREADS] [--read-pct=READ_PCT] [--engine=ENGINE] [--point-select-pct=POINT_SELECT_PCT]
   [--test-iterations=N] [--run-time=T] [--wait-time=W] [--group-warmup-time=WT] [-w] [--outfile|-o FILE]" 1>&2
   exit 1
}

function do_compress {
# compress all but the current log
for f in $(ls data/mysqlsandbox1-slow_log.0*[0-9] | head -n -2)
do
sleep 10
echo "# compressing $f"
echo "set global slow_query_log=0" | ./use 
gzip "$f"
echo "set global slow_query_log=1;set global max_slowlog_size=500*1024*1024" | ./use 
done
}

SHORT=ho:wP:z
LONG=help,threads:,read-pct:,engine:,point-select-pct:,test-iterations:,run-time:,wait-time:,outfile:,port:,group-warmup-time:

OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")

if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

# set initial values

THREADS=1
PORT=5728
READ_PCT=60
ENGINE=innodb
POINT_SELECT_PCT=0
TEST_ITERATIONS=3
RUN_TIME=300
WAIT_TIME=60
WARMUP_TIME=180
WARMUP=false
OUTFILE="test_out_${ro}_${ENGINE}_${THREADS}"
TEE="tee"
COMP=false

while true ; do
    case "$1" in
        --threads ) THREADS="$2"; shift 2;;
        --read-pct ) READ_PCT="$2"; shift 2;;
        --engine ) ENGINE="$2"; shift 2;;
        --point-select-pct ) POINT_SELECT_PCT="$2"; shift 2;;
        --test-iterations ) TEST_ITERATIONS="$2"; shift 2;;
        --run-time ) RUN_TIME="$2"; shift 2;;
        --wait-time ) WAIT_TIME="$2"; shift 2;;
        --group-warmup-time ) 
            WARMUP_TIME="$2"
            if [ $WARMUP_TIME -gt 0 ]; then 
                WARMUP=true
            else
                WARMUP=false
            fi
            shift 2;;
        --port|-P ) PORT="$2"; shift 2;;
        --outfile|-o) OUTFILE="$2"; TEE="tee -a"; shift 2;;
        -z) COMP=true; shift 1;;
        -w ) WARMUP=true; shift; break ;;
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
    echo "WARMUP: $WARMUP_TIME"

    if [ "$WARMUP" == true -a $i -eq 1 ]; then
        echo "Running RO warmup for $WARMUP_TIME sec"
        sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=$PORT --mysql-host=127.0.0.1 --mysql-db=test --time=$WARMUP_TIME --report-interval=5 \
        --end-date='2019-11-01 00:00:00' \
        --threads=$THREADS \
        --point_select_id=$POINT_SELECT_PCT \
        --read_pct=100 run > /dev/null
        echo "Finished RO warmup "
    fi

    date '+START: %Y-%m-%d %H:%M:%S'

    sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=$PORT --mysql-host=127.0.0.1 --mysql-db=test --time=$RUN_TIME --report-interval=5 \
    --end-date='2019-11-01 00:00:00' \
    --threads=$THREADS \
    --point_select_id=$POINT_SELECT_PCT \
    --histogram=on \
    --read_pct=$read_pct run

    date '+END: %Y-%m-%d %H:%M:%S'
    if [ "$COMP" == true ]; then
        do_compress
    fi
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
    echo "WARMUP: $WARMUP_TIME"

    if [ "$WARMUP" == true -a $i -eq 1 ]; then
        echo "Running RO warmup for $WARMUP_TIME sec"
        sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=$PORT --mysql-host=127.0.0.1 --mysql-db=test --time=$WARMUP_TIME --report-interval=5 \
        --end-date='2019-11-01 00:00:00' \
        --threads=$THREADS \
        --point_select_id=$POINT_SELECT_PCT \
        --read_pct=100 run > /dev/null
        echo "Finished RO warmup "
    fi

    date '+START: %Y-%m-%d %H:%M:%S'

    sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=$PORT --mysql-host=127.0.0.1 --mysql-db=test --time=$RUN_TIME --report-interval=5 \
    --end-date='2019-11-01 00:00:00' \
    --threads=$THREADS \
    --point_select_id=$POINT_SELECT_PCT \
    --histogram=on \
    --read_pct=$read_pct run

    date '+END: %Y-%m-%d %H:%M:%S'
    if [ "$COMP" == true ]; then
        do_compress
    fi
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
        echo "WARMUP: $WARMUP_TIME"

        if [ "$WARMUP" == true -a $i -eq 1 ]; then
            echo "Running RO warmup for $WARMUP_TIME sec"
            sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=$PORT --mysql-host=127.0.0.1 --mysql-db=test --time=$WARMUP_TIME --report-interval=5 \
            --end-date='2019-11-01 00:00:00' \
            --threads=$THREADS \
            --point_select_id=$POINT_SELECT_PCT \
            --read_pct=100 run > /dev/null
            echo "Finished RO warmup "
        fi

        date '+START: %Y-%m-%d %H:%M:%S'

        sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=$PORT --mysql-host=127.0.0.1 --mysql-db=test --time=$RUN_TIME --report-interval=5 \
        --end-date='2019-11-01 00:00:00' \
        --threads=$THREADS \
        --point_select_id=$POINT_SELECT_PCT \
        --histogram=on \
        --read_pct=$read_pct run

        date '+END: %Y-%m-%d %H:%M:%S'
        if [ "$COMP" == true ]; then
            do_compress
        fi
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
        echo "WARMUP: $WARMUP_TIME"

        if [ "$WARMUP" == true -a $i -eq 1 ]; then
            echo "Running RO warmup for $WARMUP_TIME sec"
            sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=$PORT --mysql-host=127.0.0.1 --mysql-db=test --time=$WARMUP_TIME --report-interval=5 \
            --end-date='2019-11-01 00:00:00' \
            --threads=$THREADS \
            --point_select_id=$POINT_SELECT_PCT \
            --read_pct=100 run > /dev/null
            echo "Finished RO warmup "
        fi

        date '+START: %Y-%m-%d %H:%M:%S'

        sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=$PORT --mysql-host=127.0.0.1 --mysql-db=test --time=$RUN_TIME --report-interval=5 \
        --end-date='2019-11-01 00:00:00' \
        --threads=$THREADS \
        --point_select_id=$POINT_SELECT_PCT \
        --histogram=on \
        --read_pct=$read_pct run

        date '+END: %Y-%m-%d %H:%M:%S'
        if [ "$COMP" == true ]; then
            do_compress
        fi
        sleep $WAIT_TIME
    done
    echo "RESETTING BIG TO PARTITIONED"
    echo "rename table big to _big_comp_nonpart, _big_part to big;" | ./use -vvv test
else
    echo "RESETTING BIG TO PARTITIONED"
    echo "rename table big to _big_nonpart, _big_part to big;" | ./use -vvv test
fi
) | $TEE $OUTFILE
