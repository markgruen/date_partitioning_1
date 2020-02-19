threads=${1:-1}
read_pct=${2:-60}
engine=${3:-"innodb"}

if [ "$read_pct" -lt 0 -o "$read_pct" -gt 100 ]; then
    echo "ERROR: read_pct = $read_pct is an invalid value"
    exit -1
fi

if [[ "$read_pct" -eq 100 ]]; then
    ro="ro"
else
    ro="rw"
fi

#if [[ "$engine" != "" ]]; then
#    engine="_${engine}"
#fi

out_file=${4:-"test_out_${ro}_${engine}_${threads}"}
write_pct=$(( 100-$read_pct ))
test_iterations=3
run_time=300
wait_time=60

if [[ -z "$4" ]]; then
    TEE="tee"
else
    TEE="tee -a"
fi
    

(
echo "show create table big;" | ./use test
for i in $(seq 1 $test_iterations)
do
    echo "########### PARTITION RW ${read_pct} ${write_pct}"
    echo "THREAD: $threads"
    echo "READ/WRITE: ${read_pct}:${write_pct}"
    echo "PARTITIONED: YES"
    echo "COMPRESSED: NO"
    echo "ENGINE: $engine"
    date '+START: %Y-%m-%d %H:%M:%S'

    sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=5728 --mysql-host=127.0.0.1 --mysql-db=test --time=$run_time --report-interval=5 \
    --end-date='2019-11-01 00:00:00' \
    --threads=$threads \
    --histogram=on \
    --read_pct=$read_pct run

    date '+END: %Y-%m-%d %H:%M:%S'
    sleep $wait_time
done

echo "PREPARING FOR NON PARTITION"
echo "rename table big to _big_part, _big_nonpart to big;" | ./use -vvv test
echo "show create table big;" | ./use test
for i in $(seq 1 $test_iterations)
do
    echo "########### NON PARTITION RW ${read_pct} ${write_pct}"
    echo "THREAD: $threads"
    echo "READ%: $read_pct"
    echo "PARTITIONED: NO"
    echo "COMPRESSED: NO"
    echo "ENGINE: $engine"
    date '+START: %Y-%m-%d %H:%M:%S'

    sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=5728 --mysql-host=127.0.0.1 --mysql-db=test --time=$run_time --report-interval=5 \
    --end-date='2019-11-01 00:00:00' \
    --threads=$threads \
    --histogram=on \
    --read_pct=$read_pct run

    date '+END: %Y-%m-%d %H:%M:%S'
    sleep $wait_time
done

if [[ "$engine" == "innodb" ]]; then
    echo "PREPARING FOR PARTITION COMPRESSED"
    echo "rename table big to _big_nonpart, _big_comp to big;" | ./use -vvv test
    echo "show create table big;" | ./use test
    for i in $(seq 1 $test_iterations)
    do
        echo "########### PARTITION COMPRESSED RW ${read_pct} ${write_pct}"
        echo "THREAD: $threads"
        echo "READ%: $read_pct"
        echo "PARTITIONED: YES"
        echo "COMPRESSED: YES"
        echo "ENGINE: $engine"
        date '+START: %Y-%m-%d %H:%M:%S'

        sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=5728 --mysql-host=127.0.0.1 --mysql-db=test --time=$run_time --report-interval=5 \
        --end-date='2019-11-01 00:00:00' \
        --threads=$threads \
        --histogram=on \
        --read_pct=$read_pct run

        date '+END: %Y-%m-%d %H:%M:%S'
        sleep $wait_time
    done

    echo "PREPARING FOR NON PARTITION COMPRESSED"
    echo "rename table big to _big_comp, _big_comp_nonpart to big;" | ./use -vvv test
    echo "show create table big;" | ./use test
    for i in $(seq 1 $test_iterations)
    do
        echo "########### NON PARTITION COMPRESSED RW ${read_pct} ${write_pct}"
        echo "THREAD: $threads"
        echo "READ%: $read_pct"
        echo "PARTITIONED: NO"
        echo "COMPRESSED: YES"
        echo "ENGINE: $engine"
        date '+START: %Y-%m-%d %H:%M:%S'

        sysbench mg_part_workload.lua --mysql-ssl=off --mysql-user=msandbox --mysql-password=msandbox --mysql-port=5728 --mysql-host=127.0.0.1 --mysql-db=test --time=$run_time --report-interval=5 \
        --end-date='2019-11-01 00:00:00' \
        --threads=$threads \
        --histogram=on \
        --read_pct=$read_pct run

        date '+END: %Y-%m-%d %H:%M:%S'
        sleep $wait_time
    done
    echo "RESETTING BIG TO PARTITIONED"
    echo "rename table big to _big_comp_nonpart, _big_part to big;" | ./use -vvv test
else
    echo "RESETTING BIG TO PARTITIONED"
    echo "rename table big to _big_nonpart, _big_part to big;" | ./use -vvv test
fi
) | tee $out_file
