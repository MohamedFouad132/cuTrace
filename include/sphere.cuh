#pragma once
#include "vec3.cuh"

struct sphere {
    vec3 center;
    float radius;
    vec3 color;
    float reflectivity; // 0 = diffuse, 1 = mirror

    // needed for shared memory arrays
    __host__ __device__ sphere() : center(0,0,0), radius(0), color(0,0,0), reflectivity(0) {}

    __host__ __device__ sphere(const vec3& center, float radius, const vec3& color, float reflectivity) : center(center), radius(radius), color(color), reflectivity(reflectivity) {}
};
