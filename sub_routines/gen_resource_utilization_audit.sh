
function gen_resource_utilization_audit(){
echo "
Resources Utilization Audit
###########################

CPU Usage
=========

`print_cpu_graphs`

|ok| |warning| |error| Here's consultant's comments


Memory Usage
============

`print_memory_graphs`

|ok| |warning| |error| Here's consultant's comments


Disk Usage
==========

`print_disk_graphs`

|ok| |warning| |error| Here's consultant's comments


Network Usage
=============

MySQL Usage
===========

Commands
********

`print_mysql_command_counters_graphs`


|ok| |warning| |error| Here's consultant's comments

API Handlers
************

`print_mysql_api_handlers_graphs`


|ok| |warning| |error| Here's consultant's comments

Caches
******

Threads Cache
-------------

`print_mysql_thread_cache_graphs`


|ok| |warning| |error| Here's consultant's comments

Table Cache
-----------

`print_mysql_table_cache_graphs`


|ok| |warning| |error| Here's consultant's comments

Query Cache
-----------

`print_mysql_query_cache_graphs`

|ok| |warning| |error| Here's consultant's comments


InnoDB
******

Innodb_log_waits
----------------

`print_mysql_Innodb_log_waits_graphs`


|ok| |warning| |error| Here's consultant's comments

Innodb_os_log_written
---------------------

`print_mysql_Innodb_os_log_written_graphs`

|ok| |warning| |error| Here's consultant's comments


Replication
***********

Binary Logging
--------------

`print_mysql_binary_logging_graphs`


|ok| |warning| |error| Here's consultant's comments

Replication Delay
-----------------


|ok| |warning| |error| Here's consultant's comments

Temporary Tables
****************

`print_mysql_tmp_tables_graphs`


|ok| |warning| |error| Here's consultant's comments

Select Types
************

`print_mysql_select_types_graphs`


|ok| |warning| |error| Here's consultant's comments

Sorting
*******

`print_mysql_sorting_graphs`


|ok| |warning| |error| Here's consultant's comments

Table Locks
***********

`print_mysql_table_locks_graphs`

|ok| |warning| |error| Here's consultant's comments


" > $report_dir/resource_utilization_audit.rst

rm -f mysqladmin.*.dat
}


function get_lines()
{
commands="$1"
allow_zero="$2"
comma=""
for command in $commands
do
	# generate data file
	grep -w "$command" "$data_dir/mysqladmin.out" | awk "
	BEGIN { t=$measurement_start; }
	{
		        print strftime(\"%F %T\", t), \$2, \$4;
			        t+=$interval;
			}
			" > "$tmpdir/mysqladmin.$command.dat.tmp"
	n=`wc -l "$tmpdir/mysqladmin.$command.dat.tmp" | awk '{ print $1}'`
	let n=$n-1
	tail -$n "$tmpdir/mysqladmin.$command.dat.tmp" > "$tmpdir/mysqladmin.$command.dat"
	rm "$tmpdir/mysqladmin.$command.dat.tmp"
	case "$command" in
		"Threads_running" | "Something else")
			divider=1
			;;
		*)
			divider=$interval
			;;
	esac
	if [ "$allow_zero" = "NO" ]
	then
		max=`cat "$tmpdir/mysqladmin.$command.dat" | sort -nr -k 4 | head -1| awk '{ print $4}'`
		if [ $max -ne 0 ]
		then
			echo -n "$comma '$tmpdir/mysqladmin.$command.dat' using 1:(\$4/$divider) title '$command' with lines  lw 1"
			comma=","
		fi
	else
		echo -n "$comma '$tmpdir/mysqladmin.$command.dat' using 1:(\$4/$divider) title '$command' with lines  lw 1"
		comma=","
	fi
done

}


