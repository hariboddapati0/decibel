#!/bin/sh

#check if Javaqruery tool is installed or not to print in prity format

if [ -f /usr/bin/jq ]
  then
    echo "JQ already installed......"

else
    if [ "$(. /etc/os-release; echo $NAME)" = "Ubuntu" ]
      	  then
           apt-get install updates && apt-get install jq
        elif [ "$(. /etc/os-release; echo $NAME)" = "Red Hat Enterprise Linux" ]
	   then
        	yum update -y && yum install -y jq >/dev/null
        else
               zypper refresh && zypper install -y jq >/dev/null
     fi
fi
echo "..........................................................................................................................."
#File system information in JSON formate
echo "[File System information ....]"
df -h  | tr -s ' ' ',' | jq -nR '[
( input | split(",") ) as $keys |
( inputs | split(",") ) as $vals |
[ [$keys, $vals] |
transpose[] |
{key:.[0],value:.[1]} ] |
from_entries ]'

echo "..........................................................................................................................."

#CPU load information
echo "[CPU Load information.....]"
 top -bn1|awk -F":" '/load average:/{ printf " { \42%s\42:\42%s\42},\n","CPU Load", $NF}'|sed '1s/^/[\n/;$s/,$/\n]/'

#Full deatils of all the processes
 top -bn1|sed 1,6d|awk '{$1=$1};1'|tr -s ' ' ','|jq -nR '[
    (input | split(",") )as $keys|
    (inputs | split(",") ) as $vals|
    [ [$keys, $vals]|
    transpose[] |
    {key:.[0],value:.[1]} ] |
    from_entries ]'
echo "..........................................................................................................................."


#####disk IO information from iostat command
echo " [ Disk IO information ........]"
 if [ -f /usr/bin/iostat ]
   then
    iostat -d |sed 1,2d|tr -s ' ' ','|grep -v ^$|jq -nR '[
    (input | split(",") )as $keys|
    (inputs | split(",") ) as $vals|
    [ [$keys, $vals]|
    transpose[] |
    {key:.[0],value:.[1]} ] |
    from_entries ]'
 else
     if [ "$(. /etc/os-release; echo $NAME)" = "Ubuntu" ]
      then
       apt-get install updates && apt-get install sysstat
       iostat -d |sed 1,2d|tr -s ' ' ','|grep -v ^$|jq -nR '[
    (input | split(",") )as $keys|
    (inputs | split(",") ) as $vals|
    [ [$keys, $vals]|
    transpose[] |
    {key:.[0],value:.[1]} ] |
    from_entries ]'
     else
         if [ "$(. /etc/os-release; echo $NAME)" = "Red Hat Enterprise Linux" ]
	   then
        	yum update -y && yum install -y sysstat
                iostat -d |sed 1,2d|tr -s ' ' ','|grep -v ^$|jq -nR '[
    (input | split(",") )as $keys|
    (inputs | split(",") ) as $vals|

