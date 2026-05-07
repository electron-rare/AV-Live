#pragma once

// Cylindrical raymarched tunnel — fullscreen fragment shader. Speed
// follows BPM, twist follows lead amplitude, segment lighting pulses
// on kick and bass.

#include "Visualizer.h"
#include "ofMain.h"

namespace oscope {

class TunnelVis : public Visualizer {
public:
    /// Multiplicateurs live pilotables au clavier (cf. ofApp::keyPressed
    /// a→z). 1.0 = défaut, > 1 boost, < 1 atténue.
    struct Mults {
        float speed     = 1.0f;
        float kickBoost = 1.0f;
        float rollAmp   = 1.0f;
        float panAmp    = 1.0f;
        float curveAmp  = 1.0f;
        float tileX     = 1.0f;
        float tileZ     = 1.0f;
        float dirLerp   = 1.0f;
    };

    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;
    void reloadShaders() override;
    void setMults(const Mults& m) { mults_ = m; }
    const Mults& mults() const { return mults_; }

private:
    int   w_ = 0, h_ = 0;
    float travel_    = 0.0f;
    float direction_ = 1.0f;   // smooth -1..+1 (lead-bass driven)
    float roll_       = 0.0f;   // banking smoothed
    float panX_       = 0.0f;
    float panY_       = 0.0f;
    float curveAmp_   = 0.05f;  // intensité du virage smoothée
    float curvePhase_ = 0.0f;   // avance avec travel pour défilement
    Mults mults_;
    float bpm_ = 120.0f, kick_ = 0.0f, bass_ = 0.0f, lead_ = 0.0f, pad_ = 0.0f;
    float snare_ = 0.0f;
    ofShader shader_;
};

} // namespace oscope
