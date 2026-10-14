#pragma once

struct vec3 {
    float x, y, z;

    __host__ __device__ vec3(float x, float y, float z) : x(x), y(y), z(z) {}

    __host__ __device__ vec3 operator+(const vec3& other) const {
        return vec3(x + other.x, y + other.y, z + other.z);
    }

    __host__ __device__ vec3 operator-(const vec3& other) const {
        return vec3(x - other.x, y - other.y, z - other.z);
    }

    __host__ __device__ vec3 operator*(float scalar) const {
        return vec3(x * scalar, y * scalar, z * scalar);
    }

    __host__ __device__ vec3& operator+=(const vec3& other) {
        x += other.x;
        y += other.y;
        z += other.z;
        return *this;
    }

    __host__ __device__ vec3& operator*=(float scalar) {
        x *= scalar;
        y *= scalar;
        z *= scalar;
        return *this;
    }

    // component-wise
    __host__ __device__ vec3 operator*(const vec3& other) const {
        return vec3(x * other.x, y * other.y, z * other.z);
    }

    __host__ __device__ float dot(const vec3& other) const {
        return x * other.x + y * other.y + z * other.z;
    }

    __host__ __device__ float length() const {
        return sqrtf(dot(*this));
    }

    __host__ __device__ vec3 normalize() const {
        float len = length();
        return vec3(x / len, y / len, z / len);
    }

    // reflect ray about the normal
    // derivation in docs/derivations.md
    __host__ __device__ vec3 reflect(const vec3& n) const {
        return *this - n * 2.0f * dot(n);
    }
};
