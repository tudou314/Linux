#!/bin/bash
for IP in 172.16.16.{1..254}
do
        (
        ping $IP -w3 -c2  &>/dev/null
        if [ $? -eq 0 ]
        then
                echo "$IP is alive"
        fi
        ) &
done

wait
