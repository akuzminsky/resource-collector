function gen_mysql_data_distribution(){
echo "
MySQL Data Distribution
#######################

Database Raw Filesystem Usage
=============================

::

` cat $data_dir/data_usage_raw | fold -s | sed 's/\(.\)/      \1/'`


|ok| |warning| |error| Here's consultant's comments



InnoDB Tables
*************

::

` cat $data_dir/data_usage_innodb_raw | fold -s | sed 's/\(.\)/      \1/'`


|ok| |warning| |error| Here's consultant's comments


MyISAM Tables
*************

::

` cat $data_dir/data_usage_myisam_raw | fold -s | sed 's/\(.\)/      \1/'`


|ok| |warning| |error| Here's consultant's comments

Disk Usage by Storage Engine
============================

.. code-block:: sql

	`cat $data_dir/data_usage_by_storage_engine.sql | fold -s | sed 's/\(.\)/      \1/'`

`cat $data_dir/data_usage_by_storage_engine`


|ok| |warning| |error| Here's consultant's comments

Data Distribution Across Tables
===============================

.. code-block:: sql

	`cat $data_dir/data_usage_by_table.sql | fold -s | sed 's/\(.\)/      \1/'`

`cat $data_dir/data_usage_by_table`


|ok| |warning| |error| Here's consultant's comments

" > $report_dir/mysql_data_distribution.rst
}

