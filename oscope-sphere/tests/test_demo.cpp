#include "check.h"
#include "DemoSignal.h"
#include <cmath>
#include <vector>

using oscope::DemoSignal;

// Output has the requested length, stays in [-1,1], and the two
// channels differ.
static void test_shape_and_bounds() {
    DemoSignal demo(48000.0f);
    std::vector<float> a, b;
    demo.next(a, b, 256);
    CHECK(a.size() == 256);
    CHECK(b.size() == 256);
    bool inRange = true, differ = false;
    for (std::size_t i = 0; i < a.size(); ++i) {
        if (std::fabs(a[i]) > 1.0f || std::fabs(b[i]) > 1.0f) inRange = false;
        if (std::fabs(a[i] - b[i]) > 1e-4f) differ = true;
    }
    CHECK(inRange);
    CHECK(differ);
}

// Splitting next() into two calls must equal one combined call:
// proves the generator is deterministic AND phase-continuous across
// call boundaries (a restart or glitch would break the identity).
static void test_phase_continuity() {
    DemoSignal whole(48000.0f);
    std::vector<float> aw, bw;
    whole.next(aw, bw, 128);

    DemoSignal split(48000.0f);
    std::vector<float> a1, b1, a2, b2;
    split.next(a1, b1, 64);
    split.next(a2, b2, 64);

    bool ch1Match = true, ch2Match = true;
    for (std::size_t i = 0; i < 64; ++i) {
        if (aw[i]      != a1[i]) ch1Match = false;
        if (aw[i + 64] != a2[i]) ch1Match = false;
        if (bw[i]      != b1[i]) ch2Match = false;
        if (bw[i + 64] != b2[i]) ch2Match = false;
    }
    CHECK(ch1Match);
    CHECK(ch2Match);
}

int main() {
    test_shape_and_bounds();
    test_phase_continuity();
    REPORT();
}
