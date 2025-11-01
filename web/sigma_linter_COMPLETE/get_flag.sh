#!/bin/bash

cat pickle_result.yml | grep -oE "flag{.*?}" --color=none
