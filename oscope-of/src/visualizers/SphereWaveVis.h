#pragma once

// Sphere wave / spectrogram 3D : sphère icosaédrique dont chaque
// vertex a son rayon modulé par la magnitude FFT à l'angle correspondant
// + une oscillation par les samples audio Hantek. Vrai 3D anim.

#include "Visualizer.h"
#include "ofMain.h"
#include "../FFT.h"

#include <memory>
#include <vector>

namespace oscope {

class SphereWaveVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;

private:
    int   w_ = 0, h_ = 0;
    float t_ = 0.0f;
    float bass_ = 0, mid_ = 0, treble_ = 0, kick_ = 0, bpm_ = 120;
    float waveAmp_ = 0;

    static constexpr int kNU = 64;   // longitude
    static constexpr int kNV = 32;   // latitude
    ofMesh sphere_;          // mesh template (vertices base sur sphère unit)
    std::vector<float> baseR_;  // rayons base par vertex
    ofCamera   camera_;
    ofLight    light_;
    ofMaterial material_;
    std::unique_ptr<FFT> fft_;
    std::vector<float> mono_;
    std::vector<float> mag_;
};

} // namespace oscope
