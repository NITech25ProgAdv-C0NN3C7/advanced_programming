#!/bin/bash

image="$1"
templates="$2"
rotation="$3"
threshold="$4"
option="$5"

x=0
for template in $templates; do
    if [ "$x" = 0 ]; then
        ./matching "$image" "$template" "$rotation" "$threshold" "c$option"
        x=1
    else
        ./matching "$image" "$template" "$rotation" "$threshold" "$option"
    fi
done
