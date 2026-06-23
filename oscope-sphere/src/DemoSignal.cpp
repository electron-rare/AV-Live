#include "DemoSignal.h"
#include <algorithm>
#include <cmath>

namespace oscope {

namespace {
constexpr double kTwoPi = 6.283185307179586;
}

DemoSignal::DemoSignal(float sampleRateHz)
    : sr_(sampleRateHz > 1.0f ? sampleRateHz : 48000.0f) {}

float DemoSignal::frand() {
    rng_ = rng_ * 1664525u + 1013904223u;
    return (static_cast<float>(rng_ >> 8) / 8388608.0f) - 1.0f;  // [-1,1)
}

void DemoSignal::next(std::vector<float>& ch1, std::vector<float>& ch2,
                      std::size_t n) {
    ch1.resize(n);
    ch2.resize(n);
    for (std::size_t i = 0; i < n; ++i) {
        // CH1: sweep 80 Hz .. 2000 Hz, sweep period ~6 s.
        sweep_ += 1.0 / sr_;
        const double sweepHz =
            80.0 + 960.0 * (1.0 + std::sin(kTwoPi * sweep_ / 6.0));
        phase1_ += kTwoPi * sweepHz / sr_;
        ch1[i] = 0.85f * static_cast<float>(std::sin(phase1_));

        // CH2: steady 440 Hz tone + light noise.
        phase2_ += kTwoPi * 440.0 / sr_;
        const float v =
            0.7f * static_cast<float>(std::sin(phase2_)) + 0.15f * frand();
        ch2[i] = std::clamp(v, -1.0f, 1.0f);
    }
    if (phase1_ > kTwoPi * 1e6) phase1_ -= kTwoPi * 1e6;
    if (phase2_ > kTwoPi * 1e6) phase2_ -= kTwoPi * 1e6;
}

} // namespace oscope
