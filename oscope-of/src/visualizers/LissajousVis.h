#pragma once

// Lissajous XY scope avec persistance type CRT phosphor.
// FBO en feedback : à chaque frame on dessine un fade noir alpha-bas par-dessus
// puis on trace les segments (CH1, CH2). Un shader glow (Gaussian blur 9-tap)
// est appliqué en sortie.

#include "Visualizer.h"
#include "ofMain.h"

namespace oscope {

class LissajousVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;
    void reloadShaders() override;

private:
    ofFbo trail_;
    ofShader glow_;
    int w_ = 0;
    int h_ = 0;
    float kickFlash_ = 0.0f; // 0..1, décrémenté à chaque frame
    int lastBeat_ = -1;
};

} // namespace oscope
