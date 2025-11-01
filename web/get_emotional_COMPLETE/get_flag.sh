#!/bin/bash

curl -s http://10.1.133.55/ | grep -oE "flag{.*?}" --color=none
