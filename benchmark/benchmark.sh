#!/bin/bash

cd "$(dirname "$0")/.."

echo "[1/3] Building project..."
mkdir -p build
cd build
cmake .. > /dev/null
make > /dev/null

if [ ! -f "raytracer" ]; then
    echo "Error: build failed, raytracer executable not found"
    exit 1
fi

echo "Build successful."
echo ""

RESOLUTIONS=(
    "640x480" # VGA 
    "1280x720" # HD
    "1920x1080" # Full HD
    "3840x2160" # 4k
)

MODES=(
    "cpu"
    "gpu"
    "gpu-optimized"
)

RUNS_PER_MODE=20

RAW_CSV="../benchmark/benchmark_raw.csv"
REPORT_MD="../benchmark/benchmark_results.md"
TIMING_FILE="last_render_time.txt"

echo "resolution,mode,run,time_ms" > "$RAW_CSV"

echo "[2/3] Running benchmarks..."
echo "  Resolutions: ${RESOLUTIONS[@]}"
echo "  Modes: ${MODES[@]}"
echo "  Runs per configuration: $RUNS_PER_MODE (plus 1 warmup)"
echo ""

total_configs=$((${#RESOLUTIONS[@]} * ${#MODES[@]}))
current_config=0

for res in "${RESOLUTIONS[@]}"; do
    width="${res%x*}"
    height="${res#*x}"
    for mode in "${MODES[@]}"; do
        current_config=$((current_config + 1))
        echo "  [$current_config/$total_configs] ${res} | ${mode}"
        echo "      warming up..."
        ./raytracer --width "$width" --height "$height" --mode "$mode" > /dev/null
        for run in $(seq 1 $RUNS_PER_MODE); do
            ./raytracer --width "$width" --height "$height" --mode "$mode" --benchmark > /dev/null
            time_ms=$(cat "$TIMING_FILE")
            echo "$res,$mode,$run,$time_ms" >> "$RAW_CSV"
            echo "      run $run/$RUNS_PER_MODE: ${time_ms} ms"
        done
    done
done

echo ""
echo "[3/3] Generating report..."
python3 ../benchmark/generate_report.py "$RAW_CSV" "$REPORT_MD"

echo "Benchmarking complete. Results written to $REPORT_MD"