#!/bin/bash

set -e
if ! test -z "$1"
then
	out_dir="$1"
else
	out_dir=data-`hostname`-`date +%F`
fi
if ! test -z "$2"
then   
        runtime="$2"
else   
        let runtime=24*3600
fi
set -ue

if [ `whoami` != 'root' ]
then
    echo "$0 must be run by root"
    exit
fi
stats_prefix=`date +%F_%H-%M-%S`
stats_prefix=""
pkgtool=""

if ! test -z "`which yum`"
then
    pkgtool="yum"
else
    if ! test -z "`which apt-get`"
    then
        pkgtool="apt"
    else
        echo "Neither apt not yum is found. The script $0 needs either of them to work"
        exit
    fi
fi

function check_mpstat {
if test -z "`which mpstat`"
then
    echo "mpstat not found."
    echo  "Install package with command"
    if [ $pkgtool = "yum" ]
    then
        echo "yum install sysstat"
    else
        echo "apt-get install sysstat"
    fi
    exit
fi
}

function check_vmstat {
if test -z "`which vmstat`"
then
    echo "vmstat not found."
    echo  "Install package with command"
    if [ $pkgtool = "yum" ]
    then
        echo "yum install procps"
    else
        echo "apt-get install procps"
    fi
    exit
fi
}

function check_mysqladmin {
if test -z "`which mysqladmin`"
then
    echo "mysqladmin not found."
    echo  "Install package with command"
    if [ $pkgtool = "yum" ]
    then
        echo "yum install mysql"
    else
        echo "apt-get install mysql"
    fi
    exit
fi
}

function check_pt {
if test -z "`which pt-diskstats`"
then
    echo "Percona toolkit not found."
    echo  "Install package with command"
    if [ $pkgtool = "yum" ]
    then
        echo "yum install percona-toolkit"
    else
        echo "apt-get install percona-toolkit"
    fi
    echo "Check http://www.percona.com/software/percona-toolkit for more details"
    exit
fi
}
# check if all tools are available

check_mysqladmin
check_vmstat
check_mpstat
check_pt


interval=$(($runtime/1000))
if [ $interval -eq 0 ]; then
	interval=1
fi

mkdir -p "$out_dir"
echo "$stats_prefix" > "$out_dir"/stats_prefix
echo "$interval" > "$out_dir"/interval
date +%s > "$out_dir"/measurement_start

nohup mpstat -P ALL $interval $((runtime/$interval)) > "$out_dir/${stats_prefix}mpstat.out" &
nohup vmstat $interval $((runtime/$interval)) > "$out_dir/${stats_prefix}vmstat.out" &
nohup mysqladmin ext -r -i $interval -c $((runtime/$interval))  > "$out_dir/${stats_prefix}mysqladmin.out" &
nohup pt-diskstats --interval $interval --group-by all --iterations $((runtime/$interval)) --show-timestamps --show-inactive > "$out_dir/${stats_prefix}pt-diskstats.out" &

mysql -NBe "SHOW GLOBAL VARIABLES" > "$out_dir/${stats_prefix}mysql_variables"
mysql -NBe "SHOW GLOBAL STATUS" > "$out_dir/${stats_prefix}mysql_global_status"
mysql -NBe "SHOW ENGINE INNODB STATUS\G" > "$out_dir/${stats_prefix}mysql_innodb_status"

cat /proc/cpuinfo > "$out_dir"/cpuinfo
cat /proc/meminfo > "$out_dir"/meminfo
dmidecode > "$out_dir"/dmidecode
sysctl -a > "$out_dir"/sysctl
pt-summary > "$out_dir"/pt-summary
dmesg > "$out_dir"/dmesg

# LVM 
! test -z "`which lvdisplay`" && lvdisplay > "$out_dir"/lvdisplay
! test -z "`which vgdisplay`" && vgdisplay > "$out_dir"/vgdisplay
! test -z "`which vgdisplay`" && pvdisplay > "$out_dir"/pvdisplay

MY_CNF=""
test -f "/etc/my.cnf" && MY_CNF="/etc/my.cnf"
test -f "/etc/mysql/my.cnf" && MY_CNF="/etc/mysql/my.cnf"
if ! test -z "$MY_CNF"
then
    echo -e "pt-config-diff localhost $MY_CNF\n" > "$out_dir"/pt-config-diff
    set +e
    pt-config-diff localhost $MY_CNF >> "$out_dir"/pt-config-diff
    set -e
else
    echo "Neither /etc/my.cnf nor /etc/mysql/my.cnf exists" > "$out_dir"/pt-config-diff
fi

df "`grep datadir \"$out_dir/${stats_prefix}mysql_variables\" | sed -e 's/datadir//' -e 's/\t//'`" > "$out_dir"/mysql_datadir_partition

mysql_datadir="`mktemp -d`"
mysql_socket="$mysql_datadir/mysql.sock"
mysql_start_timeout="300"
mysql_user="nobody"

