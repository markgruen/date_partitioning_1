_PATH=/home/mgruen/sandboxes/msb_toku5_7_28

rm $_PATH/data//mysqlsandbox1-slow.log


$_PATH/use -e 'select @@global.long_query_time into @lqt_save; set global long_query_time=2000; select sleep(2); FLUSH LOGS; select sleep(2); set global long_query_time=@lqt_save;'

ls -l $_PATH/data//mysqlsandbox1-slow.log
