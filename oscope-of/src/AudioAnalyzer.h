#pragma once

// Extracteur de bandes audio depuis le signal Hantek brut.
// Downsample (8-48 MS/s scope → ~48 kHz audio) puis FFT pour obtenir
// bass / lowMid / mid / treble + détecteurs de transitoire kick/snare.
// Source d'inspiration : besoin de piloter les visualizers sur LE signal
// qui passe physiquement dans le scope, pas sur les métadonnées OSC.

#include "FFT.h"

#include <vector>

namespace oscope {

struct AudioBands {
    float bass    = 0.0f; // 20–200 Hz
    float lowMid  = 0.0f; // 200–800 Hz
    float mid     = 0.0f; // 800–3200 Hz
    float treble  = 0.0f; // 3200 Hz+
    float kick    = 0.0f; // transient sur bass
    float snare   = 0.0f; // transient sur mid+treble
    float full    = 0.0f; // RMS global
};

class AudioAnalyzer {
public:
    AudioAnalyzer();
    /// Alimenter avec les samples Hantek bruts + sample rate scope.
    void update(const std::vector<float>& ch1,
                const std::vector<float>& ch2,
                float scopeSampleRateHz);
    const AudioBands& bands() const { return bands_; }

private:
    static constexpr std::size_t kFftSize  = 1024;
    static constexpr float       kAudioSr  = 48000.0f;

    FFT  fft_;
    std::vector<float> mono_;      // ring downsamplé, kFftSize floats
    std::size_t        head_ = 0;
    std::vector<float> mag_;
    AudioBands bands_;
    float prevBass_ = 0.0f;
    float prevMid_  = 0.0f;
};

} // namespace oscope
