#include "AudioAnalyzer.h"

#include <algorithm>
#include <cmath>

namespace oscope {

AudioAnalyzer::AudioAnalyzer() : fft_(kFftSize) {
    mono_.assign(kFftSize, 0.0f);
}

void AudioAnalyzer::update(const std::vector<float>& ch1,
                           const std::vector<float>& ch2,
                           float scopeSampleRateHz) {
    if (ch1.size() < 16 || scopeSampleRateHz < 1.0f) {
        // Décay doux pour ne pas figer la valeur précédente
        bands_.bass    *= 0.92f;
        bands_.lowMid  *= 0.92f;
        bands_.mid     *= 0.92f;
        bands_.treble  *= 0.92f;
        bands_.kick    *= 0.85f;
        bands_.snare   *= 0.85f;
        bands_.full    *= 0.92f;
        return;
    }

    // Downsampling par moyenne (box filter) du SR scope vers ~48 kHz audio.
    // Décimation = scopeSr / 48000, arrondi entier ≥ 1.
    const std::size_t deci =
        static_cast<std::size_t>(std::max(1.0f, scopeSampleRateHz / kAudioSr));
    const std::size_t n = std::min(ch1.size(), ch2.size());

    for (std::size_t i = 0; i + deci <= n; i += deci) {
        float acc = 0.0f;
        for (std::size_t j = 0; j < deci; ++j) {
            acc += 0.5f * (ch1[i + j] + ch2[i + j]);
        }
        mono_[head_] = acc / static_cast<float>(deci);
        head_ = (head_ + 1) % mono_.size();
    }

    // Window Hann + FFT — on linéarise mono_ depuis head_.
    std::vector<float> win(kFftSize);
    for (std::size_t i = 0; i < kFftSize; ++i) {
        const std::size_t idx = (head_ + i) % kFftSize;
        const float w = 0.5f * (1.0f - std::cos(2.0f * 3.14159265f * i /
                                                static_cast<float>(kFftSize - 1)));
        win[i] = mono_[idx] * w;
    }
    fft_.magnitude(win, mag_);

    // Bin width = audioSr / fftSize. Avec kAudioSr=48k, kFftSize=1024 →
    // ~46.9 Hz par bin.
    const float binHz = kAudioSr / static_cast<float>(kFftSize);
    auto sumBand = [&](float lo, float hi) -> float {
        const std::size_t i0 = static_cast<std::size_t>(lo / binHz);
        const std::size_t i1 = std::min(mag_.size(),
            static_cast<std::size_t>(hi / binHz) + 1);
        if (i1 <= i0) return 0.0f;
        float s = 0.0f;
        for (std::size_t i = i0; i < i1; ++i) s += mag_[i];
        return s / static_cast<float>(i1 - i0);
    };

    // Bandes en log-power, normalisées 0..1 par un mapping doux.
    auto db01 = [](float v) {
        const float db = 20.0f * std::log10(std::max(v, 1e-6f));
        // -60 dB → 0, 0 dB → 1
        return std::max(0.0f, std::min(1.0f, (db + 60.0f) / 60.0f));
    };

    const float prevBass = bands_.bass;
    const float prevMid  = bands_.mid;

    bands_.bass   = db01(sumBand(20.0f,    200.0f));
    bands_.lowMid = db01(sumBand(200.0f,   800.0f));
    bands_.mid    = db01(sumBand(800.0f,  3200.0f));
    bands_.treble = db01(sumBand(3200.0f, 16000.0f));

    // Transitoire = différence positive lissée. Détecte un kick = montée
    // brusque sur la bande basse, snare = montée sur mid + treble.
    const float kickRise  = std::max(0.0f, bands_.bass  - prevBass) * 1.6f;
    const float snareRise = std::max(0.0f,
        (bands_.mid + bands_.treble) * 0.5f - prevMid) * 1.6f;
    bands_.kick  = std::max(bands_.kick  * 0.85f, kickRise);
    bands_.snare = std::max(bands_.snare * 0.85f, snareRise);

    // Full RMS
    float rms = 0.0f;
    for (auto v : mono_) rms += v * v;
    bands_.full = std::sqrt(rms / mono_.size());

    prevBass_ = prevBass;
    prevMid_  = prevMid;
}

} // namespace oscope
