#pragma once
#include "ofMain.h"
#include "HantekDevice.h"
#include "AudioAnalyzer.h"
#include "DemoSignal.h"
#include "SphereViz.h"
#include "OrbitRings.h"
#include <string>
#include <vector>

class ofApp : public ofBaseApp {
public:
    void setup() override;
    void update() override;
    void draw() override;
    void keyPressed(int key) override;

private:
    void drawHud();

    oscope::HantekDevice  hantek_;
    oscope::AudioAnalyzer analyzerCh1_;
    oscope::AudioAnalyzer analyzerCh2_;
    oscope::DemoSignal    demo_{48000.0f};

    SphereViz sphere_;
    OrbitRings rings_;
    ofEasyCam cam_;

    std::vector<float> buf1_;
    std::vector<float> buf2_;

    bool  demoMode_ = false;
    bool  frozen_   = false;
    bool  layerA_   = true;
    bool  layerB_   = true;
    bool  layerC_   = true;
    int   colormap_ = 0;
    float scopeSr_  = 16.0e6f;
    std::string statusText_;
};
