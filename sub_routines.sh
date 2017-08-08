. /usr/share/rdba-audit/sub_routines/gen_title.sh
. /usr/share/rdba-audit/sub_routines/gen_executive_summary.sh
. /usr/share/rdba-audit/sub_routines/gen_queries_audit.sh
. /usr/share/rdba-audit/sub_routines/gen_hardware_configuration.sh
. /usr/share/rdba-audit/sub_routines/gen_software_audit.sh
. /usr/share/rdba-audit/sub_routines/gen_operating_system_audit.sh
. /usr/share/rdba-audit/sub_routines/gen_mysql_configuration_audit.sh
. /usr/share/rdba-audit/sub_routines/gen_resource_utilization_audit.sh
. /usr/share/rdba-audit/sub_routines/gen_mysql_utilization_statistics.sh
. /usr/share/rdba-audit/sub_routines/gen_error_log.sh
. /usr/share/rdba-audit/sub_routines/gen_mysql_data_distribution.sh
. /usr/share/rdba-audit/sub_routines/gen_duplicate_indexes.sh
. /usr/share/rdba-audit/sub_routines/gen_appendixes.sh

function print_pt_summary_snippet() {

local start=`grep -n "$1" $data_dir/pt-summary | awk -F: '{ print $1}'`
local stop=`grep -n "$2" $data_dir/pt-summary | awk -F: '{ print $1}'`

pt_summary_snippet="`head -$(($stop-1)) $data_dir/pt-summary | tail -$(($stop - $start)) | fold -s | sed 's/\(.\)/      \1/'`"

printf "%s\n" "$pt_summary_snippet"
}

function usage(){
    echo "$0 [-d <data-dir>] [-r <report-dir>]"
    echo "    -d <data-dir>   - directory with collected data(result of collect.sh)"
    echo "                      Default ./data"
    echo "    -r <report-dir> - directory where a report will be generated"
    echo "                      Default ./report-`date +%F`"
    exit
    }


