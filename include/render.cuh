#pragma once
#include "vec3.cuh"
#include "ray.cuh"
#include "sphere.cuh"

inline constexpr int SAMPLES_PER_PIXEL = 4;
inline constexpr int MAX_BOUNCES = 5;
inline constexpr int MAX_SPHERES = 4;

// LCG returns [0, 1)
__host__ __device__ inline float random_float(unsigned int& seed) {
    seed = seed * 1664525u + 1013904223u;
    return static_cast<float>(seed & 0x00FFFFFFu) * (1.0f / 16777216.0f);
}

// z is up
// camera looks along +y
struct render_params {
    vec3 camera_origin;
    float viewport_width;
    float viewport_height;
    float focal_length;
    sphere* spheres;
    int num_spheres;
    vec3 light_position;
    int width;
    int height;
};

__host__ __device__ vec3 trace_ray(ray r, sphere* spheres, int num_spheres, vec3 light_position);
__host__ __device__ vec3 trace_ray_optimized(ray r, sphere* spheres, int num_spheres, vec3 light_position);

__global__ void gpu_render(vec3* framebuffer, render_params p);

__global__ void gpu_render_optimized(vec3* framebuffer, render_params p);

void cpu_render(vec3* framebuffer, render_params p);
