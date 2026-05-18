#include "SpectrogramBuffer.h"
#include <algorithm>
#include <cmath>

namespace oscope {

SpectrogramBuffer::SpectrogramBuffer(int width, int height)
    : width_(std::max(1, width)),
      height_(std::max(2, height - (height % 2))) {
    data_.assign(static_cast<std::size_t>(width_) * height_, 0.0f);
}

float SpectrogramBuffer::logResample(const std::vector<float>& mag,
                                     float frac01) {
    if (mag.size() < 2) return 0.0f;
    const float lo = 1.0f;
    const float hi = static_cast<float>(mag.size() - 1);
    const float f  = std::clamp(frac01, 0.0f, 1.0f);
    const float bin = lo * std::pow(hi / lo, f);
    const int i0 = static_cast<int>(bin);
    const int i1 = std::min(i0 + 1, static_cast<int>(mag.size()) - 1);
    const float t = bin - static_cast<float>(i0);
    return mag[i0] * (1.0f - t) + mag[i1] * t;
}

float SpectrogramBuffer::norm01(float magnitude) {
    const float db = 20.0f * std::log10(std::max(magnitude, 1e-6f));
    return std::clamp((db + 60.0f) / 60.0f, 0.0f, 1.0f);
}

void SpectrogramBuffer::pushColumn(const std::vector<float>& magCh1,
                                   const std::vector<float>& magCh2) {
    const int col   = writeIndex_;
    const int half  = height_ / 2;
    const float denom = static_cast<float>(std::max(1, half - 1));

    // CH1 -> northern rows [half, height_): row half = equator (low freq),
    // row height_-1 = north pole (high freq).
    for (int r = half; r < height_; ++r) {
        const float frac = static_cast<float>(r - half) / denom;
        data_[static_cast<std::size_t>(r) * width_ + col] =
            norm01(logResample(magCh1, frac));
    }
    // CH2 -> southern rows [0, half): row half-1 = equator (low freq),
    // row 0 = south pole (high freq).
    for (int r = 0; r < half; ++r) {
        const float frac = static_cast<float>(half - 1 - r) / denom;
        data_[static_cast<std::size_t>(r) * width_ + col] =
            norm01(logResample(magCh2, frac));
    }
    writeIndex_ = (writeIndex_ + 1) % width_;
}

} // namespace oscope
