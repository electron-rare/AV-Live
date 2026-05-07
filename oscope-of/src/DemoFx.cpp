#include "DemoFx.h"

#include <fstream>
#include <sstream>
#include <cmath>

namespace oscope {

namespace {
constexpr int kStarCount = 220;

// Charge un fichier texte tel quel, ou renvoie un fallback si absent.
std::string loadFile(const std::string& path, const std::string& fallback) {
    std::ifstream f(path);
    if (!f.is_open()) return fallback;
    std::stringstream ss;
    ss << f.rdbuf();
    return ss.str();
}
} // namespace

void DemoFx::setup(const std::string& greetingsPath) {
    text_ = loadFile(greetingsPath,
        "*** AV-LIVE *** GREETINGS *** ");
    // Nettoie newlines pour rester sur 1 ligne de scroller.
    for (auto& c : text_) if (c == '\n' || c == '\r') c = ' ';

    stars_.resize(kStarCount);
    for (auto& s : stars_) {
        s.x = ofRandom(-1.0f, 1.0f);
        s.y = ofRandom(-1.0f, 1.0f);
        s.z = ofRandom(0.05f, 1.0f);
    }
}

void DemoFx::update(float dt) {
    t_ += dt;
    if (scrollerOn_) {
        // ~150 px/s
        scrollX_ -= dt * 150.0f;
    }
    if (starOn_) {
        for (auto& s : stars_) {
            s.z -= dt * 0.45f;
            if (s.z <= 0.02f) {
                s.x = ofRandom(-1.0f, 1.0f);
                s.y = ofRandom(-1.0f, 1.0f);
                s.z = 1.0f;
            }
        }
    }
    if (copperOn_) copperPhase_ += dt * 0.6f;
    if (bobsOn_)   bobsPhase_   += dt * 1.2f;
}

void DemoFx::drawScroller(int W, int H) {
    if (!scrollerOn_ || text_.empty()) return;
    ofPushStyle();
    ofEnableBlendMode(OF_BLENDMODE_ADD);

    const float scale  = 3.0f;
    const float charW  = 8.0f * scale;
    const float baseY  = H - 60.0f;
    const float amp    = 14.0f;

    const float fullW = charW * static_cast<float>(text_.size());
    if (scrollX_ < -fullW) scrollX_ = static_cast<float>(W);

    auto drawChar = [&](char ch, float x, float y, float sx, float sy,
                        float rot, ofColor col) {
        ofSetColor(col);
        ofPushMatrix();
        ofTranslate(x, y);
        if (rot != 0.0f) ofRotateRad(rot);
        ofScale(sx, sy, 1.0f);
        const char buf[2] = { ch, 0 };
        ofDrawBitmapString(buf, 0, 0);
        ofPopMatrix();
    };

    for (std::size_t i = 0; i < text_.size(); ++i) {
        const float cx = scrollX_ + i * charW;
        if (cx < -charW || cx > W + charW) continue;
        const float wob = std::sin(t_ * 2.5f + i * 0.28f) * amp;

        switch (scrollerStyle_) {
        case ScrollerStyle::Classic: {
            const float hue = std::fmod(i * 4.0f + t_ * 25.0f, 60.0f) + 80.0f;
            ofColor c; c.setHsb(hue, 200.0f, 255.0f); c.a = 230;
            drawChar(text_[i], cx, baseY + wob, scale, scale, 0.0f, c);
            break;
        }
        case ScrollerStyle::Wavy3D: {
            const float pulse = 0.5f + 0.5f * std::sin(t_ * 3.0f + i * 0.45f);
            const float sxv = scale * (0.6f + pulse * 0.9f);
            const float syv = scale * (1.0f - pulse * 0.3f);
            ofColor c; c.setHsb(140.0f + pulse * 60.0f, 200.0f, 255.0f); c.a = 220;
            drawChar(text_[i], cx, baseY + wob, sxv, syv, 0.0f, c);
            break;
        }
        case ScrollerStyle::Rainbow: {
            const float hue = std::fmod(i * 12.0f + t_ * 60.0f, 255.0f);
            ofColor c; c.setHsb(hue, 230.0f, 255.0f); c.a = 240;
            drawChar(text_[i], cx, baseY + wob, scale, scale, 0.0f, c);
            break;
        }
        case ScrollerStyle::Mirror: {
            const float hue = std::fmod(i * 4.0f + t_ * 25.0f, 60.0f) + 80.0f;
            ofColor c; c.setHsb(hue, 200.0f, 255.0f);
            ofColor cTop = c; cTop.a = 230;
            ofColor cBot = c; cBot.a = 90;
            drawChar(text_[i], cx, baseY + wob, scale, scale, 0.0f, cTop);
            // Reflet : translate Y de 2× scale + flip Y
            drawChar(text_[i], cx, baseY + wob + 14.0f * scale,
                     scale, -scale * 0.7f, 0.0f, cBot);
            break;
        }
        case ScrollerStyle::Glitch: {
            const float jx = std::sin(t_ * 60.0f + i * 1.7f) * 6.0f;
            const float jy = std::cos(t_ * 73.0f + i * 2.1f) * 4.0f;
            const bool corrupt = (std::sin(t_ * 11.0f + i * 0.6f) > 0.85f);
            ofColor c;
            c.setHsb(corrupt ? 0.0f : 180.0f, 230.0f,
                     200.0f + 55.0f * (corrupt ? 1.0f : 0.0f));
            c.a = 230;
            drawChar(text_[i], cx + jx, baseY + wob + jy, scale, scale, 0.0f, c);
            break;
        }
        case ScrollerStyle::Neon: {
            // Outline cyan large + cœur magenta fin
            ofColor outline(80, 220, 255, 110);
            for (int dx = -1; dx <= 1; ++dx)
                for (int dy = -1; dy <= 1; ++dy) {
                    if (dx == 0 && dy == 0) continue;
                    drawChar(text_[i], cx + dx * 2.0f, baseY + wob + dy * 2.0f,
                             scale, scale, 0.0f, outline);
                }
            ofColor core(255, 100, 200, 240);
            drawChar(text_[i], cx, baseY + wob, scale, scale, 0.0f, core);
            break;
        }
        }
    }
    ofDisableBlendMode();
    ofPopStyle();
}

void DemoFx::drawStarfield(int W, int H) {
    if (!starOn_) return;
    ofPushStyle();
    ofEnableBlendMode(OF_BLENDMODE_ADD);
    const float cx = W * 0.5f;
    const float cy = H * 0.5f;
    for (const auto& s : stars_) {
        const float k = 1.0f / std::max(0.05f, s.z);
        const float x = cx + s.x * k * (W * 0.5f);
        const float y = cy + s.y * k * (H * 0.5f);
        const float bright = std::min(1.0f, k * 0.18f);
        const int alpha    = static_cast<int>(255 * bright);
        const float r      = 0.5f + bright * 2.5f;
        ofSetColor(220, 240, 255, alpha);
        ofDrawCircle(x, y, r);
        // Streak en arrière dans la direction radiale (motion blur)
        const float k2 = 1.0f / std::max(0.05f, s.z + 0.05f);
        const float x2 = cx + s.x * k2 * (W * 0.5f);
        const float y2 = cy + s.y * k2 * (H * 0.5f);
        ofSetColor(120, 180, 220, alpha / 2);
        ofSetLineWidth(1);
        ofDrawLine(x, y, x2, y2);
    }
    ofDisableBlendMode();
    ofPopStyle();
}

void DemoFx::drawCopperBars(int W, int H) {
    if (!copperOn_) return;
    ofPushStyle();
    ofEnableBlendMode(OF_BLENDMODE_ADD);
    const int nBars = 6;
    for (int i = 0; i < nBars; ++i) {
        const float p = std::sin(copperPhase_ + i * 0.7f) * 0.5f + 0.5f;
        const float y = p * (H * 0.30f);
        const float bh = 12.0f;
        // Hue cycle
        const float hue = std::fmod((i * 30.0f + copperPhase_ * 40.0f), 255.0f);
        ofColor c;
        c.setHsb(hue, 220.0f, 220.0f);
        // Gradient vertical : cœur clair, bords sombres
        for (int j = 0; j < 8; ++j) {
            const float t = j / 7.0f;
            const float a = std::sin(t * 3.14159f);
            ofSetColor(c, static_cast<int>(180 * a));
            ofDrawRectangle(0, y + j * (bh / 8.0f), W, bh / 8.0f);
        }
    }
    ofDisableBlendMode();
    ofPopStyle();
}

void DemoFx::drawBobs(int W, int H, const std::string& logo) {
    if (!bobsOn_ || logo.empty()) return;
    ofPushStyle();
    ofEnableBlendMode(OF_BLENDMODE_ADD);
    const float scale = 4.0f;
    const float charW = 8.0f * scale;
    const float startX = W * 0.5f - logo.size() * charW * 0.5f;
    const float baseY = 80.0f;
    for (std::size_t i = 0; i < logo.size(); ++i) {
        const float cx = startX + i * charW;
        const float by = baseY + std::sin(bobsPhase_ + i * 0.5f) * 30.0f;
        const float scl = scale + std::sin(bobsPhase_ * 1.5f + i * 0.4f) * 0.5f;
        const float hue = std::fmod((bobsPhase_ * 30.0f + i * 25.0f), 255.0f);
        ofColor c;
        c.setHsb(hue, 180.0f, 255.0f);
        ofSetColor(c, 200);
        ofPushMatrix();
        ofTranslate(cx, by);
        ofScale(scl, scl, 1.0f);
        const char buf[2] = { logo[i], 0 };
        ofDrawBitmapString(buf, 0, 0);
        ofPopMatrix();
    }
    ofDisableBlendMode();
    ofPopStyle();
}

} // namespace oscope
