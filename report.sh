set -uex

customer_name="GCI Communication"
author_name="$(finger `whoami` | head -1| awk -F: '{ print $3}')"
tmpdir=`mktemp -d`

source /usr/share/rdba-audit/sub_routines.sh

report_dir=report-`date +%F`
data_dir=data

while getopts "d:r:?" opt; do
  case $opt in
    d) data_dir=$OPTARG;;
    r) report_dir=$OPTARG;;
    ?) usage; exit;;
  esac
done

pics_dir=$report_dir/pics
mkdir -p "$pics_dir"
mkdir -p $report_dir/appendixes
measurement_start=`cat $data_dir/measurement_start`    #   date when the measurement was started in seconds.
interval=`cat $data_dir/interval`  

echo ".. include:: title_page.rst
.. include:: executive_summary.rst
.. include:: queries_audit.rst
.. include:: hardware_configuration.rst
.. include:: software_audit.rst
.. include:: resource_utilization_audit.rst
.. include:: error_log.rst
.. include:: mysql_data_distribution.rst
.. include:: duplicate_indexes.rst
.. include:: appendixes.rst


.. |ok| image:: pics/ok.png
.. |warning| image:: pics/warning.png
.. |error| image:: pics/error.png

" > $report_dir/index.rst

test -f $pics_dir/percona.jpg ||  wget -q -O $pics_dir/percona.jpg https://www.dropbox.com/s/v01cceijmjdp0bm/percona.jpg
test -f $pics_dir/percona_logo.png || wget -q -O $pics_dir/percona_logo.png https://www.dropbox.com/s/822tt0psa8bpogr/percona_logo.png
test -f $pics_dir/error.png || wget -q -O $pics_dir/error.png https://www.dropbox.com/sh/wlnxinou4qp93ji/CuCNTlzg0a/error.png
test -f $pics_dir/ok.png || wget -q -O $pics_dir/ok.png https://www.dropbox.com/sh/wlnxinou4qp93ji/c3Zfgk0hof/ok.png
test -f $pics_dir/warning.png || wget -q -O $pics_dir/warning.png https://www.dropbox.com/sh/wlnxinou4qp93ji/OnNzRvAyn1/warning.png

gen_title 
gen_executive_summary 
gen_queries_audit 
gen_hardware_configuration 
gen_software_audit 
gen_resource_utilization_audit 
gen_error_log 
gen_mysql_data_distribution 
gen_duplicate_indexes 
gen_appendixes

rm -rf "$tmpdir"
