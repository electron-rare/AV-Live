#pragma once
#include <cstdint>
#include <vector>

namespace oscope {

// Pure-C++ synthetic two-channel signal for when no scope is connected.
// CH1: slow frequency sweep. CH2: steady 440 Hz tone plus light noise.
// Stateful: phase advances across calls so the output stays continuous.
class DemoSignal {
public:
    explicit DemoSignal(float sampleRateHz);

    // Fills ch1 and ch2 with n freshly generated samples each.
    void next(std::vector<float>& ch1, std::vector<float>& ch2,
              std::size_t n);

private:
    float frand();   // cheap LCG noise in [-1, 1)

    float    sr_;
    double   phase1_ = 0.0;
    double   phase2_ = 0.0;
    double   sweep_  = 0.0;
    uint32_t rng_    = 0x9E3779B9u;
};

} // namespace oscope
