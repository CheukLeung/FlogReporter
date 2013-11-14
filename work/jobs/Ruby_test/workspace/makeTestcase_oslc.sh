#!/bin/bash

##### Function
usage()
{
    echo "usage: sh $0 file1 file2 ... [-o outputfile] | [-h]";
}

##### Variable declaration
OUTPUT="testcase.py"
##### Main scripts

BASEDIR=$(dirname $0)

while read line           
do           
    #echo "$line \ n"           
    #echo `expr match "$line" 'file_name_prefix.*='` 
    i=`expr match "$line" 'file_name_prefix.*='`
    if [ "$i" != "0" ]; then
        j=`expr $i + 1`
        length=${#line}
        INPUT=`echo $line| cut -c $j-$length`"*"
        echo $INPUT
    fi
done <consumer.ini   

while [ "$1" != "" ]; do
    case $1 in
        -o | --output )    	  shift
        								  OUTPUT=$1
                                ;;
        -h | --help )           usage
                                exit 1
                                ;;
    esac
    shift
done

python consumer.py
ruby $BASEDIR/testpa/python/testpa.rb $INPUT -o $OUTPUT
ruby $BASEDIR/sigpa/python/sigpa.rb -I $BASEDIR/. -I $BASEDIR/linx_linux_headers signals.sig -o signals.py
