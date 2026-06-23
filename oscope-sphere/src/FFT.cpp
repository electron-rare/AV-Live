#include "FFT.h"

#include <cmath>

namespace oscope {

FFT::FFT(std::size_t size) : size_(size), window_(size), work_(size) {
    // Fenêtre de Hann pré-calculée.
    for (std::size_t i = 0; i < size_; ++i) {
        window_[i] = 0.5f * (1.0f - std::cos(2.0f * M_PI * i / (size_ - 1)));
    }
}

void FFT::hannWindow(std::vector<float>& buf) const {
    for (std::size_t i = 0; i < size_; ++i) buf[i] *= window_[i];
}

void FFT::fftInPlace(std::vector<std::complex<float>>& x) const {
    const std::size_t N = x.size();
    // Bit-reversal permutation.
    std::size_t j = 0;
    for (std::size_t i = 1; i < N; ++i) {
        std::size_t bit = N >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) std::swap(x[i], x[j]);
    }
    // Butterflies.
    for (std::size_t len = 2; len <= N; len <<= 1) {
        const float ang = -2.0f * M_PI / static_cast<float>(len);
        const std::complex<float> wlen(std::cos(ang), std::sin(ang));
        for (std::size_t i = 0; i < N; i += len) {
            std::complex<float> w(1.0f, 0.0f);
            for (std::size_t k = 0; k < len / 2; ++k) {
                const auto u = x[i + k];
                const auto v = x[i + k + len / 2] * w;
                x[i + k] = u + v;
                x[i + k + len / 2] = u - v;
                w *= wlen;
            }
        }
    }
}

void FFT::magnitude(const std::vector<float>& in, std::vector<float>& outMag) {
    const std::size_t N = size_;
    std::vector<float> windowed(N, 0.0f);
    const std::size_t copy = std::min(N, in.size());
    for (std::size_t i = 0; i < copy; ++i) windowed[i] = in[i];
    hannWindow(windowed);
    for (std::size_t i = 0; i < N; ++i) work_[i] = std::complex<float>(windowed[i], 0.0f);
    fftInPlace(work_);
    outMag.resize(N / 2);
    const float invN = 1.0f / static_cast<float>(N);
    for (std::size_t i = 0; i < N / 2; ++i) {
        outMag[i] = std::abs(work_[i]) * invN;
    }
}

} // namespace oscope
