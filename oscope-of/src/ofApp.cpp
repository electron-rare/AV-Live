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
        case ofApp::Mode::Tunnel:      return "Tunnel 3D";
        case ofApp::Mode::Mesh:        return "Mesh 3D";
        case ofApp::Mode::Scope4:      return "Scope 4-up";
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
    tunnel_    = std::make_unique<oscope::TunnelVis>();
    mesh_      = std::make_unique<oscope::MeshVis>();
    lissajous_->setup(W, H);
    spectro_->setup(W, H / 4);
    reactive_->setup(W, H);
    waveform_->setup(W, H);
    polar_->setup(W, H);
    plasma_->setup(W, H);
    particles_->setup(W, H);
    kaleido_->setup(W, H);
    tunnel_->setup(W, H);
    mesh_->setup(W, H);

    postfx_.setup(W, H);

    gui_.setup("oscope-of");
    gui_.add(modeLabel_.setup("Mode", modeName(mode_)));
    gui_.add(scopeStatusLabel_.setup("Scope", scope_.statusString()));
    gui_.add(oscStatusLabel_.setup("OSC", "listening"));
    gui_.add(gainCh1_.setup("CH1 V/div", 1.0f, 0.25f, 5.0f));
    gui_.add(gainCh2_.setup("CH2 V/div", 1.0f, 0.25f, 5.0f));
    gui_.add(trailFade_.setup("Trail fade", 0.07f, 0.0f, 1.0f));
    gui_.add(sampleRateHz_.setup("Sample rate", 8000000, 1000000, 48000000));
    gui_.add(timeMsPerDiv_.setup("Time ms/div", 5.0f, 0.05f, 200.0f));
    gui_.add(slowMsPerDiv_.setup("Slow ms/div", 50.0f, 5.0f, 500.0f));
    gui_.add(slowOverlayEnabled_.setup("Slow overlay", true));
    gui_.add(scrollSpeed_.setup("Scroll", 1.0f, 0.0f, 1.0f));
    // start() a déjà appelé configureDevice() avec sampleRateHz_=8e6 (valeur
    // par défaut côté HantekDevice). On NE rappelle PAS setSampleRate ici :
    // ça enverrait un control transfer 0xE2 pendant la première bulk transfer
    // et désynchroniserait le FX2 (pixels 0/255 entrelacés -> écran "blanc").
    lastSampleRateApplied_ = sampleRateHz_;
    pendingSampleRate_     = sampleRateHz_;

    // PostFx panel — placed to the right of the main GUI
    fxGui_.setup("post-fx", "fx-settings.xml", 230, 10);
    fxGui_.add(fxEnableToggle_.setup("enabled", true));
    fxGui_.add(fxChroma_.setup("chroma",     0.0f, 0.0f, 1.0f));
    fxGui_.add(fxBloom_.setup("bloom",       0.15f, 0.0f, 1.0f));
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
    else if (m == "tunnel")       mode_ = Mode::Tunnel;
    else if (m == "mesh")         mode_ = Mode::Mesh;
    else if (m == "scope4" ||
             m == "quad")         mode_ = Mode::Scope4;
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
    // Re-apply sample rate when the slider changes — debounce 250ms pour
    // ne pas spammer le FX2 avec des control transfers pendant que l'user
    // fait glisser le slider (chaque transfer désynchronise le bulk stream).
    const int curSr = sampleRateHz_;
    if (curSr != pendingSampleRate_) {
        pendingSampleRate_   = curSr;
        pendingSampleRateAt_ = ofGetElapsedTimef();
    }
    if (pendingSampleRate_ != lastSampleRateApplied_ &&
        ofGetElapsedTimef() - pendingSampleRateAt_ > 0.25f) {
        lastSampleRateApplied_ = pendingSampleRate_;
        scope_.setSampleRate(static_cast<uint32_t>(lastSampleRateApplied_));
    }
    // Push live timebase + scroll into WaveformVis.
    waveform_->setTimeMsPerDiv(timeMsPerDiv_);
    waveform_->setSlowMsPerDiv(slowMsPerDiv_);
    waveform_->setShowSlowOverlay(slowOverlayEnabled_);
    waveform_->setScrollSpeed(scrollSpeed_);
    waveform_->setSampleRate(static_cast<float>(lastSampleRateApplied_));
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
    tunnel_->update(frame);
    mesh_->update(frame);

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
        case Mode::Tunnel:      tunnel_->draw(x, y, w, h);      break;
        case Mode::Mesh:        mesh_->draw(x, y, w, h);        break;
        case Mode::Scope4:      drawScope4(w, h);               break;
        case Mode::Hybrid:      drawHybrid(w, h);               break;
    }
}

void ofApp::drawHybrid(int W, int H) {
    // Background : the 3D tunnel fills the canvas
    tunnel_->draw(0, 0, W, H);

    // 2x2 quadrant overlay with additive blending
    ofEnableBlendMode(OF_BLENDMODE_ADD);
    const int hw = W / 2;
    const int hh = H / 2;
    lissajous_->draw(0,  0,  hw, hh);
    polar_->draw   (hw, 0,  hw, hh);
    kaleido_->draw (0,  hh, hw, hh);
    mesh_->draw    (hw, hh, hw, hh);
    ofDisableBlendMode();

    // Particle field on top, fullscreen
    particles_->draw(0, 0, W, H);

    // Spectrogram strip across the bottom
    const int sh = H / 6;
    spectro_->draw(0, H - sh, W, sh);
}

