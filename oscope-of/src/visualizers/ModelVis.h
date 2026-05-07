#pragma once

// ModelVis : charge un .ply (oF native), anime en 3D avec rotation
// continue + lumière qui pulse + matériau modulé par fréquences.
// Forms type Escher / Möbius / Klein bottle / trefoil knot inclus.

#include "Visualizer.h"
#include "ofMain.h"

#include <string>

namespace oscope {

class ModelVis : public Visualizer {
public:
    explicit ModelVis(const std::string& plyPath, float autoScale = 1.0f)
        : plyPath_(plyPath), userScale_(autoScale) {}
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;

private:
    std::string plyPath_;
    float userScale_;
    int   w_ = 0, h_ = 0;
    float t_ = 0.0f;
    float bass_ = 0, mid_ = 0, treble_ = 0, kick_ = 0, bpm_ = 120;

    ofMesh   mesh_;
    bool     wireframe_ = false;
    float    autoScale_ = 1.0f;
    ofVec3f  meshCenter_;
    ofCamera camera_;
    ofLight  light_;
    ofMaterial material_;
};

} // namespace oscope
