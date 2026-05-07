#pragma once

// FFT Cooley-Tukey radix-2 in-place, sans dépendance externe.
// Format : entrée temporelle réelle (N samples, N puissance de 2),
// sortie magnitude (N/2 bins, dernier sample = Nyquist).

#include <complex>
#include <cstddef>
#include <vector>

namespace oscope {

class FFT {
public:
    explicit FFT(std::size_t size);

    /// Calcule la FFT du signal `in` (taille = size_) et écrit les magnitudes
    /// dans `outMag` (taille = size_/2).
    void magnitude(const std::vector<float>& in, std::vector<float>& outMag);

    std::size_t size() const { return size_; }

private:
    void hannWindow(std::vector<float>& buf) const;
    void fftInPlace(std::vector<std::complex<float>>& x) const;

    std::size_t size_;
    std::vector<float> window_;
    std::vector<std::complex<float>> work_;
};

} // namespace oscope
