#include "check.h"
#include "FFT.h"
#include "AudioAnalyzer.h"
#include <cmath>
#include <vector>

using oscope::AudioAnalyzer;
using oscope::FFT;

static int argmax(const std::vector<float>& v) {
    int best = 1;
    float bv = -1.0f;
    for (int i = 1; i < static_cast<int>(v.size()); ++i)
        if (v[i] > bv) { bv = v[i]; best = i; }
    return best;
}

static std::vector<float> tone(double freqHz, double srHz, std::size_t n) {
    std::vector<float> s(n);
    for (std::size_t i = 0; i < n; ++i)
        s[i] = static_cast<float>(std::sin(2.0 * M_PI * freqHz * i / srHz));
    return s;
}

// FFT of a sine landing exactly on bin 64 must peak at bin 64.
static void test_fft_peak() {
    const std::size_t N = 2048;
    std::vector<float> in(N);
    for (std::size_t i = 0; i < N; ++i)
        in[i] = static_cast<float>(std::sin(2.0 * M_PI * 64.0 * i / N));
    FFT fft(N);
    std::vector<float> mag;
    fft.magnitude(in, mag);
    CHECK(mag.size() == N / 2);
    int peak = argmax(mag);
    CHECK(peak >= 63 && peak <= 65);
}

// Feeding update(chX, chX) must isolate chX — proves the dual-analyzer
// trick: AudioAnalyzer mixes 0.5*(a+b), so 0.5*(x+x) == x.
static void test_per_channel_isolation() {
    const double sr = 48000.0;            // deci == 1, no decimation
    auto a = tone(1000.0, sr, 2048);      // bin width 23.4 Hz -> bin ~43
    auto b = tone(5000.0, sr, 2048);      // -> bin ~213
    AudioAnalyzer an1, an2;
    an1.update(a, a, static_cast<float>(sr));
    an2.update(b, b, static_cast<float>(sr));
    int p1 = argmax(an1.magDown());
    int p2 = argmax(an2.magDown());
    CHECK(p1 >= 41 && p1 <= 45);
    CHECK(p2 >= 211 && p2 <= 217);
    CHECK(p1 != p2);
}

int main() {
    test_fft_peak();
    test_per_channel_isolation();
    REPORT();
}
