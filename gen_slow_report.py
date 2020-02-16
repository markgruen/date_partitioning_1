#!/usr/bin/env python3
"""Usage: gen_slow_report [--gmt --logfile=LOGFILE] <file>...

Options:
  -h --help          Show this screen.
  --gmt              Convert test run times to gmt to extract slow logs
  --logfile=LOGFILE  optional logfile
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


def get_file_parts(thefile):
    fparts = thefile.split('_')
    threads = fparts[-1]
    engine = fparts[3]
    rw = fparts[2]
    return threads, engine, rw


def split_sysbench_out0(thefile, thedate, **kwargs):
    """
    csplit -k -f sysbenchout_1_$(date '+%F_%T') test_out_1 --suffix-format='innodb__%02d' '/^###########/' '{*}'
    """

    # out_file = f'slow_{thedate}_{engine}_{part}{comp}_{rw}_{threads}_{i}'

    threads, engine, rw = get_file_parts(thefile)
    try:
        part = kwargs["part"]
        comp = kwargs["comp"]
    except KeyError as e:
        print(f'Error {e}')
        print(f'kwargs: {kwargs}')

    # csplit -k -f sysbenchout_1_$(date '+%F_%T') test_out_1 --suffix-format='innodb__%02d' '/^###########/' '{*}'
    sh.csplit("-k",
             #f"-fsysbenchout_{threads}_{thedate}",
             f"-fsysbenchout_{thedate}",
             thefile,
             f"--suffix-format=_{engine}_{part}{comp}_{rw}_{threads}_%02d",
             "/^###########/",
             "{*}")
    sh.rm("-f", f'sysbenchout_{thedate}_{engine}_{part}{comp}_{rw}_{threads}_00')


def get_sysbench_chunk(filename):
    chunk = []
    part = ''
    comp = ''
    start = True
    pbreak = re.compile(r'^########### ')
    ppartition = re.compile(r'PARTITIONED: ')
    pcompress = re.compile(r'COMPRESSED: ')
    with open(filename, 'r') as file:
        for n,line in enumerate(file):
            if pbreak.match(line):
                if start and n>0:
                    start = False
                    chunk.append(line.strip())
                else:
                    yield chunk, part, comp
                    chunk = []
                    chunk.append(line.strip())
            else:
                chunk.append(line.strip())
                if ppartition.match(line):
                    part = line.split(':')[1].strip()
                if pcompress.match(line):
                    comp = line.split(':')[1].strip()


def split_sysbench_output(filename, thedate):
    #sh.rm("-f", f'sysbenchout_{thedate}_{engine}_{part}{comp}_{rw}_{threads}_00')
    threads, engine, rw = get_file_parts(filename)
    for i, (chunk, part, comp) in enumerate(get_sysbench_chunk(filename)):
        partition = 'partition' if part == 'YES' else 'non-partition'
        compress = '_compress' if comp == 'YES' else ''
        out_file = f'sysbenchout_{thedate}_{engine}_{partition}{compress}_{rw}_{threads}_{i:02}'
        with open(out_file, 'w') as f:
            f.write('\n'.join(chunk))


def pairwise(iterable):
    "s -> (s0,s1), (s1,s2), (s2, s3), ..."
    a, b = itertools.tee(iterable)
    next(b, None)
    return zip(a, b)


def get_metadata(thefile):
    part = sh.grep("-E", "^PARTITIONED:", thefile)
    comp = sh.grep("-E", "^COMPRESSED:", thefile)
    partitioned = ['YES' in p.split(':')[1] for p in part.splitlines()]
    compressed = ['YES' in p.split(':')[1] for p in comp.splitlines()]
    return partitioned, compressed


def create_slowreport(thefile, thedate, gmt, logfile):
    out_file = '{prefix}slow_{part}_{n}'
    querydigest = sh.Command("pt-query-digest")

    #start = True
    d = [None, None]
    #n = 1

    threads, engine, rw = get_file_parts(thefile)

    print('Extracting the START and END dates from the sysbench loads to generate slow log reports')
    times = sh.grep("-E", "START:|END:", thefile)
    times = [l.split(': ')[1] for l in times.splitlines()]
    #print(times)
    for i,d in enumerate(zip(times[::2], times[1::2])):
        print(i,d)
    #sys.exit(0)
    print('')

    parts, comps= get_metadata(thefile)

    #for i,d in enumerate(pairwise(times)):
    for i,((d),(partitioned, compressed)) in enumerate(zip(zip(times[::2], times[1::2]), zip(parts, comps))):
        #print(d)
        if partitioned:
            part = 'partition'
        else:
            part = 'non-partition'
        if compressed:
            comp = '_compressed'
        else:
            comp = ''

        file_parts = {'part': part, 'comp': comp, 'threads': threads, 'engine': engine, 'rw': rw}

        #slow_2020-02-04_19-49-06_tokudb_ro_3_03
        #tokudb_ro_3_slow_non_partition_5

        out_file = f'slow_{thedate}_{engine}_{part}{comp}_{rw}_{threads}_{i}'

        if gmt:
            dd = [arrow.get(t, tzinfo=tz.tzlocal()).to('utc').format('YYYY-MM-DD HH:mm:ss') for t in d]
            print(f'Processing the slow query logs from {d[0]} to {d[1]} converting to GMT {dd[0]}:{dd[1]} saving to {out_file}')
        else:
            dd = d
            print(f'Processing the slow query logs from {dd[0]} to {dd[1]} saving to {out_file}')

        querydigest(logfile,
                        since=f"{dd[0]}", 
                        until=f"{dd[1]}",
                        limit="100%:20",
                        filter="""($event->{user} || \"\") =~ m/msandbox/""",
                        _out=out_file)

        #print(i, thefile, file_parts)
        #split_sysbench_out(thefile, thedate, **file_parts)

        

def main(filenames, thedate, gmt, logfile='/home/mgruen/sandboxes/msb_toku5_7_28/data//mysqlsandbox1-slow.log'):
    for filename in filenames:
        print(f'spliting sysbench out files for {filename}')
        #split_sysbench_output(filename, thedate)

    for filename in filenames:
        print(f'proncessing file: {filename}')
        create_slowreport(filename, thedate, gmt, logfile) 


if __name__ == '__main__':
    args = docopt(__doc__, version=_version)
    thedate = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    print(args)
    #sys.exit(0)
    main(args['<file>'], thedate, args['--gmt'], args['--logfile'])
