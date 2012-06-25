#! /bin/sh

echo "Starting test..."

#perl warrick.pl -D MAKEFILE -o MAKEFILE_LOGFILE.log -xc -nr -dr 2007-08-02 -k -T -nv http://www.cs.odu.edu/

##use this one eventually. Other being use for the time being to giev a more visual representation of the recovery
perl warrick.pl -D MAKEFILE -o MAKEFILE_LOGFILE.log -xc -nr -dr 2007-08-02 -T -nv http://www.cs.odu.edu/

echo "TESTING DOWNLOAD COMPLETE..."
echo "-----------------------------"

chmod -R 755 MAKEFILE*

##detect differences between the master and test log files
c4=`diff MAKEFILE_recoveryLog.out ./TEST_FILES/MAKEFILE_recoveryLog.out | wc -l`

if [[ c4 -eq 0 ]]; then
	echo "No differences in log files. Test successful!"
	#exit
fi


##count the 200s. 
#c1=`cat ./MAKEFILE/TESTHEADERS.out | grep "200 OK" | wc -l`
#c2=`cat ./TEST_FILES/TESTHEADERS.out | grep "200 OK" | wc -l`

##count the number of successful downloaded resources
c1=`cat MAKEFILE_recoveryLog.out | grep ^http | wc -l`
c2=`cat ./TEST_FILES/MAKEFILE_recoveryLog.out | grep ^http | wc -l`


if [[ c1 -eq c2 ]]; then
	echo "Downloaded ${c1} resources, same as the test run. Test success!"
	#exit
fi

if [[ c1 -gt c2 ]]; then
	echo "Downloaded ${c1} resources, which is greater than the ${c2} from the testfile. We've found a new memento. Test success!"
	#exit
fi

##list of all successfully downloaded resources (originals)
recoArray=(`cat MAKEFILE/TESTHEADERS.out | grep rel=\"original | cut -d '<' -f3 | cut -d '>' -f1 | uniq`)
testArray=(`cat old_make/MAKEFILE/TESTHEADERS.out | grep rel=\"original | cut -d '<' -f3 | cut -d '>' -f1 | uniq`)

elements2=${#recoArray[@]} # total number of rows in an array
elements=${#testArray[@]}

echo "${elements} vs ${elements2}"

for((i=0;i<$elements;i++)); do
	found=0
	for((j=0;j<$elements2;j++)); do
		if [[ "${recoArray[${j}]}" == "${testArray[${i}]}" ]]; then
			found=1;
		fi
	done

	if [[ $found -eq 0 ]]; then
		echo "Did not recover resource ${testArray[${i}]}"
	fi
done

##remove the test files
#rm -r -f MAKEFILE*
