if [ "$#" -ne 1 ]; then
    echo "usages $0 ENGINE"
    exit 1
fi
engine=$1

echo "altering table to use $engine engine"

echo "alter table big engine=${engine};
alter table _big_nonpart engine=${engine};
analyze table big;
analyze table _big_nonpart;
analyze table _big_comp;
analyze table _big_comp_nonpart;" | ./use -vvv test
