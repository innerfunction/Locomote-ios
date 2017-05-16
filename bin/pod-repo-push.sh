#!/bin/bash
# Publish the pod spec
if [ "$1" == "--private" ]; then
    echo "Publishing to innerfunction private pod spec repo"
    pod repo push if-podspecs Locomote.podspec --allow-warnings
else
    echo "Publishing to public pod spec repo"
    pod trunk push Locomote.podspec $@
fi

