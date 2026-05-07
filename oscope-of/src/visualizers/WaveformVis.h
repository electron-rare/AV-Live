#pragma once

// Time-domain oscilloscope view (CRT-style) for ch1/ch2 buffers.
// Falls back to synthesized signal driven by OscClient telemetry when
// the Hantek scope buffer is empty (Big Sur libusb limitation).

#include "Visualizer.h"
#include "ofMain.h"

namespace oscope {

class WaveformVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;

private:
    int   w_ = 0, h_ = 0;
    float phase_ = 0.0f;
    float beatPhase_ = 0.0f;
    int   prevBeat_ = 0;
    std::vector<float> trace1_;
    std::vector<float> trace2_;
    int   syntheticSize_ = 2048;
    float divX_ = 8.0f;   // grid divisions
    float divY_ = 8.0f;
};

} // namespace oscope
