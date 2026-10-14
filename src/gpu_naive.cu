#include <curand_kernel.h>
#include "intersect.cuh"
#include "shading.cuh"
#include "render.cuh"

__host__ __device__ vec3 trace_ray(ray r, sphere* spheres, int num_spheres, vec3 light_position) {
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
            float brightness = shade(hit_point, normal, spheres, num_spheres, light_position);

            final_color += floor_color * brightness * color_multiplier;
            break;
        }

        // sphere hit
        vec3 hit_point = current_ray.at(sphere_t);

        vec3 normal = (hit_point - spheres[sphere_index].center).normalize();
        float brightness = shade(hit_point, normal, spheres, num_spheres, light_position);

        vec3 local_color = spheres[sphere_index].color * brightness;
        final_color += local_color * (1-spheres[sphere_index].reflectivity) * color_multiplier;

        if (spheres[sphere_index].reflectivity <= 0.0f) break;

        // bounce
        color_multiplier *= spheres[sphere_index].reflectivity;
        vec3 reflected_direction = current_ray.direction.reflect(normal);
        current_ray = ray(hit_point, reflected_direction);
    }

    return final_color;
}

// one thread per pixel
__global__ void gpu_render(vec3* framebuffer, render_params p) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int pixel_index = y * p.width + x;

    if (x >= p.width || y >= p.height) return;

    curandState rand_state;
    curand_init(pixel_index, 0, 0, &rand_state);

    vec3 pixel_color(0.0f, 0.0f, 0.0f);

    // jittered samples for anti aliasing
    for (int s = 0; s < SAMPLES_PER_PIXEL; s++) {
        float jitter_x = curand_uniform(&rand_state) - 0.5f;
        float jitter_y = curand_uniform(&rand_state) - 0.5f;

        float u = (static_cast<float>(x) + jitter_x) / (p.width - 1);
        float v = (static_cast<float>(y) + jitter_y) / (p.height - 1);

        float viewport_x = (u-0.5f) * p.viewport_width;
        float viewport_z = (0.5f-v) * p.viewport_height + p.camera_origin.z;

        vec3 viewport_point(viewport_x, p.camera_origin.y + p.focal_length, viewport_z);
        vec3 ray_direction = (viewport_point - p.camera_origin).normalize();
        ray r(p.camera_origin, ray_direction);

        pixel_color += trace_ray(r, p.spheres, p.num_spheres, p.light_position);
    }

    pixel_color *= 1.0f / SAMPLES_PER_PIXEL;
    framebuffer[pixel_index] = pixel_color;
}
