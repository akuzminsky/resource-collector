function gen_duplicate_indexes(){
echo "
Duplicate Indexes
#################

.. code-block:: sql

`cat $data_dir/pt-duplicate-key-checker | fold -s | sed 's/\(.\)/      \1/'`

" > $report_dir/duplicate_indexes.rst
}

