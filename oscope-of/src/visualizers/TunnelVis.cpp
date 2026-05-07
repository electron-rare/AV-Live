#include "TunnelVis.h"

namespace oscope {

void TunnelVis::setup(int w, int h) { w_ = w; h_ = h; reloadShaders(); }

void TunnelVis::reloadShaders() { shader_.load("shaders/tunnel"); }

void TunnelVis::update(const VisFrame& frame) {
    bpm_  = frame.osc.bpm();
    kick_ = frame.osc.amp("kick");
    bass_ = frame.osc.amp("bass");
    lead_ = frame.osc.amp("lead");
    pad_  = frame.osc.amp("pad");
    travel_ += static_cast<float>(ofGetLastFrameTime()) * (0.6f + bpm_ * 0.012f + kick_ * 1.5f);
}

void TunnelVis::draw(int x, int y, int w, int h) {
    if (!shader_.isLoaded()) {
        ofPushStyle();
        ofSetColor(40);
        ofDrawRectangle(x, y, w, h);
        ofSetColor(255, 80, 80);
        ofDrawBitmapString("tunnel shader missing", x + 12, y + 24);
        ofPopStyle();
        return;
    }
    shader_.begin();
    shader_.setUniform2f("uRes",  static_cast<float>(w), static_cast<float>(h));
    shader_.setUniform1f("uTime", ofGetElapsedTimef());
    shader_.setUniform1f("uTravel", travel_);
    shader_.setUniform1f("uBpm",  bpm_);
    shader_.setUniform1f("uKick", kick_);
    shader_.setUniform1f("uBass", bass_);
    shader_.setUniform1f("uLead", lead_);
    shader_.setUniform1f("uPad",  pad_);
    ofDrawRectangle(x, y, w, h);
    shader_.end();
}

} // namespace oscope
