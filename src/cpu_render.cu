#include <thread>
#include <vector>
#include <atomic>
#include "render.cuh"

static void render_row(int y, vec3* framebuffer, const render_params& p) {
    for (int x = 0; x < p.width; x++) {
        int pixel_index = y * p.width + x;
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

            pixel_color += trace_ray(r, p.spheres, p.num_spheres, p.light_position);
        }

        pixel_color *= 1.0f / SAMPLES_PER_PIXEL;
        framebuffer[pixel_index] = pixel_color;
    }
}

// threads grab rows off a shared counter until none are left
void cpu_render(vec3* framebuffer, render_params p) {
    std::atomic<int> next_row{0};

    unsigned int num_threads = std::thread::hardware_concurrency();
    if (num_threads == 0) num_threads = 4;

    auto worker = [&]() {
        int y;
        while ((y = next_row.fetch_add(1)) < p.height) {
            render_row(y, framebuffer, p);
        }
    };

    std::vector<std::thread> threads;
    threads.reserve(num_threads);

    for (unsigned int t = 0; t < num_threads; t++) {
        threads.emplace_back(worker);
    }

    for (auto& t: threads)
        t.join();
}
