#pragma once
#include "ofMain.h"
#include <vector>

// GL visual unit: two line-loop rings orbiting the sphere in
// perpendicular planes. Ring 1 follows CH1, ring 2 follows CH2; each
// point's orbit radius is modulated by the live waveform.
class OrbitRings {
public:
    void setup(int pointsPerRing);
    void setWaveform(const std::vector<float>& ch1,
                     const std::vector<float>& ch2);
    void draw();

private:
    int       n_          = 0;
    float     baseRadius_ = 300.0f;
    float     amp_        = 70.0f;
    ofVboMesh ring1_;   // CH1, XZ plane
    ofVboMesh ring2_;   // CH2, XY plane
};
