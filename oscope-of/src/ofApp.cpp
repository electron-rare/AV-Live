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
    lissajous_->setup(W, H);
    spectro_->setup(W, H / 4);
    reactive_->setup(W, H);
    waveform_->setup(W, H);

    gui_.setup("oscope-of");
    gui_.add(modeLabel_.setup("Mode", "Hybrid"));
    gui_.add(scopeStatusLabel_.setup("Scope", scope_.statusString()));
    gui_.add(oscStatusLabel_.setup("OSC", "listening"));
    gui_.add(gainCh1_.setup("CH1 V/div", 1.0f, 0.25f, 5.0f));
    gui_.add(gainCh2_.setup("CH2 V/div", 1.0f, 0.25f, 5.0f));
    gui_.add(trailFade_.setup("Trail fade", 0.07f, 0.0f, 1.0f));
    gui_.add(sampleRateHz_.setup("Sample rate", 8000000, 1000000, 48000000));

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
    if (m == "lissajous")   mode_ = Mode::Lissajous;
    else if (m == "spectro" || m == "spectrogram") mode_ = Mode::Spectrogram;
    else if (m == "reactive") mode_ = Mode::Reactive;
    else if (m == "waveform" || m == "scope") mode_ = Mode::Waveform;
    else mode_ = Mode::Hybrid;
}

void ofApp::update() {
    osc_.update();
    scope_.ring().readLatest(ch1_, ch2_, static_cast<std::size_t>(bufferSize_));

    oscope::VisFrame frame{ch1_, ch2_, osc_};
    if (mode_ == Mode::Lissajous || mode_ == Mode::Hybrid) lissajous_->update(frame);
    if (mode_ == Mode::Spectrogram || mode_ == Mode::Hybrid) spectro_->update(frame);
    if (mode_ == Mode::Reactive || mode_ == Mode::Hybrid) reactive_->update(frame);
    if (mode_ == Mode::Waveform || mode_ == Mode::Hybrid) waveform_->update(frame);

    scopeStatusLabel_ = "Scope: " + scope_.statusString() + " (" +
                        ofToString(ch1_.size()) + " s)";
    oscStatusLabel_ = "OSC bpm=" + ofToString(osc_.bpm(), 1) +
                      " beat=" + ofToString(osc_.beat()) +
                      " kick=" + ofToString(osc_.amp("kick"), 2);
}

void ofApp::draw() {
    const int W = ofGetWidth();
    const int H = ofGetHeight();

    if (mode_ == Mode::Reactive || mode_ == Mode::Hybrid) {
        reactive_->draw(0, 0, W, H);
    } else {
        ofBackground(0);
    }
    if (mode_ == Mode::Waveform) {
        waveform_->draw(0, 0, W, H);
    } else if (mode_ == Mode::Lissajous || mode_ == Mode::Hybrid) {
        lissajous_->draw(0, 0, W, H);
    }
    if (mode_ == Mode::Spectrogram || mode_ == Mode::Hybrid) {
        const int sh = (mode_ == Mode::Spectrogram) ? H : H / 4;
        const int sy = (mode_ == Mode::Spectrogram) ? 0 : H - sh;
        spectro_->draw(0, sy, W, sh);
    }

    if (showGui_) {
        gui_.draw();
        drawHud();
    }
}

void ofApp::drawHud() {
    ofPushStyle();
    ofSetColor(180, 220, 200, 220);
    ofDrawBitmapString("FPS: " + ofToString(ofGetFrameRate(), 1), 12, ofGetHeight() - 28);
    ofDrawBitmapString("Mode: " +
        std::string(mode_ == Mode::Lissajous ? "Lissajous" :
                    mode_ == Mode::Spectrogram ? "Spectrogram" :
                    mode_ == Mode::Reactive ? "Reactive" :
                    mode_ == Mode::Waveform ? "Waveform" : "Hybrid"),
        12, ofGetHeight() - 12);
    ofPopStyle();
}

void ofApp::exit() {
    scope_.stop();
}

void ofApp::keyPressed(int key) {
    switch (key) {
        case '1': mode_ = Mode::Lissajous; modeLabel_ = "Lissajous"; break;
        case '2': mode_ = Mode::Spectrogram; modeLabel_ = "Spectrogram"; break;
        case '3': mode_ = Mode::Reactive; modeLabel_ = "Reactive"; break;
        case '4': mode_ = Mode::Hybrid; modeLabel_ = "Hybrid"; break;
        case '5': mode_ = Mode::Waveform; modeLabel_ = "Waveform"; break;
        case 'f':
            fullscreen_ = !fullscreen_;
            ofSetFullscreen(fullscreen_);
            break;
        case 'g': showGui_ = !showGui_; break;
        case 'r':
            lissajous_->reloadShaders();
            reactive_->reloadShaders();
            ofLogNotice("ofApp") << "Shaders rechargés";
            break;
        default: break;
    }
}
