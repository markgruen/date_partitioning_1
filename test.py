"""Usage: test <file>
"""
import sh
from docopt import docopt

_version = '0.1'

def main(_file):
    #sh.ifconfig(_out="/tmp/interfaces")
    out = sh.grep("START:", _file)
    print(out)
    # out.splitlines()


if __name__ == '__main__':
   args = docopt(__doc__, version=_version)
   print(args)
   main(args['<file>'])
