#pragma once

// Lightweight kaleidoscope : draws a few rotating shape primitives that
// the post-fx kaleido pass turns into a full radial pattern. Cheap to
// render, looks rich after PostFx.

#include "Visualizer.h"
#include "ofMain.h"

namespace oscope {

class KaleidoVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;

private:
    int w_ = 0, h_ = 0;
    float phase_ = 0.0f;
    float bass_ = 0.0f, lead_ = 0.0f, kick_ = 0.0f, pad_ = 0.0f;
};

} // namespace oscope
