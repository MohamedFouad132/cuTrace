#pragma once
#include "vec3.cuh"
#include "ray.cuh"
#include "sphere.cuh"

inline constexpr int SAMPLES_PER_PIXEL = 4;
inline constexpr int MAX_BOUNCES = 5;
inline constexpr int MAX_SPHERES = 4;

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
