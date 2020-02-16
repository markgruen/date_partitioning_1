first=${1:-"innodb"}

function innodb
{
echo "----------- INNODB --------------"
./run_part_sysbench.sh 1 60 innodb
sleep 60
./run_part_sysbench.sh 3 60 innodb
sleep 60
./run_part_sysbench.sh 1 100 innodb
sleep 60
./run_part_sysbench.sh 3 100 innodb
sleep 60
}

function tokudb
{
echo "----------- TOKUDB --------------"
./run_part_sysbench.sh 1 60 tokudb
sleep 60
./run_part_sysbench.sh 3 60 tokudb
sleep 60
./run_part_sysbench.sh 1 100 tokudb
sleep 60
./run_part_sysbench.sh 3 100 tokudb
sleep 60
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
