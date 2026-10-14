#include <algorithm>
#include <charconv>
#include <chrono>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <string>
#include <vector>
#include "render.cuh"

// read by benchmark.sh
static void write_timing(double ms) {
    std::ofstream timing_file("last_render_time.txt");
    timing_file << std::fixed << std::setprecision(4) << ms;
}

// whole string must be a positive integer
static bool parse_positive_int(const char* text, int& out) {
    const char* end = text + std::strlen(text);
    auto [ptr, ec] = std::from_chars(text, end, out);
    return ec == std::errc() && ptr == end && out > 0;
}

int main(int argc, char** argv) {
    int width = 1920;
    int height = 1080;
    std::string mode = "gpu";
    bool benchmark_mode = false;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];

        if (arg == "--help" || arg == "-h") {
            std::cout << "Usage: raytracer [options]\n"
                         "  --width <n>     Image width in pixels (default: 1920)\n"
                         "  --height <n>    Image height in pixels (default: 1080)\n"
                         "  --mode <mode>   Render mode: cpu, gpu, gpu-optimized (default: gpu)\n"
                         "  --help, -h      Show this message\n"
                         "  --benchmark     Write precise render time to last_render_time.txt (default: off)\n";
            return 0;
        } else if (arg == "--width") {
            if (i + 1 >= argc) {
                std::cerr << "Error: --width requires a value\n";
                return 1;
            }

            if (!parse_positive_int(argv[++i], width)) {
                std::cerr << "Error: Width must be a positive integer\n";
                return 1;
            }
        } else if (arg == "--height") {
            if (i + 1 >= argc) {
                std::cerr << "Error: --height requires a value\n";
                return 1;
            }

            if (!parse_positive_int(argv[++i], height)) {
                std::cerr << "Error: Height must be a positive integer\n";
                return 1;
            }
        } else if (arg == "--mode") {
            if (i + 1 >= argc) {
                std::cerr << "Error: --mode requires a value\n";
                return 1;
            }

            mode = argv[++i];
            if (mode != "cpu" && mode != "gpu" && mode != "gpu-optimized") {
                std::cerr << "Error: Invalid mode. Use 'cpu', 'gpu', or 'gpu-optimized'\n";
                return 1;
            }
        } else if (arg == "--benchmark") {
            benchmark_mode = true;
        } else {
            std::cerr << "Error: Unknown flag '" << arg << "'\n"
                      << "Use --help or -h for usage information.\n";
            return 1;
        }
    }

    constexpr float VIEWPORT_HEIGHT = 2.0f;
    const float VIEWPORT_WIDTH = VIEWPORT_HEIGHT * (static_cast<float>(width) / height);
    constexpr float FOCAL_LENGTH = 1.5f;

    // scene
    sphere h_spheres[] = {
        sphere(vec3(-4.5f, 5.0f, 0.7f), 0.6f, vec3(0.0f, 0.0f, 1.0f), 0.0f),
        sphere(vec3(-1.9f, 5.0f, 1.1f), 1.0f, vec3(1.0f, 0.0f, 0.0f), 0.0f),
        sphere(vec3( 1.1f, 5.0f, 1.1f), 1.0f, vec3(0.9f, 0.9f, 0.9f), 0.82f),
        sphere(vec3( 3.9f, 5.0f, 0.9f), 0.8f, vec3(1.0f, 1.0f, 0.0f), 0.0f)
    };
    constexpr int num_spheres = std::size(h_spheres);
    static_assert(num_spheres <= MAX_SPHERES, "raise MAX_SPHERES in render.cuh");

    vec3 light_position(-1.0f, 3.0f, 10.0f);
    vec3 camera_origin(0.0f, -0.5f, 2.0f);

    render_params params{camera_origin, VIEWPORT_WIDTH, VIEWPORT_HEIGHT, FOCAL_LENGTH, h_spheres, num_spheres, light_position, width, height};

    int num_pixels = width * height;
    size_t framebuffer_size = num_pixels * sizeof(vec3);
    std::vector<vec3> h_framebuffer(num_pixels, vec3(0.0f, 0.0f, 0.0f));

    if (mode == "cpu") {
        auto start = std::chrono::steady_clock::now();
        cpu_render(h_framebuffer.data(), params);

        if (benchmark_mode) {
            std::chrono::duration<double, std::milli> elapsed = std::chrono::steady_clock::now() - start;
            write_timing(elapsed.count());
        }
    } else {
        sphere* d_spheres;
        cudaMalloc(&d_spheres, num_spheres * sizeof(sphere));
        cudaMemcpy(d_spheres, h_spheres, num_spheres * sizeof(sphere), cudaMemcpyHostToDevice);
        params.spheres = d_spheres;
        vec3 *d_framebuffer;
        cudaMalloc(&d_framebuffer, framebuffer_size);

        // 16x16 blocks
        // ceiling division grid
        dim3 blockDim(16, 16);
        dim3 gridDim((width + blockDim.x - 1) / blockDim.x, (height + blockDim.y - 1) / blockDim.y);

        cudaEvent_t start, stop;

        if (benchmark_mode) {
            cudaEventCreate(&start);
            cudaEventCreate(&stop);
            cudaEventRecord(start);
        }

        if (mode == "gpu-optimized") {
            gpu_render_optimized<<<gridDim, blockDim>>>(d_framebuffer, params);
        } else {
            gpu_render<<<gridDim, blockDim>>>(d_framebuffer, params);
        }

        if (benchmark_mode) {
            cudaEventRecord(stop);
            cudaEventSynchronize(stop);
            float milliseconds;
            cudaEventElapsedTime(&milliseconds, start, stop);
            write_timing(milliseconds);
            cudaEventDestroy(start);
            cudaEventDestroy(stop);
        }

        cudaDeviceSynchronize();
        cudaMemcpy(h_framebuffer.data(), d_framebuffer, framebuffer_size, cudaMemcpyDeviceToHost);
        cudaFree(d_framebuffer);
        cudaFree(d_spheres);
    }

    // write PPM
    std::ofstream image("output.ppm");
    if (!image) {
        std::cerr << "Error: could not open output.ppm for writing\n";
        return 1;
    }
    image << "P3\n" << width << " " << height << "\n255\n";

    for (const vec3& color : h_framebuffer) {
        int r = static_cast<int>(std::clamp(color.x, 0.0f, 1.0f) * 255);
        int g = static_cast<int>(std::clamp(color.y, 0.0f, 1.0f) * 255);
        int b = static_cast<int>(std::clamp(color.z, 0.0f, 1.0f) * 255);
        image << r << ' ' << g << ' ' << b << '\n';
    }

    return 0;
}
