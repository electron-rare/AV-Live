#pragma once

// Layer arrière-plan piloté par sound_algo : grille hexagonale qui pulse au
// kick, gradient HSV qui tourne au beat, distortion modulée par la mélodie.
// Tout est calculé dans bg.frag, on n'envoie que des uniforms.

#include "Visualizer.h"
#include "ofMain.h"

namespace oscope {

class ReactiveVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;
    void reloadShaders() override;

private:
    ofShader bg_;
    int w_ = 0, h_ = 0;
    float time_ = 0.0f;
    float kick_ = 0.0f, hat_ = 0.0f, snare_ = 0.0f, clap_ = 0.0f;
    float perc_ = 0.0f, melody_ = 0.0f, acid_ = 0.0f, harmony_ = 0.0f;
    float bpm_ = 120.0f;
    int beat_ = 0;
};

} // namespace oscope
