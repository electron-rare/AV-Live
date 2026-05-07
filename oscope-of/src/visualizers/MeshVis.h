#pragma once

// 3D mesh visualizer : icosphere whose vertices are pushed in/out by a
// 32-band approximation of the channel waveform (cheap RMS per region,
// not a real FFT — we want look, not measurement). Rotates on its own
// and gets a kick on each beat. Uses ofCamera for proper perspective.

#include "Visualizer.h"
#include "ofMain.h"

namespace oscope {

class MeshVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;

private:
    int w_ = 0, h_ = 0;
    ofMesh sphereBase_;
    ofMesh sphereDeformed_;
    ofCamera cam_;
    float yaw_ = 0.0f, pitch_ = 0.0f;
    float pulseScale_ = 1.0f;
    float bass_ = 0.0f, lead_ = 0.0f, kick_ = 0.0f, pad_ = 0.0f;
    float bpm_ = 120.0f;
    std::vector<float> bandEnergy_;
};

} // namespace oscope
