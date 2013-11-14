##### Function
usage()
{
    echo "usage: sh $0 file1 file2 ... [-o outputfile] | [-h]";
}

##### Variable declaration
INPUT=""
OUTPUT="testcase.py"

##### Main scripts
if [ $# -lt 1 ]
then
  usage
  exit 1
fi

BASEDIR=$(dirname $0)

while [ "$1" != "" ]; do
    case $1 in
        -o | --output )    	  shift
        								  OUTPUT=$1
                                ;;
        -h | --help )           usage
                                exit 1
                                ;;
        * )                     INPUT=$INPUT' '$1	  
                                ;;
    esac
    shift
done

ruby $BASEDIR/testpa/python/testpa.rb $INPUT -o $OUTPUT
ruby $BASEDIR/sigpa/python/sigpa.rb -I $BASEDIR/. -I $BASEDIR/linx_linux_headers signals.sig -o signals.py