function print_cpu_graphs() {

CPUS=`grep "processor.:" $data_dir/cpuinfo | awk '{ print $3}'`
CPUS="$CPUS all"


echo -e "Data as of `date --date=@$measurement_start`\n"
pattern="%iowait"
header=`grep -m1 "$pattern" "$data_dir/mpstat.out"`
if test -z "$header"; then
	echo "There is no string '$pattern' in mpstat data. Can't parse $data_dir/mpstat.out."
	exit 
fi
i=1
CPU_idx=0
for h in $header
do
	if [ "$h" = "CPU" ]; then
		CPU_idx=$i
	fi
	if [ $CPU_idx -gt 0 ]
	then
		hdr[$(( $i - $CPU_idx))]="$h"
	fi
	i=$(( $i + 1))
done
n_fields=$i

if [ $CPU_idx -eq 0 ]; then
	echo "Can't find CPU column in mpstat header($header)"
	exit
fi

cat "$data_dir/mpstat.out" | awk "
{
	for (i=$CPU_idx; i <= $n_fields; i++)
		printf \"%s \", \$i
	printf \"%s\", \"\n\"
	}
" >> "$tmpdir/mpstat_raw"

for c in $CPUS
do
	echo "CPU #$c"
	echo "********************"
	echo ""
		cat "$tmpdir/mpstat_raw" | grep -e "^$c " | awk "
		BEGIN {
		        t=$measurement_start;
		}
		{
			print strftime(\"%F %T\", t), \$0
			t+=$interval;
		}" > "$tmpdir/mpstat.cpu-$c.dat"
plot_cmd=""
comma=""
for i in `seq $(($n_fields - $CPU_idx - 1))`
do
	if [ ${hdr[$i]} = "intr/s" ]; then continue; fi
	plot_cmd="$plot_cmd $comma '$tmpdir/mpstat.cpu-$c.dat' using 1:$(($i + 3)) title '${hdr[$i]}' with lines  lw 1"
	comma=","
done
	gp="
set terminal png 
set output '$pics_dir/CPU-$c.png'
set title 'CPU Usage(cpu #$c)'
set ylabel '%%'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics  rotate by -45 autofreq
set yrange [0:100]
set key inside right top
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $plot_cmd" 
	echo "$gp" | gnuplot
	echo -e ".. figure:: `basename $pics_dir`/CPU-$c.png"
	echo -e "   :scale: 200%\n"
done

}

function print_memory_graphs() {

echo -e "Memory"
echo -e "******\n"
cat $data_dir/vmstat.out | grep -v "memory" | grep -v "cache" | awk "
BEGIN { t=$measurement_start; }
{
	print strftime(\"%F %T\", t), \$0;
	t+=$interval;
}
" > "$tmpdir/vmstat_ts.out"
	echo "
set terminal png
set output '$pics_dir/vmstat-memory.png'
set title 'Memory Usage'
set ylabel 'Memory'
set xlabel 'time'
set format x '%H:%M:%S'
set format y '%.2s %cB'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics '00:00:00', $interval, '23:59:59'  rotate by -45 autofreq
set yrange [0:]
set key inside right top
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  '$tmpdir/vmstat_ts.out' using 1:(\$6*1000) title 'free' with lines  lw 1, \
	'$tmpdir/vmstat_ts.out' using 1:(\$7*1000) title 'buff' with lines  lw 1, \
	'$tmpdir/vmstat_ts.out' using 1:(\$8*1000) title 'cache' with lines  lw 1
	" | gnuplot
	echo -e ".. figure:: `basename $pics_dir`/vmstat-memory.png"
	echo -e "   :scale: 200%\n"

echo -e "Swap"
echo -e "****\n"
	echo "
set terminal png
set output '$pics_dir/vmstat-swap.png'
set title 'Swap Usage'
set ylabel 'Swap activity'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics '00:00:00', $interval, '23:59:59'  rotate by -45 autofreq
set yrange [0:]
set key inside right top
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  '$tmpdir/vmstat_ts.out' using 1:9 title 'Swap in' with lines  lw 1, \
	'$tmpdir/vmstat_ts.out' using 1:10 title 'Swap out' with lines  lw 1
	" | gnuplot
	echo -e ".. figure::  `basename $pics_dir`/vmstat-swap.png"
	echo -e "   :scale: 200%\n"
}

function print_disk_graphs() {
devices=`grep -v device "$data_dir/pt-diskstats.out" | awk '{ print $2}' |  grep -v loop | grep -v ram | sort | uniq `

for d in $devices
do
	echo "Disk $d"
	echo "*******************"

	grep "$d" "$data_dir/pt-diskstats.out" | awk -F: "
BEGIN { 
	t=$measurement_start;
	}
{
	print strftime(\"%F %T\", t), \$0;
        t+=$interval;
	}
" > "$tmpdir/pt-diskstats.$d.dat"

	echo "
set terminal png
set output '$pics_dir/disk-$d.png'
set title 'Disk Usage($d)'
set ylabel 'IOPS'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics  rotate by -45 autofreq
set yrange [0:]
set key outside right top
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  '$tmpdir/pt-diskstats.$d.dat' using 1:11 title 'Writes' with lines lw 1, \
	'$tmpdir/pt-diskstats.$d.dat' using 1:5 title 'Reads' with lines  lw 1
	" | gnuplot 
	echo -e "Usage"
	echo -e "-----\n"
	echo -e ".. image:: `basename $pics_dir`/disk-$d.png" 
	echo -e "  :scale: 200%\n"

	echo "
set terminal png
set output '$pics_dir/disk-rt$d.png'
set title 'Response time($d)'
set ylabel 'Response time, ms'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 
set yrange [0:]
set key outside right top
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot '$tmpdir/pt-diskstats.$d.dat' using 1:16 title 'Writes'  with lines lw 1, \
       	'$tmpdir/pt-diskstats.$d.dat' using 1:10 title 'Reads' with lines  lw 1
	" | gnuplot 
	echo -e "Response time"
	echo -e "-------------\n"
	echo -e ".. image:: `basename $pics_dir`/disk-rt$d.png"
	echo -e "  :scale: 200%\n"
	
	echo "
set terminal png
set output '$pics_dir/disk-rnd$d.png'
set title 'Level of sequential access($d)'
set ylabel 'Merged IO, %%'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics  rotate by -45 autofreq
set yrange [0:100]
set key outside right top
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot '$tmpdir/pt-diskstats.$d.dat' using 1:14 title 'Writes'  with lines lw 1, \
       	'$tmpdir/pt-diskstats.$d.dat' using 1:8 title 'Reads'  with lines lw 1
	" | gnuplot 
	echo -e "Sequential IO access"
	echo -e "--------------------\n"
	echo -e ".. image:: `basename $pics_dir`/disk-rnd$d.png"
	echo -e "  :scale: 200%\n"
done

}


function print_mysql_command_counters_graphs() {

#commands=`grep Com_ mysqladmin.out | awk '{ prin`t $2}' | sort | uniq`
commands=`pt-mext -- cat "$data_dir/mysqladmin.out"  | grep Com_ | sort -nr -k 2 | head -5 | awk '{ print $1}'`
commands="$commands Queries"
gp_data=`get_lines "$commands" "NO"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_commands.png'
set title 'MySQL queries'
set ylabel 'queries/sec'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key inside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_commands.png"
	echo -e "  :scale: 180%\n"
}

function print_mysql_api_handlers_graphs(){

commands=`grep Handler_ "$data_dir/mysqladmin.out" | awk '{ print $2}' | sort | uniq`
gp_data=`get_lines "$commands" "NO"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_Handler.png'
set title 'MySQL API requests'
set ylabel 'requests/sec'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key inside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Handler.png" 
	echo -e "  :scale: 180%\n" 
}

function print_mysql_thread_cache_graphs() {

commands="Threads_created Connections"
gp_data=`get_lines "$commands" "YES"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_Threads_cache.png'
set title 'Theads cache efficiency'
set ylabel 'sec^-1'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key inside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Threads_cache.png"
	echo -e "  :scale: 180%\n"

}

function print_mysql_table_cache_graphs() {

commands="Opened_tables"
gp_data=`get_lines "$commands" "YES"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_Opened_tables.png'
set title 'Openned tables'
set ylabel 'sec^-1'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key inside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Opened_tables.png"
        echo -e "  :scale: 180%\n"
}

function print_mysql_query_cache_graphs() {

query_cache_size=`grep query_cache_size $data_dir/mysql_variables | awk '{ print $2}'`
query_cache_type=`grep query_cache_type $data_dir/mysql_variables | awk '{ print $2}'`

if [ $query_cache_size -eq 0 ] || [ $query_cache_type -eq 0 ] || [ $query_cache_type = "OFF" ]
then
    echo -e "\nQuery cache is disabled"
    return
fi

echo -e "Query Cache"
echo -e "~~~~~~~~~~~\n" 

commands=`grep Qcache_ "$data_dir/mysqladmin.out" | awk '{ print $2}' | sort | uniq`
gp_data=`get_lines "$commands" "YES"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_Qcache.png'
set title 'Query cache usage'
set ylabel 'sec^-1'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key outside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Qcache.png"
        echo -e "  :scale: 180%\n"

echo -e "Qcache_hits vs  Com_select"
echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
#commands=`grep Qcache_ mysqladmin.out | awk '{ print $2}' | sort | uniq`
commands="Qcache_hits Com_select"
gp_data=`get_lines "$commands" "YES"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_Qcache_hits_select.png'
set title 'Qcache_hits vs  Com_select'
set ylabel 'requests/sec'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key inside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Qcache_hits_select.png"
        echo -e "  :scale: 180%\n"

echo -e "Qcache_hits vs Qcache_inserts"
echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
#commands=`grep Qcache_ mysqladmin.out | awk '{ print $2}' | sort | uniq`
commands="Qcache_hits Qcache_inserts"
gp_data=`get_lines "$commands" "YES"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_Qcache_hits_inserts.png'
set title 'Qcache_hits vs Qcache_inserts'
set ylabel 'requests/sec'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key inside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Qcache_hits_inserts.png"
        echo -e "  :scale: 180%\n"

echo -e "Query cache free memory"
echo -e "~~~~~~~~~~~~~~~~~~~~~~~\n"
#commands=`grep Qcache_ mysqladmin.out | awk '{ print $2}' | sort | uniq`
commands="Qcache_free_memory"
gp_data=`get_lines "$commands" "YES"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_Qcache_free_memory.png'
set title 'Query cache free memory'
set ylabel 'Memory'
set xlabel 'time'
set format x '%H:%M:%S'
set format y '%.2s %cB'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key inside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Qcache_free_memory.png"
        echo -e "  :scale: 180%\n"

}

function print_mysql_Innodb_log_waits_graphs(){

init_vars

commands="Innodb_log_waits"
gp_data=`get_lines "$commands" YES`
	gp="
set terminal png 
set output '$pics_dir/mysqladmin_innodb_log_waits.png'
set title 'innodb_log_waits'
set ylabel 'sec^-1'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key inside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_innodb_log_waits.png"
        echo -e "  :scale: 200%\n"
}

function print_mysql_Innodb_os_log_written_graphs(){

init_vars

commands="Innodb_os_log_written"
gp_data=`get_lines "$commands" YES`
	gp="
set terminal png 
set output '$pics_dir/mysqladmin_Innodb_os_log_written.png'
set title 'Writes to REDO log'
set ylabel 'bytes/sec'
set format y '%.2s %cB'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key inside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Innodb_os_log_written.png"
        echo -e "  :scale: 200%\n"
}

function print_mysql_binary_logging_graphs() {

init_vars

commands=`grep Binlog_ "$data_dir/mysqladmin.out" | awk '{ print $2}' | sort | uniq`
gp_data=`get_lines "$commands" "YES"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_Binlog.png'
set title 'The number of transactions that used the binary log cache'
set ylabel 'transactions/sec'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key outside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Binlog.png"
        echo -e "  :scale: 180%\n"
}

function print_mysql_tmp_tables_graphs(){

commands=`grep Created_ "$data_dir/mysqladmin.out" | awk '{ print $2}' | sort | uniq`
gp_data=`get_lines "$commands" "YES"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_temporary.png'
set title 'Temporary tables usage'
set ylabel 'created tables per sec'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key inside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_temporary.png"
        echo -e "  :scale: 180%\n"
}

function print_mysql_select_types_graphs(){

commands=`grep Select_ "$data_dir/mysqladmin.out" | awk '{ print $2}' | sort | uniq`
gp_data=`get_lines "$commands" "NO"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_Select.png'
set title 'Select types'
set ylabel 'queries/sec'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key outside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Select.png"
        echo -e "  :scale: 180%\n"
}

function print_mysql_sorting_graphs(){

commands=`grep Sort_ "$data_dir/mysqladmin.out" | awk '{ print $2}' | sort | uniq`
gp_data=`get_lines "$commands" "YES"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_Sort.png'
set title 'Sorting activity'
set ylabel 'sorted rows/sec'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key outside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Sort.png"
        echo -e "  :scale: 180%\n"
}

function print_mysql_table_locks_graphs(){

init_vars

commands=`grep Table_locks_ "$data_dir/mysqladmin.out" | awk '{ print $2}' | sort | uniq`
gp_data=`get_lines "$commands" "YES"`
	gp="
set terminal png size 1024,600
set output '$pics_dir/mysqladmin_Table_locks.png'
set title 'Table level locking'
set ylabel 'sec^-1'
set xlabel 'time'
set format x '%H:%M:%S'
set timefmt '%Y-%m-%d %H:%M:%S'
set xdata time
set xtics rotate by -45 autofreq
set yrange [0:]
set key inside right top
#set rmargin 50
#set lmargin 50
#set key off
set datafile missing 'NaN'
set grid xtics
set grid ytics
plot  $gp_data"
	echo "$gp" | gnuplot
	echo -e ".. image:: `basename $pics_dir`/mysqladmin_Table_locks.png"
        echo -e "  :scale: 180%\n"
}
