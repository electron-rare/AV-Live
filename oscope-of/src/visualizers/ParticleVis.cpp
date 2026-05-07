#include "ParticleVis.h"

namespace oscope {

void ParticleVis::setup(int w, int h) {
    w_ = w;
    h_ = h;
    particles_.assign(800, P{});
}

void ParticleVis::spawnBurst(int n, ofVec2f origin, ofFloatColor col, float speed) {
    for (int i = 0; i < n; ++i) {
        P& p = particles_[cursor_ % particles_.size()];
        ++cursor_;
        const float a = ofRandom(0.0f, TWO_PI);
        const float v = speed * ofRandom(0.5f, 1.0f);
        p.pos = origin;
        p.vel = ofVec2f(std::cos(a), std::sin(a)) * v;
        p.col = col;
        p.col.a = 1.0f;
        p.maxLife = ofRandom(0.6f, 1.6f);
        p.life = p.maxLife;
        p.size = ofRandom(1.5f, 4.0f);
    }
}

void ParticleVis::update(const VisFrame& frame) {
    const float dt = std::min(0.05f, static_cast<float>(ofGetLastFrameTime()));
    const float kick = frame.osc.amp("kick");
    const float lead = frame.osc.amp("lead");
    const float bass = frame.osc.amp("bass");

    // Beat: kick → red burst from center, lead → cyan ring
    if (frame.osc.beatPulse()) {
        spawnBurst(50 + static_cast<int>(kick * 80.0f),
                   ofVec2f(w_ * 0.5f, h_ * 0.5f),
                   ofFloatColor(1.0f, 0.4f, 0.2f),
                   220.0f + kick * 350.0f);
        if (lead > 0.05f) {
            spawnBurst(40 + static_cast<int>(lead * 50.0f),
                       ofVec2f(w_ * 0.5f, h_ * 0.5f),
                       ofFloatColor(0.4f, 0.9f, 1.0f),
                       150.0f + lead * 280.0f);
        }
    }

    // Continuous spawn driven by lead amplitude
    if (lead > 0.05f) {
        const int n = std::min(8, static_cast<int>(lead * 30.0f));
        spawnBurst(n,
                   ofVec2f(ofRandom(0.0f, w_), ofRandom(0.0f, h_)),
                   ofFloatColor(1.0f, 0.8f, 0.3f),
                   60.0f + lead * 200.0f);
    }

    // Integrate
    const ofVec2f center(w_ * 0.5f, h_ * 0.5f);
    const float gravity = bass * 80.0f;
    for (auto& p : particles_) {
        if (p.life <= 0.0f) continue;
        ofVec2f toCenter = (center - p.pos);
        float d = toCenter.length();
        if (d > 1.0f) toCenter /= d;
        p.vel += toCenter * gravity * dt;
        p.vel *= (1.0f - dt * 0.6f);
        p.pos += p.vel * dt;
        p.life -= dt;
        p.col.a = std::max(0.0f, p.life / p.maxLife);
    }
}

void ParticleVis::draw(int x, int y, int w, int h) {
    ofPushStyle();
    ofPushMatrix();
    ofTranslate(x, y);
    const float sx = w / static_cast<float>(w_);
    const float sy = h / static_cast<float>(h_);
    ofScale(sx, sy);

    ofEnableBlendMode(OF_BLENDMODE_ADD);
    ofFill();
    for (const auto& p : particles_) {
        if (p.life <= 0.0f) continue;
        ofSetColor(p.col);
        ofDrawCircle(p.pos.x, p.pos.y, p.size);
    }
    ofDisableBlendMode();

    ofPopMatrix();
    ofPopStyle();
}

} // namespace oscope
