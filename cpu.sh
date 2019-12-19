#!/bin/sh
#CPU load information
# top -bn1|awk -F":" '/load average:/{ printf " { \42%s\42:\42%s\42},\n","CPU Load", $NF}'|sed '1s/^/[\n/;$s/,$/\n]/'

#Full deatils of all the processes
 top -bn1|sed 1,6d|awk '{$1=$1};1'|tr -s ' ' ','|jq -nR '[
    (input | split(",") )as $keys|
    (inputs | split(",") ) as $vals|
    [ [$keys, $vals]|
    transpose[] |
    {key:.[0],value:.[1]} ] |
    from_entries ]'
