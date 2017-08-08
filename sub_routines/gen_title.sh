function gen_title(){
echo ".. image:: `basename $pics_dir`/percona.jpg
   :align: center

RDBA System Analysis
####################

:author: $author_name
:revision: 1.0-1
:date: `date +%F`
:Customer: $customer_name

.. raw:: pdf

  PageBreak

.. header:: 

   .. class::  headertab

   +-----------------------------+---------------------+-----------------------+
   | .. class:: left             | .. class:: centered | .. class:: right      |
   |                             |                     |                       |
   | RDBA system analysis        | Page ###Page###     | $customer_name     |
   +-----------------------------+---------------------+-----------------------+

.. footer::

    .. image:: `basename $pics_dir`/percona_logo.png 
       :align: right

.. contents:: 
   :backlinks: entry

.. raw:: pdf

  PageBreak

.. role:: red

.. role:: orange

.. role:: green
"> $report_dir/title_page.rst

}
