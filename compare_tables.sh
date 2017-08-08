#!/bin/bash

# Usage:
# $0 database table master slave
set -eux
db=$1
tbl=$2
master=$3
slave=$4
tmpdir=`mktemp -d`

checksum_table="percona.checksums"

chunks=`mysql -h $slave -NBe "select chunk from $checksum_table where (this_crc<>master_crc or this_cnt<>master_cnt) AND db='$db' AND tbl='$tbl'"`

for c in $chunks
do
    echo "# $db.$tbl, chunk $c"
    chunk_index=`mysql -h $slave -NBe "SELECT chunk_index FROM $checksum_table WHERE db='$db' AND tbl='$tbl' AND chunk = '$c'"`
    index_fields=`mysql -h $slave -NBe "SELECT COLUMN_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$tbl' AND INDEX_NAME='$chunk_index' ORDER BY SEQ_IN_INDEX"`
    index_field_last=`mysql -h $slave -NBe "SELECT COLUMN_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$tbl' AND INDEX_NAME='$chunk_index' ORDER BY SEQ_IN_INDEX DESC LIMIT 1"`
# EXAMPLE:
#
#WHERE 
#    (
#    (`user_id` > ?) 
#    OR 
#    (`user_id` = ? AND `activity_id` > ?) 
#    OR 
#    (`user_id` = ? AND `activity_id` = ? AND `activity_type_id` >= ?)
#    ) 
#AND 
#  (
#    (`user_id` < ?) 
#    OR 
#    (`user_id` < ?) 
#    OR 
#    (`user_id` = ? AND `activity_id` < ?) 
#    OR 
#    (`user_id` = ? AND `activity_id` = ? AND `activity_type_id` <= ?)
#    )
	if [ "$chunk_index" != "NULL" ]
    then
        where="WHERE"
        v_num=1
        lower_boundary=`mysql -h $slave -NBe "SELECT lower_boundary FROM $checksum_table WHERE db='$db' AND tbl='$tbl' AND chunk = '$c'"`
        upper_boundary=`mysql -h $slave -NBe "SELECT upper_boundary FROM $checksum_table WHERE db='$db' AND tbl='$tbl' AND chunk = '$c'"`
        clause_fields=""
        where="$where (0 "
        for f in $index_fields
        do 
            clause_fields="$f $clause_fields"
            op=""
            where="$where OR ( 1"
            for cf in $clause_fields
            do
                if test -z "$op"
                then   
                    if [ $cf == $index_field_last ]
                    then   
                        op=">="
                    else   
                        op=">"
                    fi
                else   
                    op="="
                fi
                v=`echo $lower_boundary | awk -F, "{ print \\\$$v_num}"`
                v_num=$(( $v_num + 1))
                where="$where AND \`$cf\` $op '$v'"
            done
            where="$where )"
        done
        where="$where )"

        v_num=1
        clause_fields=""
        where="$where AND ( 0"
        for f in $index_fields
        do 
            clause_fields="$f $clause_fields"
            op=""
            where="$where OR ( 1"
            for cf in $clause_fields
            do
                if test -z "$op"
                then   
                    if [ $cf == $index_field_last ]
                    then   
                        op="<="
                    else   
                        op="<"
                    fi
                else   
                    op="="
                fi
                v=`echo $upper_boundary | awk -F, "{ print \\\$$v_num}"`
                v_num=$(( $v_num + 1))
                where="$where AND \`$cf\` $op '$v'"
            done
            where="$where )"
        done
		where="$where )"
	else
		where="WHERE  1 "
	fi
    echo $where
    mysql -h $master -NBe "SELECT * FROM $db.$tbl $where"  >> "$tmpdir/master"
    mysql -h $slave -NBe "SELECT * FROM $db.$tbl $where"  >> "$tmpdir/slave"
    set +e
    diff -u "$tmpdir/master" "$tmpdir/slave" | less -S
    set -e
done
rm -r "$tmpdir"
