#!/bin/sh

#meminfo from file or from free -m command
 if [ -f /proc/meminfo ]
   then
	cat /proc/meminfo|egrep 'MemTotal|MemFree|MemAvailable|Cached|SwapTotal|SwapFree|Slab'|tr -d ":"|jq -nR '[
	(input | split("\t\n") )as $keys|
	(inputs | split("\t\n") ) as $vals|
	[ [$keys, $vals]|
	transpose[] |
	{key:.[0],value:.[1]} ] |
	from_entries ]'
  else
   free -m |awk '{print $0}'|tr -s ' ' ','|jq -nR '[
	( input | split(",") ) as $keys |
	( inputs | split(",") ) as $vals |
	[ [$keys, $vals] |
	transpose[] |
	{key:.[0],value:.[1]} ] |
	from_entries ]'
fi
