#pragma once

// Polar / radial scope : maps the audio waveform onto a rose pattern.
// Time → angle, amplitude → radius. Beat triggers an outward shockwave.

#include "Visualizer.h"
#include "ofMain.h"

namespace oscope {

class PolarVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;

private:
    int w_ = 0, h_ = 0;
    float rotation_ = 0.0f;
    float shockR_   = 0.0f;
    float shockA_   = 0.0f;
    std::vector<float> trace1_;
    std::vector<float> trace2_;
    float bpm_ = 120.0f;
    float kick_ = 0.0f;
    float bass_ = 0.0f;
    float lead_ = 0.0f;
};

} // namespace oscope
