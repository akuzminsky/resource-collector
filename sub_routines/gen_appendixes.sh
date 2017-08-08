function gen_appendixes(){
echo "
Appendixes
#################

" > $report_dir/appendixes.rst

for a in $report_dir/appendixes/*.rst
do
	echo ".. include:: appendixes/`basename $a`" >> $report_dir/appendixes.rst
done
}

