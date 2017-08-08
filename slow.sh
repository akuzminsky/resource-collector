set -eu
issue=`date +%F`-`hostname`
mailto=aleksandr.kuzminsky@gmail.com
log_size_mb=1024 # Maximum log size in megabytes
max_run_time=1  # Maximum running time in hours
# No changes below this line
old_slow_query_log=`mysql -NBe "select @@slow_query_log"`
old_slow_query_log_file=`mysql -NBe "select @@slow_query_log_file"`
old_long_query_time=`mysql -NBe "select @@long_query_time"`
old_slow_query_log_use_global_control_exists="FALSE"
old_use_global_log_slow_control_exists="FALSE"
old_use_global_long_query_time_exists="FALSE"
if ! test -z "`mysql -NBe "select @@slow_query_log_use_global_control" 2>/dev/null`"
then
    old_slow_query_log_use_global_control_exists='TRUE'
    old_slow_query_log_use_global_control=`mysql -NBe "select @@slow_query_log_use_global_control"`
fi
if ! test -z "`mysql -NBe "select @@use_global_log_slow_control" 2>/dev/null`"
then
    old_use_global_log_slow_control_exists='TRUE'
    old_use_global_log_slow_control=`mysql -NBe "select @@use_global_log_slow_control"`
fi
if ! test -z "`mysql -NBe "select @@use_global_long_query_time'" 2>/dev/null`"
then
    old_use_global_long_query_time_exists='TRUE'
    old_use_global_long_query_time=`mysql -NBe "select @@use_global_long_query_time"`
fi
datadir=`mysql -NBe "select @@datadir"`
slow_log="$datadir/slow-query-issue-$issue.log"
function clean()
{
mysql -NBe "SET GLOBAL slow_query_log_file='$old_slow_query_log_file'"
mysql -NBe "SET GLOBAL long_query_time=$old_long_query_time"
mysql -NBe "SET GLOBAL slow_query_log=$old_slow_query_log"
if [ "$old_slow_query_log_use_global_control_exists" = "TRUE" ]
then
    mysql -NBe "SET GLOBAL slow_query_log_use_global_control='$old_slow_query_log_use_global_control'"
fi
if [ "$old_use_global_log_slow_control_exists" = "TRUE" ]
then
    mysql -NBe "SET GLOBAL use_global_log_slow_control='$old_use_global_log_slow_control'"
fi
if [ "$old_use_global_long_query_time_exists" = "TRUE" ]
then
    mysql -NBe "SET GLOBAL use_global_long_query_time=$old_use_global_long_query_time"
fi
}
function mail_status()
{
	status=$1
	echo "Check slow log '$slow_log' at host `hostname` " | mail -s "`hostname` slow log status: $status" $mailto
}
trap "clean; mail_status CTRL+C" INT
trap "clean; mail_status ERROR" ERR
trap "clean; mail_status OK" EXIT
let max_log_size=$log_size_mb*1024*1024 # 1G
mysql -NBe "SET GLOBAL slow_query_log_file='$slow_log'"
mysql -NBe "SET GLOBAL long_query_time=0"
mysql -NBe "SET GLOBAL slow_query_log=ON"
if [ "$old_slow_query_log_use_global_control_exists" = "TRUE" ]
then
    mysql -NBe "SET GLOBAL slow_query_log_use_global_control=all"
fi
if [ "$old_use_global_log_slow_control_exists" = "TRUE" ]
then
    mysql -NBe "SET GLOBAL use_global_log_slow_control=all"
fi
if [ "$old_use_global_long_query_time_exists" = "TRUE" ]
then
    mysql -NBe "SET GLOBAL use_global_long_query_time=1"
fi
t1=`date +%s`
let max_run_time_sec=$max_run_time*3600
while true
do
	sleep 10
	if ! test -f "$slow_log" ; then break; fi
	#if size  is bigger than $max_log_size - stop
	slow_log_size=`du -b "$slow_log" | awk '{ print $1}'`
	if [ "$slow_log_size" -gt "$max_log_size" ]; then break ; fi
	#if the slow log is being collected longer than a day - stop
	t2=`date +%s`
	let run_time=$t2-$t1
	if [ "$run_time" -gt $max_run_time_sec ]; then break ; fi
done
