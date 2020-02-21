#!/usr/bin/env python3
"""Usage: gen_slow_report [--gmt --slowlogfile=LOGFILE] <file>...

Options:
  -h --help          Show this screen.
  --gmt              Convert test run times to gmt to extract slow logs
  --slowlogfile=LOGFILE  slow logfile [default: ./data/mysqlsandbox1-slow.log]
"""
import sh
import itertools
import sys
import re
from docopt import docopt
from datetime import datetime
import arrow
from dateutil import tz

_version = '0.1'


def get_sysbench_chunk(filename):
    chunk = []
    part, comp, threads, engine, rw, starttime, endtime = '', '', '', '', '', '', ''
    start = True
    pbreak = re.compile(r'^########### ')
    ppartition = re.compile(r'PARTITIONED: ')
    pcompress = re.compile(r'COMPRESSED: ')
    pengine = re.compile(r'ENGINE: ')
    pthreads = re.compile(r'THREAD: ')
    pstart = re.compile(r'START: ')
    pend = re.compile(r'END: ')
    prw = re.compile(r'READ/WRITE: ')
    with open(filename, 'r') as file:
        for n,line in enumerate(file):
            if pbreak.match(line):
                if start and n>0:
                    start = False
                    chunk.append(line.strip())
                else:
                    yield chunk, part, comp, threads, engine, rw, starttime, endtime
                    chunk = []
                    chunk.append(line.strip())
            else:
                chunk.append(line.strip())
                if ppartition.match(line):
                    part = line.split(':')[1].strip()
                    part = 'partition' if part == 'YES' else 'non-partition'
                if pcompress.match(line):
                    comp = line.split(':')[1].strip()
                    comp = 'compress' if comp == 'YES' else ''
                if pthreads.match(line):
                    threads = line.split(':')[1].strip()
                if pengine.match(line):
                    engine = line.split(':')[1].strip()
                if pstart.match(line):
                    starttime = ':'.join(line.split(':')[-3:]).strip()
                if pend.match(line):
                    endtime = ':'.join(line.split(':')[-3:]).strip()
                if prw.match(line):
                    rw = line.split(':')[1].strip()
                    rw = 'ro' if rw=='100' else 'rw'
        else:
            yield chunk, part, comp, threads, engine, rw, starttime, endtime



def split_sysbench_output(filename, thedate):
    for i, (chunk, partition, compress, threads, engine, rw, starttime, endtime) in enumerate(get_sysbench_chunk(filename)):
        #partition = 'partition' if part == 'YES' else 'non-partition'
        #compress = '_compress' if comp == 'compress' else ''
        compress = '_compress' if compress == 'compress' else ''
        out_file = f'sysbenchout_{thedate}_{engine}_{partition}{compress}_{rw}_{threads}_{i:02}'
        with open(out_file, 'w') as f:
            f.write('\n'.join(chunk))
        print(i,chunk[0], out_file)


def list_times(filename, gmt):
    """ here we can generate the url links to PPM """
    for i, (chunk, partition, compress, threads, engine, rw, starttime, endtime) in enumerate(get_sysbench_chunk(filename)):
        if gmt:
            start_gmt = arrow.get(starttime, tzinfo=tz.tzlocal()).to('utc').format('YYYY-MM-DD HH:mm:ss')
            end_gmt = arrow.get(endtime, tzinfo=tz.tzlocal()).to('utc').format('YYYY-MM-DD HH:mm:ss')
            print(f'{starttime} {endtime} ->  {start_gmt} {end_gmt}')
        else:
            print(f'{starttime} {endtime}')


def create_slowreport(filename, thedate, gmt, logfile):
    querydigest = sh.Command("pt-query-digest")

    d = [None, None]

    for i, (chunk, partition, compress, threads, engine, rw, starttime, endtime) in enumerate(get_sysbench_chunk(filename)):

        #slow_2020-02-04_19-49-06_tokudb_ro_3_03
        #tokudb_ro_3_slow_non_partition_5

        compress = '_compress' if compress=='compress' else ''
        out_file = f'slow_{thedate}_{engine}_{partition}{compress}_{rw}_{threads}_{i}'

        if gmt:
            d = [starttime, endtime]
            dd = [arrow.get(t, tzinfo=tz.tzlocal()).to('utc').format('YYYY-MM-DD HH:mm:ss') for t in [starttime, endtime]]
            print(f'Processing the slow query logs from {d[0]} to {d[1]} converting to GMT {dd[0]}:{dd[1]} saving to {out_file}')
        else:
            dd = [starttime, endtime]
            print(f'Processing the slow query logs from {dd[0]} to {dd[1]} saving to {out_file}')

        querydigest(logfile,
                        since=f"{dd[0]}", 
                        until=f"{dd[1]}",
                        limit="100%:20",
                        filter="""($event->{user} || \"\") =~ m/msandbox/""",
                        _out=out_file)


def main(filenames, thedate, gmt, logfile):
    for filename in filenames:
        print(f'Listing times if benchamrk runs in file {filename}')
        list_times(filename, gmt)

    for filename in filenames:
        print(f'spliting sysbench out files for {filename}')
        split_sysbench_output(filename, thedate)

    for filename in filenames:
        print(f'proncessing file: {filename} using slowlog path {logfile}')
        create_slowreport(filename, thedate, gmt, logfile)


if __name__ == '__main__':
    args = docopt(__doc__, version=_version)
    thedate = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    print(args)
    #sys.exit(0)
    main(args['<file>'], thedate, args['--gmt'], args['--slowlogfile'])
