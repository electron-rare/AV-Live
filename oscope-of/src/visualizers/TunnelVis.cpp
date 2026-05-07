#include "TunnelVis.h"

namespace oscope {

void TunnelVis::setup(int w, int h) { w_ = w; h_ = h; reloadShaders(); }

void TunnelVis::reloadShaders() { shader_.load("shaders/tunnel"); }

void TunnelVis::update(const VisFrame& frame) {
    bpm_   = frame.osc.bpm();
    kick_  = frame.osc.amp("kick");
    bass_  = frame.osc.amp("bass");
    lead_  = frame.osc.amp("lead");
    pad_   = frame.osc.amp("pad");
    snare_ = frame.osc.amp("snare");

    // Direction : lerp lente vers +1 si la balance HF (lead) > LF (bass),
    // -1 sinon. Le signe contrôle le sens de défilement et le sens du twist.
    const float dirTarget = (lead_ - bass_) > 0.05f ? 1.0f
                          : (bass_ - lead_) > 0.05f ? -1.0f
                          : direction_;
    direction_ += (dirTarget - direction_) * 0.04f;

    // Vitesse : base BPM + boost sur kick, signée par direction_.
    const float speed = (0.6f + bpm_ * 0.012f + kick_ * 1.5f) * direction_;
    travel_ += static_cast<float>(ofGetLastFrameTime()) * speed;

    // 3D — Banking (roll) : la nef s'incline en suivant la balance LF/HF
    // signée, oscillation lente sinusoïdale + composante directe.
    const float rollTarget = (lead_ - bass_) * 0.6f
        + std::sin(ofGetElapsedTimef() * 0.7f) * 0.15f * (kick_ + 0.3f);
    roll_ += (rollTarget - roll_) * 0.06f;

    // 3D — Pan : kick déplace momentanément le point de fuite (impact),
    // snare donne un offset latéral, pad un drift vertical lent.
    const float panTargetX =
        std::sin(ofGetElapsedTimef() * 0.4f) * 0.15f * pad_
        + (snare_ - 0.5f) * 0.4f * snare_;
    const float panTargetY =
        std::cos(ofGetElapsedTimef() * 0.55f) * 0.10f * pad_
        - kick_ * 0.25f;
    panX_ += (panTargetX - panX_) * 0.10f;
    panY_ += (panTargetY - panY_) * 0.10f;
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
    shader_.setUniform1f("uRoll", roll_);
    shader_.setUniform2f("uPan",  panX_, panY_);
    ofDrawRectangle(x, y, w, h);
    shader_.end();
}

} // namespace oscope
