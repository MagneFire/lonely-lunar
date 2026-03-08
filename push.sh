#!/bin/bash

# Only download and convert if the file does not exist
if [ ! -f "lunar-libration-phase-img.gif" ]; then
    echo "Processing image..."
    wget -q https://upload.wikimedia.org/wikipedia/commons/8/86/Lunar_libration_with_phase_Oct_2007.gif
    # Strip header
    convert Lunar_libration_with_phase_Oct_2007.gif -coalesce -repage 0x0 -crop 610x610+15+15 +repage lunar-libration-phase-img.gif
    rm Lunar_libration_with_phase_Oct_2007.gif
fi

# Pushing files
if [ "$1" == "adb" ]; then
    echo "Pushing files using ADB mode..."
    adb push 099* /usr/share/asteroid-launcher/watchfaces/
    adb push lunar-libration-phase-img.gif /usr/share/asteroid-launcher/watchfaces-img/
else
    echo "Pushing files using Developer mode..."
    scp 099* root@192.168.2.15:/usr/share/asteroid-launcher/watchfaces/
    scp lunar-libration-phase-img.gif root@192.168.2.15:/usr/share/asteroid-launcher/watchfaces-img/
fi