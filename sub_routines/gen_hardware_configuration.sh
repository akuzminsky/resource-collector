function gen_hardware_configuration() {

rm -f $report_dir/hardware_configuration.rst

cpu_model=`grep "model name" $data_dir/cpuinfo | head -1 | awk -F: '{ print $2}'`
cpu_number=`grep "processor" $data_dir/cpuinfo | wc -l`
cpu_freq=`grep "cpu MHz" $data_dir/cpuinfo | head -1 | awk -F: '{ print $2}'`

mem_total_kb=`grep "MemTotal" $data_dir/meminfo | awk '{ print $2}'`
mem_total_mb=$(($mem_total_kb / 1024))
mem_total_Gb=$(($mem_total_mb / 1024))

echo "
Hardware Configuration
######################

Summary
=======

Server overview::

`print_pt_summary_snippet "# Percona Toolkit System Summary Report ##" "# Processor ##"`

|ok| |warning| |error| Here's consultant's comments


CPU
===
:CPU Model:
	$cpu_model

:Number of CPUs:
	$cpu_number

:Actual clock frequency, MHz:
	$cpu_freq

CPU as reported by pt-summary::

`print_pt_summary_snippet "# Processor ##" "# Memory ##"`

\`Full /proc/cpuinfo output\`_

|ok| |warning| |error| Here's consultant's comments

Memory
======

:Installed RAM:
	$mem_total_Gb GB ($mem_total_mb MB)

`print_memory_table`

|ok| |warning| |error| Here's consultant's comments

Disks
======

`print_pt_summary_raid_controller`


|ok| |warning| |error| Here's consultant's comments


Network devices
===============

::

`print_pt_summary_snippet "# Network Devices ##" "# Network Connections ##"`


|ok| |warning| |error| Here's consultant's comments



" >> $report_dir/hardware_configuration.rst

echo "
Full /proc/cpuinfo output
=========================
::

        # cat /proc/cpuinfo
`fold -s $data_dir/cpuinfo | sed 's/\(.\)/      \1/'`

" > $report_dir/appendixes/proc_cpuinfo.rst

}

function print_memory_table() {

local f1="Locator"
local f2="Size"
local f3="Speed"
local f4="Form Factor"
local f5="Type"
local f6="Type Detail"
local f1_len=${#f1}
local f2_len=${#f2}
local f3_len=${#f3}
local f4_len=${#f4}
local f5_len=${#f5}
local f6_len=${#f6}

n_slots=`grep "Memory Device$" $data_dir/dmidecode | wc -l`
csplit --prefix=dmidecode --digits=8 $data_dir/dmidecode "/^Memory Device$/" {*} > /dev/null 2>&1
rm -f dmidecode00000000

for slot in `seq $n_slots`
do
	dmifile=`printf "dmidecode%08d" $slot`
	f1=`grep  "^[[:space:]]*Locator:" $dmifile | awk -F: '{ print $2}' | head -1`
	f2=`grep  "^[[:space:]]*Size:" $dmifile | awk -F: '{ print $2}' | head -1`
	f3=`grep  "^[[:space:]]*Speed:" $dmifile | awk -F: '{ print $2}' | head -1`
	f4=`grep  "^[[:space:]]*Form Factor:" $dmifile | awk -F: '{ print $2}' | head -1`
	f5=`grep  "^[[:space:]]*Type:" $dmifile | awk -F: '{ print $2}' | head -1`
	f6=`grep  "^[[:space:]]*Type Detail:" $dmifile | awk -F: '{ print $2}' | head -1`
	if [ ${#f1} -gt $f1_len ]; then f1_len=${#f1}; fi
	if [ ${#f2} -gt $f2_len ]; then f2_len=${#f2}; fi
	if [ ${#f3} -gt $f3_len ]; then f3_len=${#f3}; fi
	if [ ${#f4} -gt $f4_len ]; then f4_len=${#f4}; fi
	if [ ${#f5} -gt $f5_len ]; then f5_len=${#f5}; fi
	if [ ${#f6} -gt $f6_len ]; then f6_len=${#f6}; fi
done
f1="Locator"
f2="Size"
f3="Speed"
f4="Form Factor"
f5="Type"
f6="Type Detail"


local max_len=$((${f1_len}+${f2_len}+${f3_len}+${f4_len}+${f5_len}+${f6_len}))
local line=""
for i in `seq $max_len`; do line="${line}="; done

pad_line="${line:0:${f1_len}} ${line:0:${f2_len}} ${line:0:${f3_len}} ${line:0:${f4_len}} ${line:0:${f5_len}} ${line:0:${f6_len}}"
echo "$pad_line"
printf "%${f1_len}s %${f2_len}s %${f3_len}s %${f4_len}s %${f5_len}s %${f6_len}s\n" "$f1" "$f2" "$f3" "$f4" "$f5" "$f6"
echo "$pad_line"
for slot in `seq $n_slots`
do
	dmifile=`printf "dmidecode%08d" $slot`
	f1=`grep  "^[[:space:]]*Locator:" $dmifile | awk -F: '{ print $2}' | head -1`
	f2=`grep  "^[[:space:]]*Size:" $dmifile | awk -F: '{ print $2}' | head -1`
	f3=`grep  "^[[:space:]]*Speed:" $dmifile | awk -F: '{ print $2}' | head -1`
	f4=`grep  "^[[:space:]]*Form Factor:" $dmifile | awk -F: '{ print $2}' | head -1`
	f5=`grep  "^[[:space:]]*Type:" $dmifile | awk -F: '{ print $2}' | head -1`
	f6=`grep  "^[[:space:]]*Type Detail:" $dmifile | awk -F: '{ print $2}' | head -1`
	printf "%${f1_len}s %${f2_len}s %${f3_len}s %${f4_len}s %${f5_len}s %${f6_len}s \n" "$f1" "$f2" "$f3" "$f4" "$f5" "$f6"
	rm -f "$dmifile"
done

echo "$pad_line"

}

function print_pt_summary_raid_controller() {

local start=`grep -n "# RAID Controller ##" $data_dir/pt-summary | awk -F: '{ print $1}'`
local stop=`grep -n "# Network Config ##" $data_dir/pt-summary | awk -F: '{ print $1}'`

echo -e "\nRAID controller as reported by pt-summary::\n"

pt_summary_raid="`head -$(($stop-1)) $data_dir/pt-summary | tail -$(($stop - $start)) | fold -s | sed 's/\(.\)/      \1/'`"

printf "%s\n" "$pt_summary_raid"

if ! test -z "`echo $pt_summary_raid | grep 'No RAID controller detected'`"
then
	echo -e "\nSCSI devices::\n"
	cat $data_dir/dmesg | grep "scsi [0-9]" | sed 's/ \+/ /g'| fold -s | sed 's/\(.\)/      \1/'
fi

}

