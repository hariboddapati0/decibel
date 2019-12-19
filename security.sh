#!/bin/sh


 if [ "$(. /etc/os-release; echo $NAME)" = "Ubuntu" ]
   then
   #Security Patch update check for ubuntu
	cat /var/lib/update-notifier/updates-available|sed 1d|grep -v '^$'|tr -s ' ' ','|jq -nR '[
	(input | split("\t\n") )as $keys|
	(inputs | split("\t\n") ) as $vals|
	[ [$keys, $vals]|
	transpose[] |
	{key:.[0],value:.[1]} ] |
	from_entries ]'
 elif [ "$(. /etc/os-release; echo $NAME)" = "Red Hat Enterprise Linux" ]
     then
   	#security pkg update check
 	yum updateinfo summary --security|sed 1d|awk '{$1=$1};1'|jq -nR '[
	(input | split("\t\n") )as $keys|
	(inputs | split("\t\n") ) as $vals|
	[ [$keys, $vals]|
	transpose[] |
	{key:.[0],value:.[1]} ] |
	from_entries ]'
 else
     echo " "
 fi
