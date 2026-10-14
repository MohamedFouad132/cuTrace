# cuTrace (CUDA / C++)

A GPU-accelerated ray tracer built from scratch. Includes core rendering logic (reflections, shadows, anti-aliasing), Nsight-guided optimizations, CPU/GPU benchmarking and CMake for build automation.

## Project Features

- Ray tracer with reflections, shadows and anti-aliasing
- Three render paths: multithreaded CPU, GPU and optimized GPU
- Configurable resolution and render path from the command line
- Automated benchmarks with warmup runs and repeated trials
- Math derivations in `docs/derivations.md`

## Rendered Output (NVIDIA RTX 5080, 1920x1080)

![cuTrace render](docs/Tracing.png)

## Project Structure

```
cuTrace/
├── CMakeLists.txt
├── render.sh
├── .gitignore
├── .gitattributes
├── LICENSE
├── README.md
├── src/
│   ├── main.cu
│   ├── gpu_naive.cu
│   ├── gpu_optimized.cu
│   └── cpu_render.cu
├── include/
│   ├── vec3.cuh
│   ├── ray.cuh
│   ├── sphere.cuh
│   ├── intersect.cuh
│   ├── shading.cuh
│   └── render.cuh
├── benchmark/
│   ├── benchmark.sh
│   ├── generate_report.py
│   └── benchmark_results.md
└── docs/
    ├── derivations.md
    └── Tracing.png
```

## Prerequisites

- NVIDIA GPU
- CUDA Toolkit 12.x or newer
- C++17-compatible compiler (usually installed automatically with the CUDA Toolkit)
- Python 3
- CMake 3.18+
- Bash
- Git
- ImageMagick (converts PPM to PNG)

## Setup

**Option A: Manually Build + Execute**

```bash
git clone https://github.com/MohamedFouad132/cuTrace.git
cd cuTrace
mkdir build && cd build
cmake ..
make
./raytracer [Flags]
convert output.ppm output.png
```

**Option B: Use `render.sh` to Build + Execute**

```bash
git clone https://github.com/MohamedFouad132/cuTrace.git
cd cuTrace
chmod +x render.sh
./render.sh [Flags]
```

**Flags**
```
--width <n>     Image width in pixels (default: 1920)
--height <n>    Image height in pixels (default: 1080)
--mode <mode>   Render mode: cpu, gpu, gpu-optimized (default: gpu)
--help, -h      Show this message
--benchmark     Write precise render time to last_render_time.txt (default: off)
```

Open `build/output.png` to view the result.

## Benchmarks

To benchmark across all modes and resolutions:

```bash
cd benchmark
chmod +x benchmark.sh
./benchmark.sh
```

## Results

- **Hardware:** NVIDIA RTX 5080 and AMD Ryzen 7 9700X (8 cores with 16 threads)
- **Method:** 20 runs per mode displayed as mean ± standard deviation. GPU times are kernel-only.

### Render Time (ms)

| Resolution | CPU | GPU | Optimized GPU |
|:---|---:|---:|---:|
| 640 × 480 | 3.57 ± 0.11 | 0.0329 ± 0.0018 | **0.0318** ± 0.0015 |
| 1280 × 720 | 10.04 ± 0.17 | 0.0719 ± 0.0006 | **0.0675** ± 0.0008 |
| 1920 × 1080 | 22.52 ± 0.48 | 0.1456 ± 0.0005 | **0.1374** ± 0.0007 |
| 3840 × 2160 | 87.62 ± 0.88 | 0.5436 ± 0.0017 | **0.5113** ± 0.0017 |

### Speedup

| Resolution | GPU vs CPU | Optimized GPU vs CPU | Optimized GPU vs GPU |
|:---|---:|---:|---:|
| 640 × 480 | 108.6× | **112.5×** | 1.04× |
| 1280 × 720 | 139.6× | **148.7×** | 1.07× |
| 1920 × 1080 | 154.7× | **163.9×** | 1.06× |
| 3840 × 2160 | 161.2× | **171.4×** | 1.06× |

## Optimizations

**Problem:** Theoretical occupancy was capped at 75% due to register pressure (68 registers/thread), allowing only 3 resident blocks/SM vs a 4-block ceiling.

**Optimization:** Replaced `curandState` with a lightweight LCG. Register pressure dropped enough to reach 100% theoretical occupancy. Achieved occupancy increased from ~70% to ~90%.

**Problem:** Shadow rays searched for the closest blocker when they only need a yes or no.

**Optimization:** Switched to `hit_anything`, which returns on the first blocker.

**Problem:** The hit sphere was read from global memory up to 5 times per bounce since the compiler couldn't rule out pointer aliasing.

**Optimization:** Copied the hit sphere into a local variable so the compiler could keep it in registers.

**Problem:** Every ray read every sphere from global memory with uncoalesced access (4 of 32 bytes per sector used).

**Optimization:** Loaded the sphere array into shared memory once per block.

**Investigated and ruled out:** Warp divergence was not a bottleneck as Nsight showed 99.47% branch efficiency despite variable bounce depth.

## Key Findings

- The GPU was **141x** faster than the CPU on average
- The optimized GPU was **149x** faster than the CPU on average
- The biggest speedup was **171x** at 4K with the optimized GPU
- The optimized GPU was **1.06x** faster than the regular GPU on average

## Derivations

Full derivations for the intersection and reflection formulas: [docs/derivations.md](docs/derivations.md)

## License

MIT License: [LICENSE](LICENSE)