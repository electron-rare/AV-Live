#include "ofApp.h"

#include "ofxOsc.h"

#include <fstream>
#include <sstream>

namespace {
// Mini-parseur JSON minimaliste pour settings.json — suffisant pour les clés
// plates qu'on utilise (pas de vraie dépendance à ofxJSON).
std::string extractString(const std::string& src, const std::string& key,
                          const std::string& fallback) {
    auto p = src.find("\"" + key + "\"");
    if (p == std::string::npos) return fallback;
    p = src.find(':', p);
    if (p == std::string::npos) return fallback;
    auto q = src.find('"', p);
    if (q == std::string::npos) return fallback;
    auto r = src.find('"', q + 1);
    if (r == std::string::npos) return fallback;
    return src.substr(q + 1, r - q - 1);
}

float extractNumber(const std::string& src, const std::string& key, float fallback) {
    auto p = src.find("\"" + key + "\"");
    if (p == std::string::npos) return fallback;
    p = src.find(':', p);
    if (p == std::string::npos) return fallback;
    std::size_t i = p + 1;
    while (i < src.size() && (src[i] == ' ' || src[i] == '\n' || src[i] == '\t')) ++i;
    std::size_t j = i;
    while (j < src.size() && (std::isdigit(src[j]) || src[j] == '.' || src[j] == '-')) ++j;
    if (j == i) return fallback;
    try { return std::stof(src.substr(i, j - i)); } catch (...) { return fallback; }
}

const char* modeName(ofApp::Mode m) {
    switch (m) {
        case ofApp::Mode::Lissajous:   return "Lissajous";
        case ofApp::Mode::Spectrogram: return "Spectrogram";
        case ofApp::Mode::Reactive:    return "Reactive";
        case ofApp::Mode::Waveform:    return "Waveform";
        case ofApp::Mode::Polar:       return "Polar";
        case ofApp::Mode::Plasma:      return "Plasma";
        case ofApp::Mode::Particles:   return "Particles";
        case ofApp::Mode::Kaleido:     return "Kaleido";
        case ofApp::Mode::Hybrid:      return "Hybrid";
    }
    return "?";
}
} // namespace

void ofApp::setup() {
    ofSetVerticalSync(true);
    ofSetFrameRate(60);
    ofBackground(0);
    ofSetCircleResolution(72);

    loadSettings();

    osc_.setup(oscListenPort_, oscSendHost_, oscSendPort_);

    auto st = scope_.start();
    if (st == oscope::HantekStatus::FirmwareNeeded) {
        ofLogWarning("ofApp") << "Hantek firmware non charge — fonctionnement degrade.";
    }

    const int W = ofGetWidth();
    const int H = ofGetHeight();
    lissajous_ = std::make_unique<oscope::LissajousVis>();
    spectro_   = std::make_unique<oscope::SpectrogramVis>();
    reactive_  = std::make_unique<oscope::ReactiveVis>();
    waveform_  = std::make_unique<oscope::WaveformVis>();
    polar_     = std::make_unique<oscope::PolarVis>();
    plasma_    = std::make_unique<oscope::PlasmaVis>();
    particles_ = std::make_unique<oscope::ParticleVis>();
    kaleido_   = std::make_unique<oscope::KaleidoVis>();
    lissajous_->setup(W, H);
    spectro_->setup(W, H / 4);
    reactive_->setup(W, H);
    waveform_->setup(W, H);
    polar_->setup(W, H);
    plasma_->setup(W, H);
    particles_->setup(W, H);
    kaleido_->setup(W, H);

    postfx_.setup(W, H);

    gui_.setup("oscope-of");
    gui_.add(modeLabel_.setup("Mode", modeName(mode_)));
    gui_.add(scopeStatusLabel_.setup("Scope", scope_.statusString()));
    gui_.add(oscStatusLabel_.setup("OSC", "listening"));
    gui_.add(gainCh1_.setup("CH1 V/div", 1.0f, 0.25f, 5.0f));
    gui_.add(gainCh2_.setup("CH2 V/div", 1.0f, 0.25f, 5.0f));
    gui_.add(trailFade_.setup("Trail fade", 0.07f, 0.0f, 1.0f));
    gui_.add(sampleRateHz_.setup("Sample rate", 8000000, 1000000, 48000000));

    // PostFx panel — placed to the right of the main GUI
    fxGui_.setup("post-fx", "fx-settings.xml", 230, 10);
    fxGui_.add(fxEnableToggle_.setup("enabled", true));
    fxGui_.add(fxChroma_.setup("chroma",     0.0f, 0.0f, 1.0f));
    fxGui_.add(fxBloom_.setup("bloom",       0.4f, 0.0f, 1.0f));
    fxGui_.add(fxRgbShift_.setup("hue rot",  0.0f, 0.0f, 1.0f));
    fxGui_.add(fxSat_.setup("saturation",    1.0f, 0.0f, 2.0f));
    fxGui_.add(fxScan_.setup("scanlines",    0.3f, 0.0f, 1.0f));
    fxGui_.add(fxVignette_.setup("vignette", 0.5f, 0.0f, 1.0f));
    fxGui_.add(fxGrain_.setup("film grain",  0.15f, 0.0f, 1.0f));
    fxGui_.add(fxPixelate_.setup("pixelate", 0.0f, 0.0f, 1.0f));
    fxGui_.add(fxKaleido_.setup("kaleido",   0.0f, 0.0f, 1.0f));
    fxGui_.add(fxFeedback_.setup("feedback", 0.0f, 0.0f, 1.0f));
    fxGui_.add(fxFbZoom_.setup("fb zoom",    1.00f, 0.92f, 1.08f));
    fxGui_.add(fxFbRot_.setup("fb rot",      0.0f, -0.10f, 0.10f));
    fxGui_.add(fxGlitch_.setup("glitch",     0.0f, 0.0f, 1.0f));
    fxGui_.add(fxGlitchProb_.setup("glitch prob", 0.15f, 0.0f, 1.0f));

    ch1_.reserve(bufferSize_);
    ch2_.reserve(bufferSize_);
}

