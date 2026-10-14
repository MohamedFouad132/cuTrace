import sys
import csv
import statistics
from collections import defaultdict

def main():

    if len(sys.argv) != 3:
        print("Usage: python generate_report.py <input_csv> <output_md>")
        sys.exit(1)

    
    input_csv = sys.argv[1]
    output_md = sys.argv[2]

    # groups the times by (resolution, mode)
    data = defaultdict(list)
    with open(input_csv, 'r') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            key = (row['resolution'], row['mode'])
            data[key].append(float(row['time_ms']))

    summary = {}
    for key, times in data.items():
        avg_time = statistics.mean(times)
        min_time = min(times)
        max_time = max(times)
        summary[key] = {
            "mean": avg_time,
            "stddev": statistics.stdev(times) if len(times) > 1 else 0.0,
            "min": min_time,
            "max": max_time
        }

    resolutions = list(dict.fromkeys(res for res, mode in summary.keys()))
    modes = list(dict.fromkeys(mode for res, mode in summary.keys()))

    with open(output_md, 'w') as mdfile:
        mdfile.write("# Benchmark Results\n\n")
        mdfile.write("| Resolution | Mode | Mean (ms) | StdDev (ms) | Min (ms) | Max (ms) | Speedup vs CPU |\n")
        mdfile.write("|---|---|---|---|---|---|---|\n")

        for res in resolutions:
            cpu_mean = summary.get((res, 'cpu'), {}).get('mean')
            for mode in modes:
                if (res, mode) not in summary:
                    continue
                s = summary[(res, mode)]
                speedup = f"{cpu_mean / s['mean']:.2f}x" if cpu_mean else "N/A"
                mdfile.write(f"| {res} | {mode} | {s['mean']:.4f} | {s['stddev']:.4f} | {s['min']:.4f} | {s['max']:.4f} | {speedup} |\n")

        # naive gpu vs optimized gpu at each resolution
        mdfile.write("\n## GPU vs Optimized GPU\n\n")
        mdfile.write("| Resolution | GPU (ms) | Optimized GPU (ms) | Time saved (ms) | Speedup |\n")
        mdfile.write("|---|---|---|---|---|\n")

        for res in resolutions:
            if (res, 'gpu') not in summary or (res, 'gpu-optimized') not in summary:
                continue
            gpu = summary[(res, 'gpu')]['mean']
            opt = summary[(res, 'gpu-optimized')]['mean']
            mdfile.write(f"| {res} | {gpu:.4f} | {opt:.4f} | {gpu - opt:.4f} | {gpu / opt:.2f}x |\n")

    print(f"Benchmark report generated and saved to {output_md}")


if __name__ == "__main__":
    main()