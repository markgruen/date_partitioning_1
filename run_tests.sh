now=$(date +"%Y%m%d_%H:%M:%S")
first=${1:-"innodb"}
#outfile=${2:-""}
sleep_time=${2:-60}

outfile="testout_$now"

function innodb
{
echo "----------- INNODB --------------"
./run_part_sysbench.sh 1 60 innodb "$outfile"
sleep "$sleep_time"
./run_part_sysbench.sh 3 60 innodb "$outfile"
sleep "$sleep_time"
./run_part_sysbench.sh 1 100 innodb "$outfile"
sleep "$sleep_time"
./run_part_sysbench.sh 3 100 innodb "$outfile"
sleep "$sleep_time"
}

function tokudb
{
echo "----------- TOKUDB --------------"
./run_part_sysbench.sh 1 60 tokudb "$outfile"
sleep "$sleep_time"
./run_part_sysbench.sh 3 60 tokudb "$outfile"
sleep "$sleep_time"
./run_part_sysbench.sh 1 100 tokudb "$outfile"
sleep "$sleep_time"
./run_part_sysbench.sh 3 100 tokudb "$outfile"
sleep "$sleep_time"
}

if [[ "$first" == "innodb" ]]; then
    innodb
    ./big_change_engine.sh tokudb
    tokudb
else
    tokudb
    ./big_change_engine.sh innodb
    innodb
fi
