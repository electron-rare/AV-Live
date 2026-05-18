#include "check.h"
#include "SpectrogramBuffer.h"
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

int main() {
    test_write_index_wraps();
    test_high_freq_maps_to_poles();
    REPORT();
}
