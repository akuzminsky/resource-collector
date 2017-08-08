function gen_executive_summary(){
echo "
Executive Summary
#################

The purpose of this report is to provide insight into the current state of the database servers being maintained and monitored by Percona's Remote DBA Service.
The contents of this document will contain suggestions to improve the performance and reliability of MySQL database server
" > $report_dir/executive_summary.rst
}

