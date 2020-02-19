data_path=/home/mgruen

function check_table
{
local table_name=$1

out=$(echo "select count(*) from information_schema.tables where table_schema=database() and table_name='$table_name'" |  ./use test -s )
echo $out
if [[ "$out" == 0 ]]; then
    echo 0 > /dev/null
else
    echo 1 > /dev/null
fi
}

echo "drop table if exists big;
CREATE TABLE big (
id int(11) NOT NULL AUTO_INCREMENT,
region varchar(20) DEFAULT NULL,
add_date datetime NOT NULL,
i int(11) DEFAULT NULL,
UNIQUE KEY id (id,add_date),
UNIQUE KEY add_date (add_date,id)
) ENGINE=innodb DEFAULT CHARSET=latin1
PARTITION BY RANGE (to_days(add_date))
(PARTITION p01_2019 VALUES LESS THAN (737456) ENGINE = innodb,
PARTITION p02_2019 VALUES LESS THAN (737484) ENGINE = innodb,
PARTITION p03_2019 VALUES LESS THAN (737515) ENGINE = innodb,
PARTITION p04_2019 VALUES LESS THAN (737545) ENGINE = innodb,
PARTITION p05_2019 VALUES LESS THAN (737576) ENGINE = innodb,
PARTITION p06_2019 VALUES LESS THAN (737606) ENGINE = innodb,
PARTITION p07_2019 VALUES LESS THAN (737637) ENGINE = innodb,
PARTITION p08_2019 VALUES LESS THAN (737668) ENGINE = innodb,
PARTITION p09_2019 VALUES LESS THAN (737698) ENGINE = innodb,
PARTITION p10_2019 VALUES LESS THAN (737729) ENGINE = innodb,
PARTITION p11_2019 VALUES LESS THAN (737759) ENGINE = innodb,
PARTITION p12_2019 VALUES LESS THAN (737790) ENGINE = innodb,
PARTITION p01_2020 VALUES LESS THAN (737821) ENGINE = innodb,
PARTITION p02_2020 VALUES LESS THAN (737850) ENGINE = innodb,
PARTITION p03_2020 VALUES LESS THAN (737881) ENGINE = innodb,
PARTITION pMAX VALUES LESS THAN MAXVALUE ENGINE = innodb)
;
load data local infile 
'$data_path/partition_test_data.csv'
into table test.big
FIELDS TERMINATED BY ',' ENCLOSED BY '\"'
LINES TERMINATED BY '\r\n'
(region, add_date)
;
analyze table big
;
drop table if exists _big_nonpart;
create table _big_nonpart like big
;
alter table _big_nonpart remove partitioning;
insert into _big_nonpart select * from big;
analyze table _big_nonpart
;
drop table if exists _big_comp;
create table _big_comp like big;
alter table _big_comp key_block_size=4 row_format=compressed;
insert into _big_comp select * from big;
analyze table _big_comp
;
drop table if exists _big_comp_nonpart;
create table _big_comp_nonpart like _big_comp;
alter table _big_comp_nonpart remove partitioning;
insert into _big_comp_nonpart select * from big;
analyze table _big_comp_nonpart;
" | ./use -vvv test
