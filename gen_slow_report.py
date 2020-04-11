#!/usr/bin/env python3
"""Usage:
    gen_slow_report [--gmt --slowlogfile=LOGFILE --gen-url=BASEURL --list-times] <benchmark_outfiles>...

Arguments:
    benchmark_outfile  list of output files from run_tests.sh

Options:
  -h --help              Show this screen.
  --gmt                  Convert test run times to gmt to extract slow logs using pt-query-digest
  --slowlogfile=LOGFILE  slow logfile [default: ./data/mysqlsandbox1-slow.log]
  --gen-urls=BASEURL     Create URLS for timespans of testing to compare in PMM
  --list-times           List times and exit

Example:
    gen_slow_report --gmt --list-times testout_20200223_09:27:45
    gen_slow_report --gmt --gen-url=192.168.101.42 --list-times testout_20200223_09:27:45

"""
from typing import List, Any, Tuple, Union

import sh
import re
import pandas as pd
import numpy as np
from docopt import docopt
from datetime import datetime
from tzlocal import get_localzone
import arrow
from dateutil import tz
from tabulate import tabulate

_version = '0.2'


def get_sysbench_chunk(filename):
    chunk = []
    part, comp, threads, engine, rw, starttime, endtime = '', '', '', '', '', '', ''
    start = True
    pbreak = re.compile(r'^########### ')
    ppartition = re.compile(r'^PARTITIONED: ')
    pcompress = re.compile(r'^COMPRESSED: ')
    pengine = re.compile(r'^ENGINE: ')
    ppointselect = re.compile(r'^POINT_SELECT_PCT: ')
    pthreads = re.compile(r'^THREAD: ')
    pstart = re.compile(r'^START: ')
    pend = re.compile(r'^END: ')
    prw = re.compile(r'^READ/WRITE: ')
    with open(filename, 'r') as file:
        for n,line in enumerate(file):
            if pbreak.match(line):
                if start and n>0:
                    start = False
                    chunk.append(line.strip())
                else:
                    yield chunk, part, comp, pselect, threads, engine, rw, starttime, endtime
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
                if ppointselect.match(line):
                    pselect = line.split(':')[1].strip()
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
            yield chunk, part, comp, pselect, threads, engine, rw, starttime, endtime


def split_sysbench_output(filename, thedate):
    for i, (chunk, partition, compress, pselect, threads, engine, rw, starttime, endtime) in enumerate(get_sysbench_chunk(filename)):
        #partition = 'partition' if part == 'YES' else 'non-partition'
        #compress = '_compress' if comp == 'compress' else ''
        compress = '_compress' if compress == 'compress' else ''
        out_file = f'sysbenchout_{thedate}_{engine}_{partition}{compress}_{rw}_{threads}_{i:02}'
        with open(out_file, 'w') as f:
            f.write('\n'.join(chunk))
        print(i,chunk[0], out_file)


