#pragma once

// Time-domain oscilloscope view (CRT-style) for ch1/ch2 buffers.
// Falls back to synthesized signal driven by OscClient telemetry when
// the Hantek scope buffer is empty (Big Sur libusb limitation).

#include "Visualizer.h"
#include "ofMain.h"

#include <algorithm>
#include <vector>

namespace oscope {

class WaveformVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;

    // Live tweaks (driven by GUI sliders / OSC).
    void setTimeMsPerDiv(float v)     { timeMsPerDiv_ = std::max(0.05f, v); }
    void setSlowMsPerDiv(float v)     { slowMsPerDiv_ = std::max(1.0f, v); }
    void setShowSlowOverlay(bool b)   { showSlowOverlay_ = b; }
    void setScrollSpeed(float v)      { scrollSpeed_  = std::max(0.0f, std::min(1.0f, v)); }
    void setSampleRate(float hz)      { if (hz > 1.0f) sampleRateHz_ = hz; }
    void setCircular(bool b)          { circular_ = b; }
    /// Render circulaire fullscreen — timeline mappée à l'angle (0..2π),
    /// CH1/CH2/slow chacun sur un anneau concentrique. Pour Scope4.
    void drawCircular(int cx, int cy, float baseR, float maxR);

private:
    int   w_ = 0, h_ = 0;
    float phase_ = 0.0f;
    float beatPhase_ = 0.0f;
    int   prevBeat_ = 0;
    // trace1_/trace2_ : fenêtre "audio" (timeMsPerDiv_), taille fixe
    std::vector<float> trace1_;
    std::vector<float> trace2_;
    // slowTrace_ : même données mais fenêtre longue (slowMsPerDiv_), mono
    std::vector<float> slowTrace_;
    // Ring d'historique pour le scrolling (plus long, on lit la queue)
    std::vector<float> ring1_;
    std::vector<float> ring2_;
    std::size_t ringHead_ = 0;
    int   syntheticSize_ = 2048;
    float divX_ = 8.0f;   // grid divisions
    float divY_ = 8.0f;

    // Time base — combien de millisecondes représente une division horizontale.
    float timeMsPerDiv_     = 5.0f;
    // Time base lent (overlay) — vue enveloppe / drift, lit le même ring
    // mais avec une fenêtre bien plus longue, superposé au trace audio.
    float slowMsPerDiv_     = 50.0f;
    bool  showSlowOverlay_  = true;
    bool  circular_         = false;
    // 0 = freeze (capture par trame), 1 = scroll continu (oscilloscope rolling).
    // Défaut = 1 pour que le trace soit live tant que le user ne touche à rien.
    float scrollSpeed_  = 1.0f;
    // Hz — utilisé pour convertir ms/div en samples/div.
    float sampleRateHz_ = 8'000'000.0f;
};

} // namespace oscope
