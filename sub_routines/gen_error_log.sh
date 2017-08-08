function gen_error_log(){
echo "
Error Log Analysis
##################

Content of MySQL error log since start::

`print_error_log`

|ok| |warning| |error| Here's consultant's comments


" > $report_dir/error_log.rst
}


function print_error_log () {

if test -f "$data_dir/error_log"
then
	csplit --prefix=error_log --digits=8 $data_dir/error_log "/mysqld: ready for connections/" {*} > /dev/null 2>&1
	l=`ls error_log0*| sort| tail -1`

	test -f "$l" && fold -s "$l" | sed 's/\(.\)/      \1/'

	rm -f error_log0*
else
	echo " Error log wasn't copied"
fi

}
