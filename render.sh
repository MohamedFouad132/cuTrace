#!/bin/bash

# builds if needed and forwards args to raytracer

cd "$(dirname "$0")"

if [ ! -f "./build/raytracer" ]; then
    echo "Building raytracer..."
    mkdir -p build
    cd build
    cmake .. > /dev/null
    make > /dev/null
    cd ..
fi

cd build
./raytracer "$@"

# PPM -> PNG if ImageMagick is found
if [ -f "output.ppm" ] && command -v convert > /dev/null; then
    convert output.ppm output.png
else
    echo "Note: ImageMagick not found or output.ppm missing"
fi