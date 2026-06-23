#pragma once
#include <vector>

namespace oscope {

// Pure-C++ rolling spectrogram column store. No GL dependency.
// Layout: row-major, data()[row * width + col].
// Height is forced even. Rows [H/2, H) hold CH1 (equator -> north pole),
// rows [0, H/2) hold CH2 (equator -> south pole). Frequency is log-scaled
// along the rows; magnitudes are normalised to [0,1] via a -60..0 dB map.
class SpectrogramBuffer {
public:
    SpectrogramBuffer(int width, int height);

    // magCh1 / magCh2: raw FFT magnitudes. Log-resampled into one column
    // at the current write index, which then advances modulo width.
    void pushColumn(const std::vector<float>& magCh1,
                    const std::vector<float>& magCh2);

    int width()  const { return width_; }
    int height() const { return height_; }
    int writeIndex() const { return writeIndex_; }
    const std::vector<float>& data() const { return data_; }

private:
    static float logResample(const std::vector<float>& mag, float frac01);
    static float norm01(float magnitude);

    int width_;
    int height_;
    int writeIndex_ = 0;
    std::vector<float> data_;
};

} // namespace oscope
