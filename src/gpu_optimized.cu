#include "intersect.cuh"
#include "shading.cuh"
#include "render.cuh"

// LCG returns [0, 1)
__device__ float random_float(unsigned int& seed) {
    seed = seed * 1664525u + 1013904223u;
    return static_cast<float>(seed & 0x00FFFFFFu) * (1.0f / 16777216.0f);
}

// same as trace_ray but early-exit shadows and cached sphere
__host__ __device__ vec3 trace_ray_optimized(ray r, sphere* spheres, int num_spheres, vec3 light_position) {
    vec3 final_color(0.0f, 0.0f, 0.0f);
    // shrinks with each reflection
    vec3 color_multiplier(1.0f, 1.0f, 1.0f);

    ray current_ray = r;

    for (int bounce = 0; bounce < MAX_BOUNCES; bounce++) {
        float sphere_t;
        int sphere_index = hit_scene(current_ray, spheres, num_spheres, sphere_t);

        // floor at z = 0
        float floor_t;
        bool hit_floor = hit_plane(current_ray, 0.0f, floor_t);

        bool floor_is_closer = hit_floor && (sphere_index == -1 || floor_t < sphere_t);

        // sky: blend white and light blue
        if (sphere_index == -1 && !hit_floor) {
            float sky_t = 0.5f * (current_ray.direction.z + 1.0f);
            vec3 sky_color = vec3(1.0f, 1.0f, 1.0f) * (1.0f - sky_t) + vec3(0.5f, 0.7f, 1.0f) * sky_t;
            final_color += sky_color * color_multiplier;
            break;
        }

        if (floor_is_closer) {
            vec3 hit_point = current_ray.at(floor_t);
            // checkerboard
            int checker = (static_cast<int>(floorf(hit_point.x)) + static_cast<int>(floorf(hit_point.y))) & 1;
            vec3 floor_color = (checker == 0) ? vec3(0.9f,0.9f,0.9f) : vec3(0.1f,0.1f,0.1f);

            vec3 normal(0.0f, 0.0f, 1.0f);
            float brightness = shade_optimized(hit_point, normal, spheres, num_spheres, light_position);

            final_color += floor_color * brightness * color_multiplier;
            break;
        }

        // sphere hit
        vec3 hit_point = current_ray.at(sphere_t);

        sphere hit_sphere_data = spheres[sphere_index];

        vec3 normal = (hit_point - hit_sphere_data.center).normalize();
        float brightness = shade_optimized(hit_point, normal, spheres, num_spheres, light_position);

        vec3 local_color = hit_sphere_data.color * brightness;
        final_color += local_color * (1-hit_sphere_data.reflectivity) * color_multiplier;

        if (hit_sphere_data.reflectivity <= 0.0f) break;

        // bounce
        color_multiplier *= hit_sphere_data.reflectivity;
        vec3 reflected_direction = current_ray.direction.reflect(normal);
        current_ray = ray(hit_point, reflected_direction);
    }

    return final_color;
}

// LCG instead of curand and spheres in shared memory
__global__ void gpu_render_optimized(vec3* framebuffer, render_params p) {
    __shared__ sphere shared_spheres[MAX_SPHERES];
    int local_index = threadIdx.y * blockDim.x + threadIdx.x;
    if (local_index < p.num_spheres) {
        shared_spheres[local_index] = p.spheres[local_index];
    }
    __syncthreads();

    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int pixel_index = y * p.width + x;

    if (x >= p.width || y >= p.height) return;

    unsigned int seed = pixel_index * 3242174893u + 123456789u;

    vec3 pixel_color(0.0f, 0.0f, 0.0f);

    // jittered samples for anti aliasing
    for (int s = 0; s < SAMPLES_PER_PIXEL; s++) {
        float jitter_x = random_float(seed) - 0.5f;
        float jitter_y = random_float(seed) - 0.5f;

        float u = (static_cast<float>(x) + jitter_x) / (p.width - 1);
        float v = (static_cast<float>(y) + jitter_y) / (p.height - 1);

        float viewport_x = (u-0.5f) * p.viewport_width;
        float viewport_z = (0.5f-v) * p.viewport_height + p.camera_origin.z;

        vec3 viewport_point(viewport_x, p.camera_origin.y + p.focal_length, viewport_z);
        vec3 ray_direction = (viewport_point - p.camera_origin).normalize();
        ray r(p.camera_origin, ray_direction);

        pixel_color += trace_ray_optimized(r, shared_spheres, p.num_spheres, p.light_position);
    }

    pixel_color *= 1.0f / SAMPLES_PER_PIXEL;
    framebuffer[pixel_index] = pixel_color;
}