void ofApp::loadSettings() {
    std::ifstream f(ofToDataPath("settings.json"));
    if (!f.is_open()) return;
    std::stringstream ss; ss << f.rdbuf();
    const std::string s = ss.str();
    oscListenPort_ = static_cast<int>(extractNumber(s, "listen_port", oscListenPort_));
    oscSendPort_   = static_cast<int>(extractNumber(s, "send_port", oscSendPort_));
    oscSendHost_   = extractString(s, "send_host", oscSendHost_);
    bufferSize_    = static_cast<int>(extractNumber(s, "buffer_size", bufferSize_));
    const std::string m = extractString(s, "default_mode", "hybrid");
    if      (m == "lissajous")    mode_ = Mode::Lissajous;
    else if (m == "spectro" ||
             m == "spectrogram")  mode_ = Mode::Spectrogram;
    else if (m == "reactive")     mode_ = Mode::Reactive;
    else if (m == "waveform" ||
             m == "scope")        mode_ = Mode::Waveform;
    else if (m == "polar")        mode_ = Mode::Polar;
    else if (m == "plasma")       mode_ = Mode::Plasma;
    else if (m == "particles")    mode_ = Mode::Particles;
    else if (m == "kaleido")      mode_ = Mode::Kaleido;
    else                          mode_ = Mode::Hybrid;
}

void ofApp::applyOscFx() {
    // OSC values override GUI sliders when explicitly received. Sliders
    // remain the source of truth for values that have no OSC binding.
    auto bind = [&](const std::string& name, ofxFloatSlider& s) {
        s = osc_.fx(name, static_cast<float>(s));
    };
    bind("chroma",      fxChroma_);
    bind("bloom",       fxBloom_);
    bind("hue",         fxRgbShift_);
    bind("sat",         fxSat_);
    bind("scan",        fxScan_);
    bind("vignette",    fxVignette_);
    bind("grain",       fxGrain_);
    bind("pixelate",    fxPixelate_);
    bind("kaleido",     fxKaleido_);
    bind("feedback",    fxFeedback_);
    bind("fbzoom",      fxFbZoom_);
    bind("fbrot",       fxFbRot_);
    bind("glitch",      fxGlitch_);
    bind("glitchprob",  fxGlitchProb_);

    // /oscope/glitch <amount> → momentary pulse
    float pulse = 0.0f;
    if (osc_.consumeGlitchPulse(pulse)) {
        postfx_.triggerGlitch(pulse);
    }
    // Auto-glitch on kick if enabled
    if (autoGlitchOnKick_) {
        const float k = osc_.amp("kick");
        if (k > 0.55f) postfx_.triggerGlitch(0.5f * (k - 0.5f) * 2.0f, 0.12f);
    }
}

void ofApp::update() {
    osc_.update();
    scope_.ring().readLatest(ch1_, ch2_, static_cast<std::size_t>(bufferSize_));

    oscope::VisFrame frame{ch1_, ch2_, osc_};
    lissajous_->update(frame);
    spectro_->update(frame);
    reactive_->update(frame);
    waveform_->update(frame);
    polar_->update(frame);
    plasma_->update(frame);
    particles_->update(frame);
    kaleido_->update(frame);

    applyOscFx();

    postFxEnabled_ = fxEnableToggle_;
    postfx_.params.chroma       = fxChroma_;
    postfx_.params.bloom        = fxBloom_;
    postfx_.params.rgbShift     = fxRgbShift_;
    postfx_.params.saturation   = fxSat_;
    postfx_.params.scanlines    = fxScan_;
    postfx_.params.vignette     = fxVignette_;
    postfx_.params.filmGrain    = fxGrain_;
    postfx_.params.pixelate     = fxPixelate_;
    postfx_.params.kaleido      = fxKaleido_;
    postfx_.params.feedback     = fxFeedback_;
    postfx_.params.feedbackZoom = fxFbZoom_;
    postfx_.params.feedbackRot  = fxFbRot_;
    postfx_.params.glitch       = fxGlitch_;
    postfx_.params.glitchProb   = fxGlitchProb_;
    postfx_.update(ofGetLastFrameTime());

    scopeStatusLabel_ = "Scope: " + scope_.statusString() + " (" +
                        ofToString(ch1_.size()) + " s)";
    oscStatusLabel_ = "OSC bpm=" + ofToString(osc_.bpm(), 1) +
                      " beat=" + ofToString(osc_.beat()) +
                      " kick=" + ofToString(osc_.amp("kick"), 2);
    modeLabel_ = modeName(mode_);
}

