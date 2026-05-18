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

// Phase is continuous across calls: a second block differs from the first.
static void test_phase_advances() {
    DemoSignal demo(48000.0f);
    std::vector<float> a1, b1, a2, b2;
    demo.next(a1, b1, 64);
    demo.next(a2, b2, 64);
    bool same = true;
    for (std::size_t i = 0; i < 64; ++i)
        if (std::fabs(a1[i] - a2[i]) > 1e-4f) same = false;
    CHECK(!same);
}

int main() {
    test_shape_and_bounds();
    test_phase_advances();
    REPORT();
}
