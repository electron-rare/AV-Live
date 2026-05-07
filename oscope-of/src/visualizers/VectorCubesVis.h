#pragma once

// Vector cubes 3D : grille de cubes (ofBoxPrimitive) qui tournent
// individuellement + ensemble, lumière point qui suit le rythme.
// Animation 3D RÉELLE (pas un fragment shader). Audio-reactive.

#include "Visualizer.h"
#include "ofMain.h"

#include <vector>

namespace oscope {

class VectorCubesVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;

private:
    int w_ = 0, h_ = 0;
    float t_ = 0.0f;
    float bass_ = 0, mid_ = 0, treble_ = 0, kick_ = 0, bpm_ = 120;
    ofCamera camera_;
    ofLight  light_;
    ofMaterial material_;
    struct Cube {
        ofVec3f pos;
        ofVec3f rotAxis;
        float   rotSpeed;
        float   size;
    };
    std::vector<Cube> cubes_;
};

} // namespace oscope
