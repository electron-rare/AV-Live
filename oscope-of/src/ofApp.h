#pragma once

// Orchestrateur principal :
// - démarre le scope Hantek + thread USB
// - démarre le client OSC
// - gère le mode courant (8 visualizers + Hybrid)
// - applique la chaîne PostFx avant l'écran (chromatic ab, bloom,
//   scanlines, glitch, feedback, kaleido, etc.)

#include "ofMain.h"
#include "ofxGui.h"

#include "HantekDevice.h"
#include "OscClient.h"
#include "PostFx.h"
#include "visualizers/LissajousVis.h"
#include "visualizers/ReactiveVis.h"
#include "visualizers/SpectrogramVis.h"
#include "visualizers/WaveformVis.h"
#include "visualizers/PolarVis.h"
#include "visualizers/PlasmaVis.h"
#include "visualizers/ParticleVis.h"
#include "visualizers/KaleidoVis.h"
#include "visualizers/TunnelVis.h"
#include "visualizers/MeshVis.h"

#include <memory>

class ofApp : public ofBaseApp {
public:
    enum class Mode {
        Lissajous, Spectrogram, Reactive, Waveform,
        Polar, Plasma, Particles, Kaleido,
        Tunnel, Mesh,
        Scope4,   // waveform + spectrogram + polar pulsing + lissajous
        Hybrid
    };

    void setup() override;
    void update() override;
    void draw() override;
    void exit() override;
    void keyPressed(int key) override;
    void windowResized(int w, int h) override;

private:
    void loadSettings();
    void drawHud();
    void drawMode(Mode m, int x, int y, int w, int h);
    void drawHybrid(int W, int H);
    void drawScope4(int W, int H);
    void drawPanelLabel(int x, int y, const char* title, const std::string& metric);
    void drawTunnelHud(int W, int H);

    // HUD pseudo-aléatoire sur les "carreaux" du tunnel : labels Hz < 10
    // (composantes LF / sub-bass extraites de la magnitude FFT).
    struct HudItem {
        float u, v;       // pos écran 0..1
        float life;       // secondes restantes
        float born;       // âge total pour fade-in
        float scale;
        std::string text;
        std::string label;
    };
    std::vector<HudItem> tunnelHud_;
    float tunnelHudNext_ = 0.0f;
    void applyOscFx();

    oscope::HantekDevice scope_;
    oscope::OscClient osc_;
    oscope::PostFx postfx_;
    oscope::AudioAnalyzer audio_;

    std::unique_ptr<oscope::LissajousVis>   lissajous_;
    std::unique_ptr<oscope::SpectrogramVis> spectro_;
    std::unique_ptr<oscope::ReactiveVis>    reactive_;
    std::unique_ptr<oscope::WaveformVis>    waveform_;
    std::unique_ptr<oscope::PolarVis>       polar_;
    std::unique_ptr<oscope::PlasmaVis>      plasma_;
    std::unique_ptr<oscope::ParticleVis>    particles_;
    std::unique_ptr<oscope::KaleidoVis>     kaleido_;
    std::unique_ptr<oscope::TunnelVis>      tunnel_;
    std::unique_ptr<oscope::MeshVis>        mesh_;

    std::vector<float> ch1_, ch2_;
    Mode mode_ = Mode::Scope4;
    bool showGui_ = true;
    bool fullscreen_ = false;
    bool postFxEnabled_ = true;
    bool autoGlitchOnKick_ = true;

    // GUI - scope
    ofxPanel gui_;
    ofxFloatSlider gainCh1_, gainCh2_;
    ofxFloatSlider trailFade_;
    ofxIntSlider sampleRateHz_;
    ofxFloatSlider timeMsPerDiv_;
    ofxFloatSlider slowMsPerDiv_;
    ofxToggle      slowOverlayEnabled_;
    ofxFloatSlider scrollSpeed_;
    int   lastSampleRateApplied_ = 0;
    int   pendingSampleRate_     = 0;
    float pendingSampleRateAt_   = 0.0f;
    ofxLabel scopeStatusLabel_;
    ofxLabel oscStatusLabel_;
    ofxLabel modeLabel_;

    // GUI - postfx
    ofxPanel fxGui_;
    ofxFloatSlider fxChroma_, fxBloom_, fxRgbShift_, fxSat_;
    ofxFloatSlider fxScan_, fxVignette_, fxGrain_, fxPixelate_;
    ofxFloatSlider fxKaleido_, fxFeedback_, fxFbZoom_, fxFbRot_;
    ofxFloatSlider fxGlitch_, fxGlitchProb_;
    ofxToggle      fxEnableToggle_;

    // Settings persistants.
    int oscListenPort_ = 57122;
    std::string oscSendHost_ = "127.0.0.1";
    int oscSendPort_ = 57121;
    int bufferSize_ = 4096;
};
