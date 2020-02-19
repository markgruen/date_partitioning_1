#!/usr/bin/env python3
"""
Usage:
  extract_oltp [--csv] <file_name>...


extracts the datapoints from oltp sysbench tests
"""

from docopt import docopt
import re
import sys


def get_next_dataline(file):
    start = False
    for line in file:
        if not start and not re.match(r'^SQL statistics:', line):
            continue
        else:
            start = True
        yield line
           

def main(file_names):

    for file in file_names:
        extract(file)
        print('')


def extract(file_names, csv):
    sysbench_version = '1.0'
    debug = False

    exp_v05 = re.compile( '^Number of threads: (\d\d*)|'
                          'read: *(\d\d*)|'
                          'write: *(\d\d*)|'
                          'other: *(\d\d*)|'
                          'total: *(\d\d*)|'
                          'transactions: *(\d\d*) *\((\d\d*\.\d\d) per sec\.|'
                          'read\/write requests: *(\d\d*) *\((\d\d*\.\d\d) per sec\.|'
                          'other operations: *(\d\d*) *\((\d\d*\.\d\d) per sec\.|'
                          'ignored errors: *(\d\d*) *\((\d\d*\.\d\d) per sec\.|'
                          'reconnects: *(\d\d*) *\((\d\d*\.\d\d) per sec\.|'
                          'total time: *(\d\d*.\d\d*)s|'
                          'total number of events: *(\d\d*)|'
                          'total time taken by event execution: *(\d\d*.\d\d*)s|'
                          'min: *(\d\d*\.\d\d*)ms|'
                          'avg: *(\d\d*\.\d\d*)ms|'
                          'max: *(\d\d*\.\d\d*)ms|'
                          'approx\.  95 percentile: *([0-9][0-9]*\.\d\d*)ms$')

    exp_v10 = re.compile( '^Number of threads: (\d\d*)|'
                          '.*read: *(\d\d*)|'
                          '.*write: *(\d\d*)|'
                          '.*other: *(\d\d*)|'
                          '.*total: *(\d\d*)|'
                          '.*transactions: *(\d\d*) *\((\d\d*\.\d\d) per sec\.|'
                          '.*queries: *(\d\d*) *\((\d\d*\.\d\d) per sec\.|'
                          '.*read\/write requests: *(\d\d*) *\((\d\d*\.\d\d) per sec\.|'
                          '.*other operations: *(\d\d*) *\((\d\d*\.\d\d) per sec\.|'
                          '.*ignored errors: *(\d\d*) *\((\d\d*\.\d\d) per sec\.|'
                          '.*reconnects: *(\d\d*) *\((\d\d*\.\d\d) per sec\.|'
                          '.*total time: *\d\d*.\d\d*s|'
                          '.*total number of events: *\d\d*|'
                          '.*sum: *(\d\d*.\d\d*)s|'
                          '.*min: *(\d\d*\.\d\d*)|'
                          '.*avg: *(\d\d*\.\d\d*)|'
                          '.*max: *(\d\d*\.\d\d*)|'
                          '.*95th percentile: *([0-9][0-9]*\.\d\d*)$')
    if sysbench_version == '1.0':
        exp = exp_v10

    header1 = ('Queries', 'Transactions', 'General Statisics', 'Response Time')
    header = ('Threads',
              'reads', 'writes', 'other', 'total',
              'trans', 'trans/sec',
              'r/w_reqs', 'rw/s',
              'other_ops', 'other_ops/s',
              'ignored_errs', 'ignored_errs/s',
              'reconnects', 'reconnects/s',
              'tot_time', '#events', 'tot_time_for_events', 'min', 'avg', 'max', '95_%', 'filename')
    #print('File: {}'.format(file_name))
    print('')
    if not csv:
        print('{:40s} {:108s} {:36s} {}'.format(*header1))
        print('{:7s} '
              '{:9s} {:6s} {:7s} {:7s} '
              '{:6s} {:9s} ' #trans
              '{:8s} {:8s} ' #r/w
              '{:9s} {:11s} ' #other
              '{:12s} {:14} ' #ignored errors
              '{:10s} {:12s} ' #reconnects
              '{:8s} {:7s} {:19s} {:7s} {:7s} {:7s} {:7s} {}'.format(*header))
    else:
        print('{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}'.format(*header))
    #values = [None]*22
    values = [None]*23
    for file_name in file_names:
        values[22] = file_name
        with open(file_name, 'r') as f:
            for l, line in enumerate(f):
            #for l, line in enumerate(get_next_dataline(f)):
                #print(l,line)
                try:
                    #m = re.search('[1-9][0-9\.]*Mb\/sec', line)
                    """
                    if l in [23,24]:
                        print('SKIP')
                        pass"""
                    #m = exp.search(line, re.M).groups()
                    m = exp.match(line).groups()
                    #print(m)
                    nm = sum(map(len, [e for e in m if e is not None]))
                    i_m = [n for n,e in enumerate(m) if e is not None]
                    if nm > 0:
                        #print "MATCH:"
                        #print line
                        i = list(map(bool, m)).index(True)
                        if i == 0:
                            #print(line)
                            values = [None]*23
                            values[0] = m[0]
                            values[22] = file_name
                        else:
                            #values[i] = m[i]
                            for j in i_m:
                                values[j] = m[j]

                        #print(line)
                        #print('values: {}'.format(values))
                        #print('m:      {}'.format(m))
                        #if len([e for e in values if e is not None]) == 22:
                        #print(f'LEN: {len([e for e in values if e is not None])}')
                        if len([e for e in values if e is not None]) == 18:
                            #print(f'LEN VALUES {len(values)}')
                            if not csv:
                                print('{:7s} '
                                      '{:9s} {:6s} {:7s} {:7s} '
                                      '{:6s} {:9s} ' #trans
                                      '{:8s} {:8s} ' #r/w
                                      '{:9s} {:11s} ' #other
                                      '{:12s} {:14} ' #ignored errors
                                      '{:10s} {:12s} ' #reconnects
                                      '{:8s} {:7s} {:19s} {:7s} {:7s} {:7s} {:7s} {}'.format(*['' if e is None else e for e in values]))
                            else:
                                print('{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}'.format(*['' if e is None else e for e in values]))
                        else:
                            if debug:
                                print('{:7s} '
                                      '{:9s} {:6s} {:7s} {:7s} '
                                      '{:6s} {:9s} ' #trans
                                      '{:8s} {:8s} ' #r/w
                                      '{:9s} {:11s} ' #other
                                      '{:12s} {:14} ' #ignored errors
                                      '{:10s} {:12s} ' #reconnects
                                      '{:8s} {:7s} {:19s} {:7s} {:7s} {:7s} {:7s} {N}'.format(N=l,*values))
                        #for s in m:
                        #    print('STRING: {}'.format(s))
                except (TypeError, AttributeError) as e:
                    next
        if debug: print('DEBUG: {}'.format(values))

if __name__ == '__main__':
    args = docopt(__doc__)
    print(args)
    #sys.exit()
    #main(args["<file_name>"], args['--csv'])
    extract(args["<file_name>"], args['--csv'])


