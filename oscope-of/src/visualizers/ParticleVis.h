#pragma once

// Audio-reactive particle field. Beat spawns bursts. FFT amplitudes per
// voice modulate per-particle drift and color. ~600 particles, integrated
// in fixed timestep, drawn as additive points.

#include "Visualizer.h"
#include "ofMain.h"

namespace oscope {

class ParticleVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;

private:
    struct P {
        ofVec2f pos;
        ofVec2f vel;
        ofFloatColor col;
        float life = 0.0f;
        float maxLife = 1.0f;
        float size = 2.0f;
    };

    int w_ = 0, h_ = 0;
    std::vector<P> particles_;
    std::size_t cursor_ = 0;
    void spawnBurst(int n, ofVec2f origin, ofFloatColor col, float speed);
};

} // namespace oscope
