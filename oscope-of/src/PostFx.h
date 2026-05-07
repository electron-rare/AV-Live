#pragma once

// Post-processing chain : applies a single composite fragment shader to
// the scene, with feedback ping-pong for trail/echo effects. All effects
// are summed into one frag pass for performance — set an intensity to 0
// to skip its branch.

#include "ofMain.h"

namespace oscope {

class PostFx {
public:
    struct Params {
        // Color
        float chroma       = 0.0f;  // chromatic aberration radius
        float bloom        = 0.4f;  // bright-pass blur strength
        float rgbShift     = 0.0f;  // hue rotation 0..1 = 0..2π
        float saturation   = 1.0f;  // 0..2 (1 = neutral)

        // CRT
        float scanlines    = 0.3f;  // 0..1
        float vignette     = 0.5f;  // 0..1
        float filmGrain    = 0.15f; // 0..1
        float pixelate     = 0.0f;  // 0..1 (block size)

        // Spatial
        float kaleido      = 0.0f;  // 0..1 → 2..12 mirror axes
        float feedback     = 0.0f;  // 0..1 trail strength
        float feedbackZoom = 1.0f;  // 0.95..1.05
        float feedbackRot  = 0.0f;  // -π..π per frame

        // Glitch
        float glitch       = 0.0f;  // 0..1 block displacement intensity
        float glitchProb   = 0.15f; // 0..1 fraction of blocks affected
    };

    Params params;

    void setup(int w, int h);
    void resize(int w, int h);
    void reloadShader();

    /// Wrap your visualizer draw between beginScene() and endScene().
    void beginScene();
    void endScene();

    /// Apply the post-processing chain and draw to the screen.
    void draw(int x, int y, int w, int h);

    /// Triggered by audio threshold to flash glitch effects briefly.
    void triggerGlitch(float amount, float decaySeconds = 0.18f);

    void update(float dt);

private:
    int  w_ = 0, h_ = 0;
    int  writeIdx_ = 0;
    bool ready_ = false;
    ofFbo fboScene_;
    ofFbo history_[2];
    ofShader shader_;
    float glitchPulse_ = 0.0f;
    float glitchDecay_ = 0.18f;
};

} // namespace oscope
