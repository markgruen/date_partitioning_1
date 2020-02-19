# must run as root
# sudo transparent_pages.sh 
# use to setup sandbox instance to use tokudb

echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
