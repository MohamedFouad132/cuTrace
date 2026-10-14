#pragma once
#include "vec3.cuh"
#include "ray.cuh"
#include "sphere.cuh"
#include "intersect.cuh"

// brightness multiplier for points in shadow
inline constexpr float SHADOW_FACTOR = 0.5f;

// diffuse brightness
// dimmed by SHADOW_FACTOR if shadowed
__host__ __device__ inline float shade(const vec3& hit_point, const vec3& normal, sphere* spheres, int num_spheres, vec3 light_position) {
    vec3 light_direction = (light_position - hit_point).normalize();
    float brightness = fmaxf(0.0f, normal.dot(light_direction));

    ray shadow_ray(hit_point, light_direction);
    float shadow_t;
    int shadow_hit_index = hit_scene(shadow_ray, spheres, num_spheres, shadow_t);
    if (shadow_hit_index != -1 && shadow_t < (light_position - hit_point).length()) {
        brightness *= SHADOW_FACTOR;
    }
    return brightness;
}

// same as shade() but exits on the first blocker
__host__ __device__ inline float shade_optimized(const vec3& hit_point, const vec3& normal, sphere* spheres, int num_spheres, vec3 light_position) {
    vec3 light_direction = (light_position - hit_point).normalize();
    float brightness = fmaxf(0.0f, normal.dot(light_direction));

    ray shadow_ray(hit_point, light_direction);
    if (hit_anything(shadow_ray, spheres, num_spheres, (light_position - hit_point).length())) {
        brightness *= SHADOW_FACTOR;
    }
    return brightness;
}
