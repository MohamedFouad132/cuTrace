// derivations in docs/derivations.md

#pragma once
#include <cfloat>
#include "vec3.cuh"
#include "ray.cuh"
#include "sphere.cuh"

// t values below this are self intersection from floating point error
inline constexpr float HIT_EPSILON = 0.001f;

__host__ __device__ inline bool hit_sphere(const ray& r, const sphere& s, float& t) {
    vec3 oc = r.origin - s.center;
    // at^2 + bt + c = 0
    float a = r.direction.dot(r.direction);
    float b = 2.0f * oc.dot(r.direction);
    float c = oc.dot(oc) - s.radius * s.radius;

    float discriminant = b * b - 4 * a * c;
    if (discriminant < 0)
        return false;

    float t0 = (-b - sqrtf(discriminant)) / (2.0f * a);
    float t1 = (-b + sqrtf(discriminant)) / (2.0f * a);

    // Pick the nearest hit
    if (t0 > HIT_EPSILON) {
        t = t0;
        return true;
    }

    if (t1 > HIT_EPSILON) {
        t = t1;
        return true;
    }

    return false;
}

// Checks if the ray hits the floor plane
__host__ __device__ inline bool hit_plane(const ray& r, float plane_z, float& t) {
    // skip near parallel rays
    if (fabsf(r.direction.z) < 0.0001f) return false;
    t = (plane_z - r.origin.z) / r.direction.z;
    return t > HIT_EPSILON;
}

// returns index of closest sphere hit (-1 if none)
__host__ __device__ inline int hit_scene(const ray& r, const sphere* spheres, int num_spheres, float& closest_t) {
    closest_t = FLT_MAX;
    int index = -1;
    for (int i = 0; i < num_spheres; i++) {
        float t;
        if (hit_sphere(r, spheres[i], t) && t < closest_t) {
            closest_t = t;
            index = i;
        }
    }

    return index;
}

// true for any hit before reaching light source.
// used for early exit for shadow rays
__host__ __device__ inline bool hit_anything(const ray& r, const sphere* spheres, int num_spheres, float max_t) {
    for (int i = 0; i < num_spheres; i++) {
        float t;
        if (hit_sphere(r, spheres[i], t) && t < max_t) {
            return true;
        }
    }

    return false;
}
