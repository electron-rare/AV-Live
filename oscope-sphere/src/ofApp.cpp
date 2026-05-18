#include "ofApp.h"
#include <algorithm>
#include <cmath>

void ofApp::setup() {
    ofSetFrameRate(60);
    ofSetVerticalSync(true);
    ofBackground(6, 6, 10);
    ofEnableDepthTest();
    glEnable(GL_PROGRAM_POINT_SIZE);

    cam_.setDistance(750.0f);
    cam_.setNearClip(1.0f);
    cam_.setFarClip(5000.0f);

    sphere_.setup(5, 512, 256, 1024);
    rings_.setup(512);

    hantek_.setSampleRate(16000000u);
    const oscope::HantekStatus st = hantek_.start();
    if (st == oscope::HantekStatus::Ok) {
        demoMode_ = false;
        statusText_ = "SCOPE OK";
    } else {
        demoMode_ = true;
        statusText_ = (st == oscope::HantekStatus::FirmwareNeeded)
            ? "DEMO - firmware needed (see docs/HANTEK_SETUP.md)"
            : "DEMO - scope not found";
    }
}

void ofApp::update() {
    if (frozen_) return;

    if (demoMode_) {
        demo_.next(buf1_, buf2_, 8192);
    } else {
        hantek_.ring().readLatest(buf1_, buf2_, 8192);
        if (hantek_.status() != oscope::HantekStatus::Ok) {
            demoMode_ = true;
            statusText_ = "DEMO - scope lost";
        }
    }

    const float sr = demoMode_ ? 48000.0f : scopeSr_;
    analyzerCh1_.update(buf1_, buf1_, sr);
    analyzerCh2_.update(buf2_, buf2_, sr);

    // Audio-reactive motion: rotation speed tracks signal energy, the whole
    // sphere pulses with the kick transient.
    const oscope::AudioBands& b1 = analyzerCh1_.bands();
    const oscope::AudioBands& b2 = analyzerCh2_.bands();
    const float energy = 0.5f * (b1.full + b2.full);
    const float kick   = std::max(b1.kick, b2.kick);
    const float dt     = static_cast<float>(ofGetLastFrameTime());
    if (!ofGetMousePressed())
        spin_ += (8.0f + 80.0f * energy) * dt;
    pulse_ += (1.0f + 0.20f * kick - pulse_) * 0.25f;

    sphere_.setColormap(colormap_);
    sphere_.pushSpectrogramColumn(analyzerCh1_.magDown(),
                                  analyzerCh2_.magDown());
    sphere_.setWaveform(buf1_, buf2_);
    rings_.setWaveform(buf1_, buf2_);
}

void ofApp::draw() {
    const float t = ofGetElapsedTimef();
    cam_.begin();
    ofPushMatrix();
    ofRotateYDeg(spin_);
    ofRotateXDeg(16.0f * std::sin(t * 0.27f));   // slow tumble
    ofScale(pulse_, pulse_, pulse_);             // audio pulse
    if (layerA_) sphere_.drawSkin();
    if (layerC_) sphere_.drawPoints();
    if (layerB_) rings_.draw();
    ofPopMatrix();
    cam_.end();
    drawHud();
}

void ofApp::drawHud() {
    ofDisableDepthTest();
    ofSetColor(230);
    std::string hud = statusText_ + "\n";
    hud += std::string("[1] skin   ") + (layerA_ ? "on" : "off") + "\n";
    hud += std::string("[2] rings  ") + (layerB_ ? "on" : "off") + "\n";
    hud += std::string("[3] points ") + (layerC_ ? "on" : "off") + "\n";
    hud += std::string("[c] colormap   [space] ") +
           (frozen_ ? "frozen" : "live");
    ofDrawBitmapString(hud, 16, 24);
    ofEnableDepthTest();
}

void ofApp::keyPressed(int key) {
    switch (key) {
        case '1': layerA_ = !layerA_; break;
        case '2': layerB_ = !layerB_; break;
        case '3': layerC_ = !layerC_; break;
        case 'c':
        case 'C': colormap_ = (colormap_ + 1) % 2; break;
        case ' ': frozen_ = !frozen_; break;
    }
}
