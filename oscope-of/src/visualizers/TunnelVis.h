#pragma once

// Cylindrical raymarched tunnel — fullscreen fragment shader. Speed
// follows BPM, twist follows lead amplitude, segment lighting pulses
// on kick and bass.

#include "Visualizer.h"
#include "ofMain.h"

namespace oscope {

class TunnelVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;
    void reloadShaders() override;

private:
    int   w_ = 0, h_ = 0;
    float travel_    = 0.0f;
    float direction_ = 1.0f;   // smooth -1..+1 (lead-bass driven)
    float bpm_ = 120.0f, kick_ = 0.0f, bass_ = 0.0f, lead_ = 0.0f, pad_ = 0.0f;
    ofShader shader_;
};

} // namespace oscope
