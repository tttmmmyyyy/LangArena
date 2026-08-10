#include <stdint.h>
#include <time.h>

// Wall-clock seconds from a monotonic source. The benchmark timing of every
// LangArena implementation is taken with a monotonic clock.
double langarena_monotonic_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

// Milliseconds since the Unix epoch, for the `start:` line the runner reads.
int64_t langarena_unix_millis(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (int64_t)ts.tv_sec * 1000 + (int64_t)(ts.tv_nsec / 1000000);
}