def build_timewindow(outlist, base_url):
    columns = ['start', 'end', 'engine', 'partition', 'compress', 'pselect%', 'threads', 'rw']
    dfout = pd.DataFrame(outlist, columns=columns)
    #print(columns)
    #print(outlist)
    dfout['starttime'] = dfout['start'].apply(arrow.Arrow.fromtimestamp)
    dfout['endtime'] = dfout['end'].apply(arrow.Arrow.fromtimestamp)
    dfout.astype({'start': np.int32, 'end': np.int32})
    sec = 1000

    top = dfout.groupby(['engine', 'threads', 'partition', 'compress', 'rw']).head(1).reset_index()
    bottom = dfout.groupby(['engine', 'threads', 'partition', 'compress', 'rw']).tail(1).reset_index()

    print('Run times of tests:')
    window = pd.merge(top, bottom, how='inner', on=['engine', 'partition', 'compress', 'threads', 'rw']) \
        [['starttime_x', 'endtime_y', 'start_x','end_y','threads', 'engine', 'compress', 'partition', 'rw']]

    print('\n\n')
    print('Links to PMM for each test')
    "http://192.168.101.42/graph/d/7Xk9QMNmk/mysql-tokudb-metrics?"
    for i, d in window.iterrows():
        print(f"{d['engine']} {d['threads']} {d['partition']} {d['compress']} {d['rw']}")
        if base_url:
            if d['engine'] == 'innodb':
                print(f"    http://{base_url}/graph/d/MQWgroiiz/mysql-overview?from="
                      f"{int(d['start_x']) * 1000 - sec}&to={int(d['end_y']) * 1000 + 60 * sec}\n")
            elif d['engine'] == 'tokudb':
                print(f"    http://{base_url}/graph/d/MQWgroiiz/mysql-overview?from="
                      f"{int(d['start_x']) * 1000 - sec}&to={int(d['end_y']) * 1000 + 60 * sec}\n")
                print(f"    http://{base_url}/graph/d/MQWgroiiz/mysql-tokudb-metrics?from="
                      f"{int(d['start_x'])*1000-sec}&to={int(d['end_y'])*1000+15*sec}")
            else:
                print(f"    http://{base_url}/graph/d/MQWgroiiz/mysql-overview?from="
                      f"{int(d['start_x']) * 1000 - sec}&to={int(d['end_y']) * 1000 + 60 * sec}\n")

    print('\n\n')
    print('Links to PMM by engine and threads:')

    top = dfout.groupby(['engine', 'threads']).head(1).reset_index()
    bottom = dfout.groupby(['engine', 'threads']).tail(1).reset_index()
    window = pd.merge(top, bottom, how='inner', on=['engine', 'threads']) \
        [['starttime_x', 'endtime_y', 'start_x', 'end_y', 'engine']]
    group_details = dfout.groupby(['engine', 'threads'], sort=False)

    for (i, d), (name, group) in zip(window.iterrows(), group_details):
        print(f"{d['engine']}")
        if base_url:
            print(f"    http://{base_url}/graph/d/MQWgroiiz/mysql-overview?from="
                  f"{int(d['start_x']) * 1000 - sec}&to={int(d['end_y']) * 1000 + 60 * sec}\n")
        gcolumns = [c for c in group.columns.tolist() if c not in ['start', 'end', 'starttime', 'endtime']]
        g = group.groupby(gcolumns, sort=False, as_index=False).count()

        header = g.columns.str.upper()
        print(tabulate(g, headers=header, tablefmt='psql'))
        print('')




    print('\n\n')
    print('Links to PMM by engine, threads and rw:')

    top = dfout.groupby(['engine', 'threads','rw']).head(1).reset_index()
    bottom = dfout.groupby(['engine', 'threads','rw']).tail(1).reset_index()
    window = pd.merge(top, bottom, how='inner', on=['engine', 'threads','rw']) \
        [['starttime_x', 'endtime_y', 'start_x', 'end_y', 'engine']]
    group_details = dfout.groupby(['engine', 'threads','rw'], sort=False)

    for (i, d), (name, group) in zip(window.iterrows(), group_details):
        print(f"{d['engine']} {name[1]} threads {name[2]}")
        if base_url:
            print(f"    http://{base_url}/graph/d/MQWgroiiz/mysql-overview?from="
                  f"{int(d['start_x']) * 1000 - sec}&to={int(d['end_y']) * 1000 + 60 * sec}\n")
        gcolumns = [c for c in group.columns.tolist() if c not in ['start', 'end', 'starttime', 'endtime']]
        g = group.groupby(gcolumns, sort=False, as_index=False).count()

        header = g.columns.str.upper()
        print(tabulate(g, headers=header, tablefmt='psql'))
        print('')




    print('\n\n')
    print('Links to PMM by engine showing all test in a single plot:')

    top = dfout.groupby(['engine']).head(1).reset_index()
    bottom = dfout.groupby(['engine']).tail(1).reset_index()
    window = pd.merge(top, bottom, how='inner', on=['engine']) \
        [['starttime_x', 'endtime_y', 'start_x', 'end_y', 'engine']]
    group_details = dfout.groupby(['engine'], sort=False)

    for (i, d), (name, group) in zip(window.iterrows(), group_details):
        print(f"{d['engine']}")
        if base_url:
            print(f"    http://{base_url}/graph/d/MQWgroiiz/mysql-overview?from="
                  f"{int(d['start_x']) * 1000 - sec}&to={int(d['end_y']) * 1000 + 60 * sec}\n")
        gcolumns = [c for c in group.columns.tolist() if c not in ['start', 'end', 'starttime', 'endtime']]
        g = group.groupby(gcolumns, sort=False, as_index=False).count()

        header = g.columns.str.upper()
        print(tabulate(g, headers=header, tablefmt='psql'))
        print('')
    return window


