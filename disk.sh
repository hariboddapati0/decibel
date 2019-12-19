#!/bin/sh

#####disk IO information from iostat command
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
    [ [$keys, $vals]|
    transpose[] |
    {key:.[0],value:.[1]} ] |
    from_entries ]'

    else
        zypper install sysstat &&  iostat -d |sed 1,2d|tr -s ' ' ','|grep -v ^$|jq -nR '[
    (input | split(",") )as $keys|
    (inputs | split(",") ) as $vals|
    [ [$keys, $vals]|
    transpose[] |
    {key:.[0],value:.[1]} ] |
    from_entries ]'


        fi
     fi
fi