void ofApp::drawPanelLabel(int x, int y, const char* title,
                           const std::string& metric) {
    ofPushStyle();
    ofSetColor(0, 0, 0, 140);
    const int textW = 6 * (static_cast<int>(metric.size()) + 16);
    ofDrawRectangle(x, y, textW + 14, 22);
    ofSetColor(0, 255, 140, 220);
    ofDrawBitmapString(title, x + 8, y + 14);
    ofSetColor(180, 230, 200, 220);
    ofDrawBitmapString(metric, x + 8 + 6 * 8, y + 14);
    ofPopStyle();
}

void ofApp::drawScope4(int W, int H) {
    // 1) Tunnel fullscreen en fond — focal central, fréquences pilotent
    //    tile size / direction / vitesse (cf. TunnelVis).
    tunnel_->draw(0, 0, W, H);

    // 2) Spectrogramme circulaire colorisé par fréquence, centré.
    //    Anneau de barres FFT, hue bleu→rouge, magnitude = longueur radiale.
    const float cx = W * 0.5f;
    const float cy = H * 0.5f;
    const float ringInner = std::min(W, H) * 0.18f;
    const float ringOuter = std::min(W, H) * 0.32f;
    spectro_->drawCircular(cx, cy, ringInner, ringOuter);

    // 3) Trois satellites en orbite autour du tunnel — leur position
    //    tourne lentement en suivant le BPM. Chacun garde son rendu
    //    interne (pas de rotation du contenu, juste de la position).
    const float bpm  = osc_.bpm();
    const float orbit = ofGetElapsedTimef() * (0.04f + bpm * 0.0003f);
    const float orbitR = std::min(W, H) * 0.40f;
    const int satW = static_cast<int>(W * 0.24f);
    const int satH = static_cast<int>(H * 0.20f);

    struct Satellite { oscope::Visualizer* vis; const char* tag; std::string metric; };
    const float kick = osc_.amp("kick");
    const float lead = osc_.amp("lead");
    const float bass = osc_.amp("bass");
    Satellite sats[3] = {
        {waveform_.get(),  "WAVE  ",
            ofToString(static_cast<float>(timeMsPerDiv_), 2) + " ms"},
        {polar_.get(),     "POLAR ",
            ofToString(bpm, 0) + " bpm k" + ofToString(kick, 1)},
        {lissajous_.get(), "LISSA ",
            "L" + ofToString(lead, 1) + " B" + ofToString(bass, 1)},
    };
    for (int i = 0; i < 3; ++i) {
        const float a = orbit + i * (TWO_PI / 3.0f);
        const int sx = static_cast<int>(cx + std::cos(a) * orbitR - satW * 0.5f);
        const int sy = static_cast<int>(cy + std::sin(a) * orbitR - satH * 0.5f);
        sats[i].vis->draw(sx, sy, satW, satH);
        drawPanelLabel(sx + 6, sy + 6, sats[i].tag, sats[i].metric);
    }

    // 4) Label central : tunnel infos
    drawPanelLabel(static_cast<int>(cx) - 80, 6, "TUNNEL",
        ofToString(bpm, 1) + " bpm  dir " +
        ofToString((osc_.amp("lead") - osc_.amp("bass")), 2));
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

    // Bottom-left : FPS + mode
    ofSetColor(180, 220, 200, 220);
    ofDrawBitmapString("FPS: " + ofToString(ofGetFrameRate(), 1),
                       12, ofGetHeight() - 28);
    ofDrawBitmapString(std::string("Mode: ") + modeName(mode_) +
        (postFxEnabled_ ? "  [fx ON]" : "  [fx OFF]"),
        12, ofGetHeight() - 12);

    // Top-left : sound_algo state from /sync/* (album, melody, synthdef,
    // bpm, beat). Boxed background so it stays readable over any visual.
    const std::string& album = osc_.album();
    const std::string& melody = osc_.melody();
    const std::string& synthdef = osc_.synthdef();
    const float bpm = osc_.bpm();
    const int beat = osc_.beat();
    const float kick = osc_.amp("kick");

    std::vector<std::string> lines;
    if (!album.empty())    lines.push_back("ALBUM   " + album);
    if (!melody.empty())   lines.push_back("MELODY  " + melody);
    if (!synthdef.empty()) lines.push_back("SYNTH   " + synthdef);
    lines.push_back("BPM     " + ofToString(bpm, 1) +
                    "   BEAT " + ofToString(beat));

    if (!lines.empty()) {
        const int padding = 8;
        const int lineH = 14;
        const int boxW = 280;
        const int boxH = static_cast<int>(lines.size()) * lineH + padding * 2;
        ofSetColor(0, 0, 0, 150);
        ofDrawRectangle(12, 12, boxW, boxH);
        ofSetColor(140, 200, 255, 60);
        ofNoFill();
        ofDrawRectangle(12, 12, boxW, boxH);
        ofFill();
        for (std::size_t i = 0; i < lines.size(); ++i) {
            ofSetColor(220, 230, 240, 230);
            ofDrawBitmapString(lines[i],
                               12 + padding,
                               12 + padding + 11 + static_cast<int>(i) * lineH);
        }
        // Beat indicator dot pulses on each beat (uses kick amp as proxy)
        const float pulse = std::min(1.0f, kick * 2.0f);
        ofSetColor(255, 180, 80, static_cast<int>(120 + pulse * 135.0f));
        ofDrawCircle(12 + boxW - padding - 6, 12 + padding + 6,
                     3.0f + pulse * 4.0f);
    }

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
        case '0': mode_ = Mode::Tunnel;      break;
        case '-': mode_ = Mode::Mesh;        break;
        case 'q': mode_ = Mode::Scope4;      break;
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
            tunnel_->reloadShaders();
            postfx_.reloadShader();
            ofLogNotice("ofApp") << "Shaders rechargés";
            break;
        default: break;
    }
}
