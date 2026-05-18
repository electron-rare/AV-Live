#include "check.h"
#include "SpectrogramBuffer.h"
#include <cmath>
#include <vector>

using oscope::SpectrogramBuffer;

// writeIndex advances modulo width.
static void test_write_index_wraps() {
    SpectrogramBuffer buf(8, 4);
    std::vector<float> z(1024, 0.0f);
    for (int i = 0; i < 10; ++i) buf.pushColumn(z, z);
    CHECK(buf.writeIndex() == 2);                 // 10 % 8
    CHECK(static_cast<int>(buf.data().size()) == 8 * 4);
}

// High-frequency energy must land near the poles for both channels.
static void test_high_freq_maps_to_poles() {
    SpectrogramBuffer buf(4, 8);   // H=8 -> CH1 rows 4..7, CH2 rows 0..3
    std::vector<float> hi(1024, 0.0f);
    hi[1023] = 100.0f;             // energy at the top FFT bin
    buf.pushColumn(hi, hi);        // both channels: high-frequency content
    const std::vector<float>& d = buf.data();
    const int W = buf.width();
    CHECK(d[7 * W + 0] > d[4 * W + 0]);   // CH1: north pole > equator
    CHECK(d[0 * W + 0] > d[3 * W + 0]);   // CH2: south pole > equator
}

// A 2-row buffer (half == 1) must not divide by zero / emit NaN.
static void test_height_two_is_finite() {
    SpectrogramBuffer buf(4, 2);
    std::vector<float> m(1024, 0.0f);
    m[500] = 50.0f;
    buf.pushColumn(m, m);
    const std::vector<float>& d = buf.data();
    bool allFinite = true;
    for (float v : d)
        if (!std::isfinite(v)) allFinite = false;
    CHECK(allFinite);
}

int main() {
    test_write_index_wraps();
    test_high_freq_maps_to_poles();
    test_height_two_is_finite();
    REPORT();
}