def list_times(filename, gmt, base_url=None):
    """ here we can generate the url links to PMM """
    if isinstance(filename, list):
        for fn in filename:
            outlist = get_times(fn, gmt)
    else:
        outlist = get_times(filename, gmt)
    if base_url:
        build_timewindow(outlist, base_url)


def get_times(filename, gmt):
    out_list: List[Tuple[str, str, Union[str, Any], str, str, Union[str, Any], str]] = []
    out = []
    if gmt:
        header = ('Engine','Partition','Compression','PSelect%', 'Threads','R/W','Start','End','Start UCT','End UCT')
    else:
        header = ('Engine','Partition','Compression','PSelect%', 'Threads','R/W','Start','End')

    for i, (chunk, partition, compress, pselect, threads, engine, rw, starttime, endtime) in enumerate(get_sysbench_chunk(filename)):
        if gmt:
            start_gmt = arrow.get(starttime, tzinfo=tz.tzlocal()).to('utc').format('YYYY-MM-DD HH:mm:ss')
            end_gmt = arrow.get(endtime, tzinfo=tz.tzlocal()).to('utc').format('YYYY-MM-DD HH:mm:ss')
            out.append((engine, partition, compress, pselect, threads, rw, starttime, endtime, start_gmt, end_gmt))
        else:
            out.append((engine, partition, compress, threads, rw, starttime, endtime))
            print(f'{starttime} {endtime} {engine} {pselect} {partition} {compress} {threads} {rw}')

        out_list.append((arrow.get(starttime, tzinfo=get_localzone()).format('X'),
                         arrow.get(endtime, tzinfo=get_localzone()).format('X'),
                         engine, partition, compress, pselect, threads, rw) )
    print('Listing the benchmark tests and run times:\n')
    print(tabulate(out, header, tablefmt='simple'))
    return out_list


def create_slowreport(filename, thedate, gmt, logfile):
    querydigest = sh.Command("pt-query-digest")

    d = [None, None]

    for i, (chunk, partition, compress, pselect, threads, engine, rw, starttime, endtime) in enumerate(get_sysbench_chunk(filename)):

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


def run_date(filenames):
    matched = []
    try:
        for filename in filenames:
            m = re.match(r'.*(\d\d\d\d\d\d\d\d.\d\d.\d\d.\d\d)', filename)
            matched.append(m.group(1))
    except AttributeError:
        return arrow.now().format('YYYYMMDD_HH-mm-ss')

    if len(set(matched)) == 1:
        return arrow.get(matched[0], 'YYYYMMDD_HH:mm:ss').format('YYYYMMDD_HH-mm-ss')
    else:
        return arrow.now().format('YYYYMMDD_HH-mm-ss')


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
    """add function to check all files for a date and use that or use the current date"""
    args = docopt(__doc__, version=_version)
    print(args)
    thedate = run_date(args['<benchmark_outfiles>'])
    #sys.exit(0)
    if args['--list-times']:
        list_times(args['<benchmark_outfiles>'], args['--gmt'], args['--gen-url'])
    else:
        main(args['<benchmark_outfiles>'], thedate, args['--gmt'], args['--slowlogfile'])