void ofApp::drawMode(Mode m, int x, int y, int w, int h) {
    switch (m) {
        case Mode::Lissajous:   lissajous_->draw(x, y, w, h);   break;
        case Mode::Spectrogram: spectro_->draw(x, y, w, h);     break;
        case Mode::Reactive:    reactive_->draw(x, y, w, h);    break;
        case Mode::Waveform:    waveform_->draw(x, y, w, h);    break;
        case Mode::Polar:       polar_->draw(x, y, w, h);       break;
        case Mode::Plasma:      plasma_->draw(x, y, w, h);      break;
        case Mode::Particles:
            ofPushStyle();
            ofSetColor(0); ofDrawRectangle(x, y, w, h);
            ofPopStyle();
            particles_->draw(x, y, w, h);
            break;
        case Mode::Kaleido:     kaleido_->draw(x, y, w, h);     break;
        case Mode::Hybrid:      drawHybrid(w, h);               break;
    }
}

void ofApp::drawHybrid(int W, int H) {
    // Background plasma stretches across the full canvas
    plasma_->draw(0, 0, W, H);

    // 2x2 quadrant overlay with additive blending
    ofEnableBlendMode(OF_BLENDMODE_ADD);
    const int hw = W / 2;
    const int hh = H / 2;
    lissajous_->draw(0,  0,  hw, hh);
    polar_->draw   (hw, 0,  hw, hh);
    kaleido_->draw (0,  hh, hw, hh);
    reactive_->draw(hw, hh, hw, hh);
    ofDisableBlendMode();

    // Particle field on top, fullscreen
    particles_->draw(0, 0, W, H);

    // Spectrogram strip across the bottom
    const int sh = H / 6;
    spectro_->draw(0, H - sh, W, sh);
}

void ofApp::draw() {
    const int W = ofGetWidth();
    const int H = ofGetHeight();

    if (postFxEnabled_) {
        postfx_.beginScene();
        ofClear(0, 255);
        drawMode(mode_, 0, 0, W, H);
        postfx_.endScene();
        postfx_.draw(0, 0, W, H);
    } else {
        ofBackground(0);
        drawMode(mode_, 0, 0, W, H);
    }

    if (showGui_) {
        gui_.draw();
        fxGui_.draw();
        drawHud();
    }
}

void ofApp::drawHud() {
    ofPushStyle();
    ofSetColor(180, 220, 200, 220);
    ofDrawBitmapString("FPS: " + ofToString(ofGetFrameRate(), 1),
                       12, ofGetHeight() - 28);
    ofDrawBitmapString(std::string("Mode: ") + modeName(mode_) +
        (postFxEnabled_ ? "  [fx ON]" : "  [fx OFF]"),
        12, ofGetHeight() - 12);
    ofPopStyle();
}

void ofApp::exit() {
    scope_.stop();
}

void ofApp::windowResized(int w, int h) {
    postfx_.resize(w, h);
}

void ofApp::keyPressed(int key) {
    switch (key) {
        case '1': mode_ = Mode::Lissajous;   break;
        case '2': mode_ = Mode::Spectrogram; break;
        case '3': mode_ = Mode::Reactive;    break;
        case '4': mode_ = Mode::Hybrid;      break;
        case '5': mode_ = Mode::Waveform;    break;
        case '6': mode_ = Mode::Polar;       break;
        case '7': mode_ = Mode::Plasma;      break;
        case '8': mode_ = Mode::Particles;   break;
        case '9': mode_ = Mode::Kaleido;     break;
        case 'f':
            fullscreen_ = !fullscreen_;
            ofSetFullscreen(fullscreen_);
            break;
        case 'g': showGui_ = !showGui_; break;
        case 'p': fxEnableToggle_ = !fxEnableToggle_; break;
        case 'k': autoGlitchOnKick_ = !autoGlitchOnKick_; break;
        case ' ': postfx_.triggerGlitch(0.8f); break;
        case 'r':
            lissajous_->reloadShaders();
            reactive_->reloadShaders();
            plasma_->reloadShaders();
            postfx_.reloadShader();
            ofLogNotice("ofApp") << "Shaders rechargés";
            break;
        default: break;
    }
}
