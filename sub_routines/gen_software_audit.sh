function gen_software_audit(){
echo "
Software Audit
#################

Operating System
================

Version
*******

::

`print_pt_summary_snippet "# Percona Toolkit System Summary Report ##" "# Processor ##" | grep -e "Percona Toolkit System Summary Report" -e "Platform" -e "Release" -e "Kernel" -e "Architecture"`


|ok| |warning| |error| Here's consultant's comments

Swappiness
**********

\`\`vm.swappiness\`\` is an option that instructs the kernel how  agressively it should swap. Zero means *do not swap unless it's absolutely necessary*. Non-zero values is not recommended::

	`grep swappiness $data_dir/sysctl`

|ok| |warning| |error| Here's consultant's comments

IO Scheduler
************

::

`print_pt_summary_snippet "# Disk Schedulers And Queue Size ##" "# Disk Partioning ##"`

|ok| |warning| |error| Here's consultant's comments [#]_

   .. [#] http://kmaiti.blogspot.com/2011/09/what-is-io-scheduler-for-hard-disk-on.html

File Systems
************

::

`print_pt_summary_snippet "# Mounted Filesystems ##" "# Disk Schedulers And Queue Size ##"`

MySQL datadir is on partition:: 

`cat $data_dir/mysql_datadir_partition | sed 's/\(.\)/      \1/'`

|ok| |warning| |error| Here's consultant's comments

LVM
************

`print_lvm_details`

MySQL Version
=============

`print_mysql_version`

|ok| |warning| |error| Here's consultant's comments

MySQL Features
**************

`print_mysql_features`

|ok| |warning| |error| Here's consultant's comments


MySQL Configuration
*******************

Differences Between my.cnf And Actual Configuration
---------------------------------------------------

::

`if test -f "$data_dir/pt-config-diff"; then  cat "$data_dir/pt-config-diff" | sed 's/\(.\)/      \1/'; else echo "      Data wasn't collected"; fi`

|ok| |warning| |error| Here's consultant's comments

General Server Configuration
----------------------------


`print_general_mysql_options`

InnoDB Configuration
--------------------

`print_innodb_mysql_options`

" > $report_dir/software_audit.rst

echo "
Full List of MySQL variables
============================


$(print_mysql_options_table `awk '{ print $1}' "$data_dir/mysql_variables"`)


" > $report_dir/appendixes/mysql_variables.rst


}

function print_mysql_version() {

for v in `grep version $data_dir/mysql_variables | awk '{ print $1}' | grep -v -w -e slave_type_conversions -e protocol_version`
do
	echo -en "\n:$v:\n\t"
	grep -w $v $data_dir/mysql_variables | sed -e "s/^$v//" -e 's/\t//' -e 's/\n//g'
done
}
function print_mysql_features() {

if test -f "$data_dir/mysql_have_features"
then
    cat "$data_dir/mysql_have_features"
else
    for v in `grep have_ $data_dir/mysql_variables | awk '{ print $1}'`
    do
        echo -en "\n:$v:\n\t"
        grep -w $v $data_dir/mysql_variables | sed -e "s/^$v//" -e 's/\t//' -e 's/\n//g'
    done
fi

}

function print_general_mysql_options (){

options=`diff -u $data_dir/mysql_variables_default $data_dir/mysql_variables | grep -e "^+" -e "^-"| grep -v -e innodb -e '+' -e '--' | awk '{ print $1}' | sed -e 's/+//' -e 's/-//'`
# Add important options
options="$options
secure_auth
skip_name_resolve
old_passwords
expire_logs_days
"

options_sorted=`printf "%s" "$options" | sort | uniq`

for o in $options_sorted
do
    print_mysql_options_table $o 
done

}

function print_innodb_mysql_options (){

options=`diff -u $data_dir/mysql_variables_default $data_dir/mysql_variables | grep -e "^+" -e "^-"| grep innodb | awk '{ print $1}' | sed -e 's/+//' -e 's/-//'`
# Add important options
options="$options
innodb_buffer_pool_size
innodb_file_per_table
innodb_flush_method
innodb_log_file_size"

options_sorted=`printf "%s" "$options" | sort | uniq`

for o in $options_sorted
do
    print_mysql_options_table $o 
done

}

function h_size() {
    local value=$1
    local unit=$2
    if ! test -z "`echo $value | grep -E '^[0-9]+$'`"
    then
        echo $value| numfmt --to=$unit
    else
        echo $value
    fi
}

function h_option() {
    local option=$1
    local value=$2
    case "$option" in
        "server_id") echo $value;;
        "port") echo $value;;
        "report_port") echo $value;;
        "expire_logs_days") h_size $value si ;;
        "max_connect_errors") h_size $value si ;;
        "max_connections") h_size $value si ;;
        "open_files_limit") h_size $value si ;;
        "table_definition_cache") h_size $value si ;;
        "table_open_cache") h_size $value si ;;
        "thread_cache_size") h_size $value si ;;
        "interactive_timeout") h_size $value si ;;
        *)  h_size $value iec-i
    esac
}

function print_mysql_options (){

cat > ignore_options <<IGNOREEOF
basedir
datadir
general_log_file
log_error
log_slow_queries
pid_file
port
report_port
skip_networking
slow_query_log_file
socket
version
IGNOREEOF
	

local value=""
local default_value=""

for option in `echo $*`
do
	if ! test -z "`echo $option | grep -wf ignore_options`"; then continue; fi
	value=`grep -w $option $data_dir/mysql_variables | sed -e "s/$option//" -e 's/\t//'`
    value=`h_option $option $value`
	default_value=`grep -w $option $data_dir/mysql_variables_default | sed -e "s/$option//" -e 's/\t//'`
    default_value=`h_option $option $default_value`
	
	if [ ${#value} -gt 40 ]; then value=${value:0:40}; fi

	local f1="Option"
	local f2="Value"
	local f3="Default Value"
	local f1_len=${#f1}
	local f2_len=${#f2}
	local f3_len=${#f3}

	if [ ${#option} -gt $f1_len ]; then f1_len=${#option}; fi
	if [ ${#value} -gt $f2_len ]; then f2_len=${#value}; fi
	if [ ${#default_value} -gt $f3_len ]; then f3_len=${#default_value}; fi
	
	local max_len=$((${f1_len} + ${f2_len} + ${f3_len}))
	local line=""
	for i in `seq $max_len`; do line="${line}="; done
	
	pad_line="${line:0:${f1_len}} ${line:0:${f2_len}} ${line:0:${f3_len}}"
	echo "$pad_line"
	printf "%${f1_len}s %${f2_len}s %${f3_len}s\n" "Option" "Value" "Default Value"
	echo "$pad_line"
	printf "%${f1_len}s %${f2_len}s %${f3_len}s\n" "$option" "$value" "$default_value"
	echo "$pad_line"
	
	echo ""
	echo "|ok| |warning| |error| Here's consultant's comments"
	echo ""
done
rm -f ignore_options

}

function print_lvm_details() {

if test -f "$data_dir/lvdisplay"
then
    echo -e "Logical Volumes"
    echo -e "---------------\n::\n"
    cat $data_dir/lvdisplay
    echo -e "Volume Groups"
    echo -e "---------------\n::\n"
    cat $data_dir/vgdisplay
    echo -e "Physical Volumes"
    echo -e "----------------\n::\n"
    cat $data_dir/pvdisplay
else
    echo "LVM details are not collected"  
fi
}

function print_mysql_options_table() {

local value=""
local default_value=""
local max_field_legth=25

# get lengths of fields
local f1="Option"
local f2="Value"
local f3="Default Value"
local f1_len=${#f1}
local f2_len=${#f2}
local f3_len=${#f3}
for option in `echo $*`
do
    value=`grep -w $option $data_dir/mysql_variables | sed -e "s/$option//" -e 's/\t//'`
    test -z "$value" && value="<EMPTY>"
    value=`h_option $option $value`
    default_value=`grep -w $option $data_dir/mysql_variables_default | sed -e "s/$option//" -e 's/\t//'`
    test -z "$default_value" && default_value="<EMPTY>"
    default_value=`h_option $option $default_value`
	
	if [ ${#value} -gt $max_field_legth ]; then value=${value:0:$max_field_legth}; fi
	if [ ${#default_value} -gt $max_field_legth ]; then default_value=${default_value:0:$max_field_legth}; fi

	if [ ${#option} -gt $f1_len ]; then f1_len=${#option}; fi
	if [ ${#value} -gt $f2_len ]; then f2_len=${#value}; fi
	if [ ${#default_value} -gt $f3_len ]; then f3_len=${#default_value}; fi
done
    
local max_len=$((${f1_len} + ${f2_len} + ${f3_len}))
local line=""
for i in `seq $max_len`; do line="${line}="; done
local pad_line="${line:0:${f1_len}} ${line:0:${f2_len}} ${line:0:${f3_len}}"

# print header

echo "$pad_line"
printf "%${f1_len}s %${f2_len}s %${f3_len}s\n" "Option" "Value" "Default Value"
echo "$pad_line"

for option in `echo $*`
do
    value=`grep -w $option $data_dir/mysql_variables | sed -e "s/$option//" -e 's/\t//'`
    test -z "$value" && value="<EMPTY>"
    value=`h_option $option $value`
    default_value=`grep -w $option $data_dir/mysql_variables_default | sed -e "s/$option//" -e 's/\t//'`
    test -z "$default_value" && default_value="<EMPTY>"
    default_value=`h_option $option $default_value`
	
	if [ ${#value} -gt $max_field_legth ]; then value=${value:0:$max_field_legth}; fi
	if [ ${#default_value} -gt $max_field_legth ]; then default_value=${default_value:0:$max_field_legth}; fi

	printf "%${f1_len}s %${f2_len}s %${f3_len}s\n" "$option" "$value" "$default_value"
	
done
	echo "$pad_line"

    echo -e "\n|ok| |warning| |error| Here's consultant's comments\n"
}
