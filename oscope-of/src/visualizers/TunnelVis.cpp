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

    // Direction : lerp lente vers +1 si la balance HF (lead) > LF (bass),
    // -1 sinon. Le signe contrôle le sens de défilement et le sens du twist.
    const float dirTarget = (lead_ - bass_) > 0.05f ? 1.0f
                          : (bass_ - lead_) > 0.05f ? -1.0f
                          : direction_;
    direction_ += (dirTarget - direction_) * 0.04f;

    // Vitesse : base BPM + boost sur kick, signée par direction_.
    const float speed = (0.6f + bpm_ * 0.012f + kick_ * 1.5f) * direction_;
    travel_ += static_cast<float>(ofGetLastFrameTime()) * speed;
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
    // Taille de tile pilotée par les fréquences :
    // - axe Z (profondeur) : bass loud → grosses tuiles (uTileZ bas)
    // - axe angulaire        : lead loud → tuiles fines    (uTileX haut)
    const float tileZ = ofLerp(3.0f, 0.5f, std::min(1.0f, bass_));
    const float tileX = ofLerp(8.0f, 32.0f, std::min(1.0f, lead_));
    shader_.setUniform1f("uTileZ", tileZ);
    shader_.setUniform1f("uTileX", tileX);
    shader_.setUniform1f("uDirection", direction_);
    ofDrawRectangle(x, y, w, h);
    shader_.end();
}

} // namespace oscope