mkdir -p "$mysql_datadir"
mysql_install_db --no-defaults --datadir="$mysql_datadir"
chown -R $mysql_user "$mysql_datadir"
mysqld --no-defaults --datadir="$mysql_datadir" --socket="$mysql_socket" --user=$mysql_user --skip-networking --skip-grant-tables &

while [ "`mysql -NB --socket=\"$mysql_socket\" -e 'select 1'`" != "1" ]
do
	echo "Waiting till aux instance of MySQL starts"
	sleep 1
	mysql_start_timeout=$(($mysql_start_timeout - 1))
	if [ $mysql_start_timeout -eq 0 ]; then echo "Can't start aux instance of MySQL. Exiting..."; exit ; fi
done
mysql --socket="$mysql_socket" -NBe "SHOW GLOBAL VARIABLES" > "$out_dir/${stats_prefix}mysql_variables_default"
mysqladmin --socket="$mysql_socket" shutdown
rm -rf "$mysql_datadir"

error_log=`mysql -NBe 'SELECT @@log_error'`
if test -f "$error_log" ; then
        cp "$error_log" "$out_dir/${stats_prefix}error_log"
        chmod 644 "$out_dir/${stats_prefix}error_log"
fi


pt-duplicate-key-checker > "$out_dir/${stats_prefix}pt-duplicate-key-checker"

cmd="# du -sh \`mysql -NBe 'SELECT @@datadir'\`"
echo "$cmd" > "$out_dir/${stats_prefix}data_usage_raw"
mysql_datadir=`mysql -NBe 'SELECT @@datadir'`
du -sh "$mysql_datadir" >> "$out_dir/${stats_prefix}data_usage_raw"

cmd="# find \`mysql -NBe 'SELECT @@datadir'\` -name *.ibd -or -name ibdata* | xargs du -shc  | tail -1"
echo "$cmd" > "$out_dir/${stats_prefix}data_usage_innodb_raw"
du -sh "$mysql_datadir" >> "$out_dir/${stats_prefix}data_usage_innodb_raw"

cmd="# find \`mysql -NBe 'SELECT @@datadir'\` -name *.MYD | xargs du -shc  | tail -1"
echo "$cmd" > "$out_dir/${stats_prefix}data_usage_myisam_raw"
find "$mysql_datadir" -name *.MYD | xargs du -shc  | tail -1 >> "$out_dir/${stats_prefix}data_usage_myisam_raw"

echo ""

cmd="# find \`mysql -NBe 'SELECT @@datadir'\` -name *.MYI | xargs du -shc  | tail -1"
echo "$cmd" >> "$out_dir/${stats_prefix}data_usage_myisam_raw"
find "$mysql_datadir" -name *.MYI | xargs du -shc  | tail -1 >> "$out_dir/${stats_prefix}data_usage_myisam_raw"


sql="select engine, 
	round(sum(data_length+index_length)/1024/1024/1024, 2) as total_gb, 
	round(sum(data_length)/1024/1024/1024,2) as data_gb, 
	round(sum(index_length)/1024/1024/1024,2) as index_gb 
	from information_schema.tables 
	group by 1 
	order by 2 desc"

echo "$sql" > "$out_dir/${stats_prefix}data_usage_by_storage_engine.sql"


mysql --table -e "$sql" > "$out_dir/${stats_prefix}data_usage_by_storage_engine"

line=`grep "+--" "$out_dir/${stats_prefix}data_usage_by_storage_engine" | head -1`

sed -i -e "s/\(.*|$\)/\1\n$line/" "$out_dir/${stats_prefix}data_usage_by_storage_engine"

sql="SELECT CONCAT(table_schema, '.', table_name) tbl,
	CONCAT(ROUND(table_rows / 1000000, 2), 'M') rows,
	CONCAT(ROUND(data_length / ( 1024 * 1024 * 1024 ), 2), 'G') DATA,
	CONCAT(ROUND(index_length / ( 1024 * 1024 * 1024 ), 2), 'G') idx,
	CONCAT(ROUND(( data_length + index_length ) / ( 1024 * 1024 * 1024 ), 2), 'G') total_size,
	ROUND(index_length / data_length, 2) idxfrac
	FROM   information_schema.TABLES 
	ORDER  BY data_length + index_length 
	DESC LIMIT  10;"

echo "$sql" > "$out_dir/${stats_prefix}data_usage_by_table.sql"


mysql --table -e "$sql" > "$out_dir/${stats_prefix}data_usage_by_table"

line=`grep "+--" "$out_dir/${stats_prefix}data_usage_by_table" | head -1`

sed -i -e "s/\(.*|$\)/\1\n$line/" "$out_dir/${stats_prefix}data_usage_by_table"

sql="SHOW GLOBAL VARIABLES LIKE 'have_%'"

mysql --table -e "$sql" > "$out_dir/${stats_prefix}mysql_have_features"
line=`grep "+--" "$out_dir/${stats_prefix}mysql_have_features" | head -1`
sed -i -e "s/\(.*|$\)/\1\n$line/" "$out_dir/${stats_prefix}mysql_have_features"

