#pragma once

// Procedural plasma : fragment shader generating sin/cos turbulence with
// hue and turbulence params driven by audio amplitudes (bass/lead/kick).

#include "Visualizer.h"
#include "ofMain.h"

namespace oscope {

class PlasmaVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;
    void reloadShaders() override;

private:
    int w_ = 0, h_ = 0;
    float bass_ = 0.0f, lead_ = 0.0f, kick_ = 0.0f, pad_ = 0.0f;
    float bpm_ = 120.0f;
    ofShader shader_;
};

} // namespace oscope
