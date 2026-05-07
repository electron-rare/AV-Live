#pragma once

// Orchestrateur principal :
// - démarre le scope Hantek + thread USB
// - démarre le client OSC
// - gère le mode courant (Lissajous / Spectrogram / Reactive / Hybrid)
// - assemble les visualizers et la GUI ofxPanel

#include "ofMain.h"
#include "ofxGui.h"

#include "HantekDevice.h"
#include "OscClient.h"
#include "visualizers/LissajousVis.h"
#include "visualizers/ReactiveVis.h"
#include "visualizers/SpectrogramVis.h"
#include "visualizers/WaveformVis.h"

#include <memory>

class ofApp : public ofBaseApp {
public:
    enum class Mode { Lissajous, Spectrogram, Reactive, Waveform, Hybrid };

    void setup() override;
    void update() override;
    void draw() override;
    void exit() override;
    void keyPressed(int key) override;

private:
    void loadSettings();
    void drawHud();

    oscope::HantekDevice scope_;
    oscope::OscClient osc_;

    std::unique_ptr<oscope::LissajousVis> lissajous_;
    std::unique_ptr<oscope::SpectrogramVis> spectro_;
    std::unique_ptr<oscope::ReactiveVis> reactive_;
    std::unique_ptr<oscope::WaveformVis> waveform_;

    std::vector<float> ch1_, ch2_;
    Mode mode_ = Mode::Hybrid;
    bool showGui_ = true;
    bool fullscreen_ = false;

    // GUI
    ofxPanel gui_;
    ofxFloatSlider gainCh1_, gainCh2_;
    ofxFloatSlider trailFade_;
    ofxIntSlider sampleRateHz_;
    ofxLabel scopeStatusLabel_;
    ofxLabel oscStatusLabel_;
    ofxLabel modeLabel_;

    // Settings persistants.
    int oscListenPort_ = 57122;
    std::string oscSendHost_ = "127.0.0.1";
    int oscSendPort_ = 57121;
    int bufferSize_ = 4096;
};
