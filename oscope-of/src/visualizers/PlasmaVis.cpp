#include "PlasmaVis.h"

namespace oscope {

void PlasmaVis::setup(int w, int h) {
    w_ = w;
    h_ = h;
    reloadShaders();
}

void PlasmaVis::reloadShaders() {
    shader_.load("shaders/plasma");
}

void PlasmaVis::update(const VisFrame& frame) {
    bass_ = frame.osc.amp("bass");
    lead_ = frame.osc.amp("lead");
    kick_ = frame.osc.amp("kick");
    pad_  = frame.osc.amp("pad");
    bpm_  = frame.osc.bpm();
}

void PlasmaVis::draw(int x, int y, int w, int h) {
    if (!shader_.isLoaded()) {
        ofPushStyle();
        ofSetColor(20, 30, 60);
        ofDrawRectangle(x, y, w, h);
        ofSetColor(255, 80, 80);
        ofDrawBitmapString("plasma shader missing", x + 12, y + 24);
        ofPopStyle();
        return;
    }
    shader_.begin();
    shader_.setUniform2f("uRes", static_cast<float>(w), static_cast<float>(h));
    shader_.setUniform1f("uTime", ofGetElapsedTimef());
    shader_.setUniform1f("uBpm", bpm_);
    shader_.setUniform1f("uBass", bass_);
    shader_.setUniform1f("uLead", lead_);
    shader_.setUniform1f("uKick", kick_);
    shader_.setUniform1f("uPad", pad_);
    ofDrawRectangle(x, y, w, h);
    shader_.end();
}

} // namespace oscope
