# date_partitioning_1
using sysbench to benchmark date partitioned tables

sysbench doesn't provide an out of the box benchmarking script for date partitioned tables. 
This project provides a configurable benchmarking script for date partitioning.

$ sysbench mg_part_workload.lua help
sysbench 1.0.18 (using bundled LuaJIT 2.1.0-beta2)

mg_part_workload.lua options:
  --end_date=STRING   end of random date range [2020-01-01 00:00:00]
  --read_pct=N        percentage of read events [60]
  --select_range=N    number of days in select range [14]
  --skip_trx[=on|off] Do not use BEGIN/COMMIT; Use global auto_commit value [off]
  --start_date=STRING start of random date range [2019-01-01 00:00:00]
