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
    metaballs_ = std::make_unique<oscope::ShaderVis>("shaders/metaballs");
    voronoi_   = std::make_unique<oscope::ShaderVis>("shaders/voronoi");
    twister_   = std::make_unique<oscope::ShaderVis>("shaders/twister");
    plasmaFbm_ = std::make_unique<oscope::ShaderVis>("shaders/plasma_fbm");
    rotozoom_  = std::make_unique<oscope::ShaderVis>("shaders/rotozoom");
    truchet_   = std::make_unique<oscope::ShaderVis>("shaders/truchet");
    sdfTunnel_  = std::make_unique<oscope::ShaderVis>("shaders/sdf_tunnel");
    kifs_       = std::make_unique<oscope::ShaderVis>("shaders/kifs");
    fire_       = std::make_unique<oscope::ShaderVis>("shaders/fire");
    gridPersp_  = std::make_unique<oscope::ShaderVis>("shaders/grid_persp");
    tunnelCubes_= std::make_unique<oscope::ShaderVis>("shaders/tunnel_cubes");
    caustics_   = std::make_unique<oscope::ShaderVis>("shaders/caustics");
    vortex_     = std::make_unique<oscope::ShaderVis>("shaders/vortex");
    octahedron_ = std::make_unique<oscope::ShaderVis>("shaders/octahedron");
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
    metaballs_->setup(W, H);
    voronoi_->setup(W, H);
    twister_->setup(W, H);
    plasmaFbm_->setup(W, H);
    rotozoom_->setup(W, H);
    truchet_->setup(W, H);
    sdfTunnel_->setup(W, H);
    kifs_->setup(W, H);
    fire_->setup(W, H);
    gridPersp_->setup(W, H);
    tunnelCubes_->setup(W, H);
    caustics_->setup(W, H);
    vortex_->setup(W, H);
    octahedron_->setup(W, H);

    postfx_.setup(W, H);

    demo_.setup(ofToDataPath("greetings.txt", true));
    initDemos();

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
    const std::string m = extractString(s, "default_mode", "scope4");
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

    // FFT audio depuis le ring Hantek (downsampled vers 48 kHz) pour les
    // bandes bass/lowMid/mid/treble + transitoires kick/snare. Pilote
    // les visualizers (Tunnel, Polar) sans dépendre de l'OSC.
    audio_.update(ch1_, ch2_, static_cast<float>(lastSampleRateApplied_));
    demo_.update(static_cast<float>(ofGetLastFrameTime()));
    updateNarrative(static_cast<float>(ofGetLastFrameTime()));

    oscope::VisFrame frame{ch1_, ch2_, osc_, audio_.bands()};
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
    metaballs_->update(frame);
    voronoi_->update(frame);
    twister_->update(frame);
    plasmaFbm_->update(frame);
    rotozoom_->update(frame);
    truchet_->update(frame);
    sdfTunnel_->update(frame);
    kifs_->update(frame);
    fire_->update(frame);
    gridPersp_->update(frame);
    tunnelCubes_->update(frame);
    caustics_->update(frame);
    vortex_->update(frame);
    octahedron_->update(frame);

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

void ofApp::initDemos() {
    using SS = oscope::ScrollerStyle;
    auto stars = []{
        ScopeToggles s{};
        s.tunnel=false; s.starfield=true; s.copperBars=false;
        s.bobs=false; s.tunnelHud=false; s.polar=false;
        s.spectroRing=false; s.waveform=false;
        return s;
    };
    auto starsWave = []{
        ScopeToggles s{};
        s.tunnel=false; s.starfield=true; s.copperBars=false;
        s.bobs=false; s.tunnelHud=false; s.polar=false;
        s.spectroRing=false; s.waveform=true;
        return s;
    };
    auto tunOnly = []{
        ScopeToggles s{};
        s.starfield=false; s.spectroRing=false; s.polar=false;
        s.waveform=false; s.bobs=false; s.copperBars=false;
        s.tunnelHud=false;
        return s;
    };
    auto polSpe = []{
        ScopeToggles s{};
        s.tunnel=false; s.starfield=false; s.copperBars=false;
        s.bobs=false; s.tunnelHud=false; s.waveform=false;
        return s;
    };
    auto cleanScope = []{
        ScopeToggles s{};
        s.tunnel=false; s.starfield=false; s.copperBars=false;
        s.bobs=false; s.tunnelHud=false;
        return s;
    };
    auto all = []{ return ScopeToggles{}; };

    demos_.clear();
    demos_.resize(15);

    // ─── 1 · AMIGA TRIBUTE ───────────────────────────────────
    demos_[0] = {"AMIGA TRIBUTE", {
        {"INSERT DISK",  18.0f, stars(),     SS::Neon,
         "    *** AMIGA 500 RELOADED ***    KICKSTART 1.3    "
         "    INSERT WORKBENCH DISK ", "M", BgKind::Starfield},
        {"SCROLLZ",      35.0f, all(),       SS::Classic,
         "    GREETINGS FROM 1989    COPPER BARS AND BOBS FOREVER    "
         "    AMIGA NEVER DIES    HELLO TO ALL DEMOSCENE VETERANS    ", "M",
         BgKind::Twister},
        {"COPPER STORM", 30.0f, all(),       SS::Rainbow,
         "    COPPER LIST IS POETRY    EVERY SCANLINE A NEW COLOR    ", "G",
         BgKind::Twister},
    }};

    // ─── 2 · C64 LOWLIFE ─────────────────────────────────────
    demos_[1] = {"C64 LOWLIFE", {
        {"BOOT",     15.0f, stars(),    SS::Glitch,
         "    **** COMMODORE 64 BASIC V2 ****    "
         "    64K RAM SYSTEM 38911 BASIC BYTES FREE    "
         "    READY.    LOAD \"DEMO\",8,1    SEARCHING FOR DEMO    ", "M",
         BgKind::Starfield},
        {"PIXEL",    35.0f, all(),      SS::Wavy3D,
         "    8 BIT FOREVER    SID CHIP 6581 SCREAMING    "
         "    THE FUTURE WAS LOFI ALL ALONG    "
         "    GREETINGS TO BOOZE DESIGN AND HOKUTO FORCE    ", "M",
         BgKind::Rotozoom},
        {"FREEZE",   25.0f, all(),      SS::Mirror,
         "    HARDWARE SCROLLER LOCKED IN VIC-II    "
         "    GROOVE THAT DEFIED 1MHZ    ", "M", BgKind::Rotozoom},
        {"CLIMAX",   30.0f, all(),      SS::Glitch,
         "    BREADBIN STILL ALIVE    NTSC COLORS DRIFTING    "
         "    LOAD\"$\",8 LIST    NEVER STOP    ", "V", BgKind::Voronoi},
    }};

    // ─── 3 · ACID JOURNEY ────────────────────────────────────
    demos_[2] = {"ACID JOURNEY", {
        {"DROP IN",    20.0f, stars(),   SS::Neon,
         "    THE ACID IS KICKING IN    303 STARTING TO CRY    "
         "    BREATHE SLOW    LET IT TAKE YOU    ", "A", BgKind::PlasmaFbm},
        {"303 LOOP",   45.0f, all(),     SS::Wavy3D,
         "    SQUELCH OF THE 303    FOREVER ASCENDING    "
         "    THE PATTERN NEVER REPEATS    HUE CYCLES IN OUR EYES    "
         "    EVERY KNOB TURN A NEW UNIVERSE    ", "A", BgKind::Truchet},
        {"PEAK",       40.0f, all(),     SS::Rainbow,
         "    FULL ACID    NEURONS DANCING    REALITY MELTING    "
         "    THE FILTER OPENS THE FILTER CLOSES    "
         "    AND THE HEAVENS SQUELCH BACK    ", "H", BgKind::Metaballs},
        {"FRACTAL",    30.0f, all(),     SS::Rainbow,
         "    THE BEAT FRACTALS    SELF SIMILAR INFINITE    "
         "    GREETINGS TO MERCURY AND TBL    ", "H", BgKind::Truchet},
        {"COMEDOWN",   25.0f, starsWave(), SS::Mirror,
         "    AND SOFTLY BACK TO EARTH    "
         "    THE 303 SLEEPS IN ITS CIRCUIT    ", "J", BgKind::Starfield},
    }};

    // ─── 4 · TUNNEL VISION ───────────────────────────────────
    demos_[3] = {"TUNNEL VISION", {
        {"DARK",     20.0f, tunOnly(), SS::Classic,
         "    INTO THE DARK    DEEPER WE GO    "
         "    NO STARS NO POLAR ONLY THE TUNNEL    "
         "    HOLD YOUR BREATH    ", "P", BgKind::SdfTunnel},
        {"WALLS",    40.0f, tunOnly(), SS::Wavy3D,
         "    THE WALLS BREATHE    FREQUENCIES SHAPE THE TILES    "
         "    BASS WIDENS LEAD NARROWS    "
         "    THE TURN BEGINS    A SLOW CURVE    ", "P", BgKind::SdfTunnel},
        {"BENDING",  35.0f, tunOnly(), SS::Wavy3D,
         "    REALITY BENDS AROUND THE PATH    "
         "    A NEVER ENDING TORUS    "
         "    GREETINGS TO ANDROMEDA AND CONSPIRACY    ", "P",
         BgKind::SdfTunnel},
        {"OPENING",  30.0f, all(),     SS::Rainbow,
         "    THE TUNNEL OPENS UP    EVERYTHING APPEARS    "
         "    PURE LIGHT BEYOND THE WALLS    ", "F", BgKind::Tunnel},
    }};

    // ─── 5 · FREQUENCIES ─────────────────────────────────────
    demos_[4] = {"FREQUENCIES", {
        {"SILENCE",   12.0f, polSpe(), SS::Neon,
         "    LISTEN    THE SPECTRUM IS LOADING    "
         "    FFT 1024 BINS WAITING    ", "I", BgKind::PlasmaFbm},
        {"BANDS",     45.0f, polSpe(), SS::Wavy3D,
         "    20HZ TO 200HZ : BASS    "
         "    200 TO 800 : LOW MID    800 TO 3200 : MID    "
         "    3200+ : TREBLE    EVERY HZ HAS A COLOR    "
         "    NYQUIST IS WATCHING    ", "I", BgKind::PlasmaFbm},
        {"HARMONICS", 35.0f, polSpe(), SS::Mirror,
         "    EVERY NOTE A SERIES    FUNDAMENTAL PLUS OVERTONES    "
         "    THE HARMONIC LADDER NEVER ENDS    ", "I", BgKind::Truchet},
        {"FULL",      35.0f, all(),    SS::Rainbow,
         "    EVERY BAND ALIVE NOW    THE SPECTRUM IS COMPLETE    "
         "    FROM SUBSONIC TO ULTRASONIC    ", "Q", BgKind::Voronoi},
    }};

    // ─── 6 · GLITCH WORLD ────────────────────────────────────
    demos_[5] = {"GLITCH WORLD", {
        {"PROBE",     15.0f, stars(),  SS::Neon,
         "    SCANNING ANOMALY    REALITY UNSTABLE    ", "V", BgKind::Voronoi},
        {"CORRUPT",   40.0f, all(),    SS::Glitch,
         "    BUFFER OVERFLOW    SIGNAL CORRUPTED    "
         "    THE GHOSTS IN THE WIRES ARE WAKING UP    ", "V", BgKind::Voronoi},
        {"CRASH",     30.0f, all(),    SS::Glitch,
         "    KERNEL PANIC    BUT THE BEAT GOES ON    ", "Q", BgKind::Voronoi},
    }};

    // ─── 7 · AMBIENT VOID ────────────────────────────────────
    demos_[6] = {"AMBIENT VOID", {
        {"DRIFT",      40.0f, stars(),     SS::Neon,
         "    NO BEAT    JUST THE DRIFT    SLOW STARS PASSING    "
         "    SOMEWHERE BEYOND THE OORT CLOUD    ", "J", BgKind::Starfield},
        {"DEEPNESS",   45.0f, polSpe(),    SS::Mirror,
         "    THE SPECTRUM BREATHES    SLOW AND BLUE    "
         "    20HZ DRONES UNDER THE SKIN    ", "S", BgKind::PlasmaFbm},
        {"DREAM",      35.0f, polSpe(),    SS::Mirror,
         "    THE FREQUENCIES BECOME LANDSCAPE    "
         "    A FOG OF HARMONICS    GREETINGS TO ASD    ", "S",
         BgKind::PlasmaFbm},
        {"RETURN",     30.0f, starsWave(), SS::Mirror,
         "    AND BACK TO THE STARS    REMEMBER THIS QUIET    "
         "    YOU WERE HERE    YOU LISTENED    ", "J", BgKind::Starfield},
    }};

    // ─── 8 · RAVE ────────────────────────────────────────────
    demos_[7] = {"RAVE", {
        {"BUILD",     20.0f, all(),  SS::Wavy3D,
         "    180 BPM    HOLD ON    "
         "    THE WAREHOUSE IS WAITING    "
         "    SECURITY GUARD ALREADY GIVE UP    ", "T", BgKind::Twister},
        {"DROP",      25.0f, all(),  SS::Glitch,
         "    HERE WE GO    KICK PUNCH MAXIMUM    "
         "    GABBA GABBA HEY    ", "T", BgKind::Voronoi},
        {"FULL POWER",55.0f, all(),  SS::Rainbow,
         "    NO SLEEP TIL DAWN    KICK BIAS MAXIMUM    "
         "    HARDCORE NEVER DIES    GREETINGS TO ALL RAVERS    "
         "    ALSO TO RAZOR 1911 AND FAIRLIGHT    ", "T", BgKind::Truchet},
        {"AFTER",     30.0f, polSpe(), SS::Mirror,
         "    THE BEAT IS GONE    THE WALLS STILL SHAKE    "
         "    YOUR HEART STILL THINKS IT IS RAVING    ", "Q",
         BgKind::PlasmaFbm},
    }};

    // ─── 9 · MEMORY LANE ─────────────────────────────────────
    demos_[8] = {"MEMORY LANE", {
        {"REWIND",    20.0f, starsWave(), SS::Mirror,
         "    *** AESTHETIC MODE ***    SLOWING DOWN    "
         "    LET THE TAPE WHIRR    ", "U", BgKind::Rotozoom},
        {"VAPOR",     50.0f, all(),       SS::Mirror,
         "    PINK NEON ON CHROME    LOST PALACES OF THE 90S    "
         "    THIS IS HOW WE REMEMBER YOU    "
         "    GREETINGS TO TPOLM AND PLASTIC    ", "R", BgKind::Rotozoom},
        {"DREAM POOL",30.0f, all(),       SS::Mirror,
         "    POOL TILES ECHO    UNDERWATER COPPER    "
         "    SOMETHING WAITS BENEATH    ", "R", BgKind::Truchet},
        {"FOG",       30.0f, polSpe(),    SS::Mirror,
         "    THE MEMORY FADES    BUT NEVER DISAPPEARS    "
         "    UNTIL THE NEXT REWIND    ", "U", BgKind::PlasmaFbm},
    }};

    // ─── 10 · GREETINGS FROM SAILLANS ────────────────────────
    demos_[9] = {"GREETINGS", {
        {"OPENING",   20.0f, stars(),  SS::Neon,
         "    *** GREETINGS FROM SAILLANS 2026 ***    "
         "    *** AV-LIVE / L-ELECTRON RARE ***    ", "J",
         BgKind::Starfield},
        {"ROLL CALL", 60.0f, all(),    SS::Rainbow,
         "    GREETINGS TO :: KXKM CREW :: HYPNEUM LAB :: SUPERCOLLIDER ::"
         "    OPENFRAMEWORKS HACKERS :: COOKIE COLLECTIVE :: ALL LIVE CODERS    "
         "    FAIRLIGHT :: RAZOR 1911 :: ANDROMEDA :: ASD :: CONSPIRACY ::"
         "    FARBRAUSCH :: MERCURY :: TPOLM :: TBL :: LOONIES ::"
         "    THIS SCROLLER IS FOR YOU    ", "L", BgKind::Twister},
        {"DEMOSCENE", 45.0f, all(),    SS::Wavy3D,
         "    THE SCENE IS NOT DEAD    THE SCENE IS EVERYWHERE    "
         "    EVERY LIVE CODER A NEW MEMBER    "
         "    1985 - 2026 - INFINITY    ", "L", BgKind::Truchet},
        {"FINALE",    35.0f, all(),    SS::Mirror,
         "    SEE YOU NEXT TIME    KEEP THE PHOSPHOR ALIVE    "
         "    AV-LIVE / L-ELECTRON RARE    "
         "    *** WRAP *** PRESS 1-9 0 TO RESTART ***    ", "U",
         BgKind::Starfield},
    }};

    // ─── 11 · FRACTAL DREAMS (KIFS) ─────────────────────────
    demos_[10] = {"FRACTAL DREAMS", {
        {"GENESIS",   18.0f, polSpe(),  SS::Neon,
         "    *** FRACTAL DREAMS ***    BEGIN ITERATION 0    ", "J",
         BgKind::Kifs},
        {"FOLD",      35.0f, polSpe(),  SS::Wavy3D,
         "    REFLECTION OF REFLECTION OF REFLECTION    "
         "    AT EVERY SCALE THE SAME PATTERN    ", "S", BgKind::Kifs},
        {"INFINITE",  40.0f, all(),     SS::Rainbow,
         "    THE FRACTAL HAS NO END    "
         "    GREETINGS TO INIGO QUILEZ AND KNIGHTY    ", "L",
         BgKind::Kifs},
        {"COLLAPSE",  25.0f, polSpe(),  SS::Mirror,
         "    AND THE FUNCTION RESETS    BACK TO X = 0 Y = 0    ", "J",
         BgKind::Starfield},
    }};

    // ─── 12 · INFERNO (Fire) ────────────────────────────────
    demos_[11] = {"INFERNO", {
        {"SPARK",     15.0f, stars(),   SS::Glitch,
         "    *** INFERNO ***    A SPARK IGNITES    ", "T", BgKind::Fire},
        {"FLAME",     45.0f, all(),     SS::Glitch,
         "    THE FLAMES RISE    EVERY KICK FUELS THE BLAZE    "
         "    GREETINGS TO HARDCODE AND TITAN    ", "T", BgKind::Fire},
        {"BURNOUT",   35.0f, all(),     SS::Rainbow,
         "    EVERYTHING IS BURNING    NOTHING REMAINS    "
         "    KICK BIAS IS THE FUEL    ", "P", BgKind::Fire},
        {"ASHES",     25.0f, polSpe(),  SS::Mirror,
         "    THE EMBERS COOL    BUT THEY DO NOT DIE    ", "S",
         BgKind::PlasmaFbm},
    }};

    // ─── 13 · OUTRUN (Grid persp) ────────────────────────────
    demos_[12] = {"OUTRUN", {
        {"DRIVE OFF",   18.0f, all(),    SS::Neon,
         "    *** OUTRUN ***    SUNSET IGNITES THE HORIZON    ", "R",
         BgKind::GridPersp},
        {"NEON HIGHWAY",45.0f, all(),    SS::Mirror,
         "    PINK NEON ON CHROME ROAD    "
         "    1985 STILL SPEEDING    "
         "    GREETINGS TO STILL AND RGBA    ", "R",
         BgKind::GridPersp},
        {"OVERDRIVE",   35.0f, all(),    SS::Rainbow,
         "    KICKDOWN    THE VECTOR SUN BENDS    ", "T",
         BgKind::GridPersp},
        {"HORIZON",     25.0f, starsWave(), SS::Mirror,
         "    AND THE ENGINE FADES INTO THE NIGHT    ", "U",
         BgKind::Starfield},
    }};

    // ─── 14 · CUBE STORM (tunnel cubes) ──────────────────────
    demos_[13] = {"CUBE STORM", {
        {"INCOMING",  18.0f, polSpe(),   SS::Neon,
         "    *** CUBE STORM ***    SOMETHING APPROACHES    ", "Q",
         BgKind::TunnelCubes},
        {"CASCADE",   45.0f, all(),      SS::Wavy3D,
         "    THOUSANDS OF CUBES    EACH ONE A NOTE    "
         "    THEY FALL THEY FLY THEY FALL AGAIN    ", "Q",
         BgKind::TunnelCubes},
        {"GEOMETRY",  35.0f, all(),      SS::Glitch,
         "    EUCLIDEAN SPACE COLLAPSES    "
         "    GREETINGS TO FARBRAUSCH AND ANDROMEDA    ", "V",
         BgKind::TunnelCubes},
        {"ZERO",      20.0f, polSpe(),   SS::Mirror,
         "    BACK TO ORIGIN    DIMENSION COLLAPSED    ", "J",
         BgKind::Starfield},
    }};

    // ─── 15 · GRAND FINAL (mix everything) ───────────────────
    demos_[14] = {"GRAND FINAL", {
        {"OPEN",       12.0f, stars(),    SS::Neon,
         "    *** GRAND FINAL ***    ALL EFFECTS ENGAGED    ", "L",
         BgKind::Starfield},
        {"AMIGA",      18.0f, all(),      SS::Classic,
         "    AMIGA SECTION    COPPER LIST POETRY    ", "M",
         BgKind::Twister},
        {"FRACTAL",    18.0f, all(),      SS::Wavy3D,
         "    FRACTAL SECTION    INFINITE DETAIL    ", "L",
         BgKind::Kifs},
        {"FIRE",       18.0f, all(),      SS::Glitch,
         "    FIRE SECTION    BURN IT ALL DOWN    ", "T",
         BgKind::Fire},
        {"OUTRUN",     18.0f, all(),      SS::Mirror,
         "    OUTRUN SECTION    NEON HORIZON    ", "R",
         BgKind::GridPersp},
        {"CUBES",      18.0f, all(),      SS::Wavy3D,
         "    CUBE STORM    GEOMETRY ATTACK    ", "Q",
         BgKind::TunnelCubes},
        {"FAREWELL",   30.0f, all(),      SS::Rainbow,
         "    THIS IS THE GRAND FINAL    "
         "    GREETINGS TO EVERYBODY OUT THERE    "
         "    THE SCENE IS YOUR FAMILY    THE PHOSPHOR YOUR HOME    "
         "    AV-LIVE / L-ELECTRON RARE / 2026    ", "U",
         BgKind::PlasmaFbm},
    }};

    launchDemo(0);
}

void ofApp::launchDemo(int demoIdx) {
    if (demoIdx < 0 || demoIdx >= (int)demos_.size()) return;
    currentDemo_  = demoIdx;
    narrativeMode_ = true;
    enterScene(0);
    ofLogNotice("ofApp") << "launch demo " << demoIdx
                         << " : " << demos_[demoIdx].name
                         << " (" << demos_[demoIdx].scenes.size() << " scenes)";
}

void ofApp::enterScene(int idx) {
    auto& scenes = demos_[currentDemo_].scenes;
    if (idx < 0 || idx >= (int)scenes.size()) {
        // Fin de démo : reboucle sur la 1ère scène.
        idx = 0;
    }
    narrativeIdx_ = idx;
    narrativeT_   = 0.0f;
    const auto& s = scenes[idx];
    scope4_ = s.toggles;
    demo_.setScrollerStyle(s.scroller);
    demo_.setText(s.narration);
    if (s.albumLetter) {
        osc_.sendControl("/control/playAlbum", std::string(s.albumLetter));
    }
    // Transition punchy : flash blanc + glitch postfx 0.5s.
    transitionFlash_ = 1.0f;
    postfx_.triggerGlitch(0.7f, 0.45f);
}

void ofApp::updateNarrative(float dt) {
    if (transitionFlash_ > 0.0f) transitionFlash_ -= dt / 0.45f;
    if (transitionFlash_ < 0.0f) transitionFlash_ = 0.0f;
    if (!narrativeMode_) return;
    auto& scenes = demos_[currentDemo_].scenes;
    if (narrativeIdx_ >= (int)scenes.size()) return;
    narrativeT_ += dt;
    if (narrativeT_ >= scenes[narrativeIdx_].durSec) {
        if (narrativeIdx_ + 1 >= (int)scenes.size()) {
            // Fin : reboucle l'acte 0 de la même démo (loop continu).
            enterScene(0);
        } else {
            enterScene(narrativeIdx_ + 1);
        }
    }
}

void ofApp::drawNarrativeOverlay(int W, int H) {
    if (!narrativeMode_) return;
    auto& scenes = demos_[currentDemo_].scenes;
    if (narrativeIdx_ >= (int)scenes.size()) return;
    const auto& s = scenes[narrativeIdx_];
    const float prog = std::min(1.0f, narrativeT_ / s.durSec);

    ofPushStyle();
    ofEnableBlendMode(OF_BLENDMODE_ADD);

    const float fadeIn  = std::min(1.0f, narrativeT_ / 1.5f);
    const float fadeOut = std::min(1.0f, (s.durSec - narrativeT_) / 1.5f);
    const int alpha = static_cast<int>(220 * std::min(fadeIn, fadeOut));

    // Ligne 1 : nom de la démo (petit)
    const std::string demoTag = std::string("DEMO ") +
        ofToString(currentDemo_ + 1) + " / " + ofToString(demos_.size()) + "   " +
        demos_[currentDemo_].name;
    ofSetColor(140, 255, 200, alpha);
    ofDrawBitmapString(demoTag, W / 2 - demoTag.size() * 4, 18);

    // Ligne 2 : "ACT N — TITLE" en gros
    const std::string title = "ACT " + ofToString(narrativeIdx_ + 1) +
                              " / " + ofToString(scenes.size())
                              + "   " + s.name;
    ofSetColor(255, 200, 100, alpha);
    ofPushMatrix();
    ofTranslate(W / 2 - title.size() * 10, 50);
    ofScale(2.5f, 2.5f, 1.0f);
    ofDrawBitmapString(title, 0, 0);
    ofPopMatrix();

    // Barre de progression
    const float barW = W - 200;
    ofSetColor(60, 130, 80, 140);
    ofDrawRectangle(100, 70, barW, 3);
    ofSetColor(100, 220, 140, 220);
    ofDrawRectangle(100, 70, barW * prog, 3);

    // Hint clavier
    ofSetColor(200, 220, 220, 180);
    ofDrawBitmapString("[1-9 0] demo   [enter] next act   [esc] live mode",
                       100, H - 48);

    ofDisableBlendMode();
    ofPopStyle();
}

void ofApp::drawTunnelHud(int W, int H) {
    const float now = ofGetElapsedTimef();
    const float dt  = ofGetLastFrameTime();

    // Refresh : ajoute 1-2 nouveaux items toutes les ~150-400 ms et
    // remplace les expirés. Cap à 14 items simultanés.
    if (now > tunnelHudNext_) {
        tunnelHudNext_ = now + ofRandom(0.15f, 0.40f);
        const int spawn = static_cast<int>(ofRandom(1.0f, 2.99f));
        for (int s = 0; s < spawn && tunnelHud_.size() < 14; ++s) {
            HudItem it;
            // Position périphérique : on évite le quart central pour rester
            // "sur les carreaux" et pas sur le polar/spectro.
            const float ang = ofRandom(0.0f, TWO_PI);
            const float rad = ofRandom(0.34f, 0.49f);  // 0.5 = bord
            it.u = 0.5f + std::cos(ang) * rad;
            it.v = 0.5f + std::sin(ang) * rad;
            it.life  = ofRandom(0.8f, 2.5f);
            it.born  = 0.0f;
            it.scale = ofRandom(0.85f, 1.4f);
            const float hz = ofRandom(0.2f, 9.9f);
            it.text  = ofToString(hz, 1) + " Hz";
            const char* labels[] = {
                "LFO", "DC ", "DRIFT", "SUB", "MOD", "Δf",
                "PHASE", "GAIN", "BIAS", "TRIG", "PWM", "ENV"
            };
            it.label = labels[static_cast<int>(ofRandom(0, 12))];
            tunnelHud_.push_back(std::move(it));
        }
    }

    // Update + draw
    ofPushStyle();
    ofEnableBlendMode(OF_BLENDMODE_ADD);
    for (auto it = tunnelHud_.begin(); it != tunnelHud_.end(); ) {
        it->life -= dt;
        it->born += dt;
        if (it->life <= 0.0f) {
            it = tunnelHud_.erase(it);
            continue;
        }
        // Alpha : fade-in 0.2s, fade-out dernière 0.4s.
        const float fadeIn  = std::min(1.0f, it->born / 0.2f);
        const float fadeOut = std::min(1.0f, it->life / 0.4f);
        const int alpha = static_cast<int>(180 * fadeIn * fadeOut);

        const float x = it->u * W;
        const float y = it->v * H;

        // Petit cadre rectangulaire phosphor — texture "tile HUD".
        ofPushMatrix();
        ofTranslate(x, y);
        // Léger flicker scintillant
        const float jitter = std::sin(now * 30.0f + it->born * 10.0f) * 0.5f + 0.5f;
        ofSetColor(0, 200, 130, static_cast<int>(alpha * (0.4f + 0.6f * jitter)));
        ofNoFill();
        ofSetLineWidth(1);
        const float bw = 64 * it->scale;
        const float bh = 22 * it->scale;
        ofDrawRectangle(-bw * 0.5f, -bh * 0.5f, bw, bh);
        // Tick gauche (style cadran)
        ofDrawLine(-bw * 0.5f - 6, 0, -bw * 0.5f, 0);

        // Texte
        ofSetColor(120, 255, 180, alpha);
        ofDrawBitmapString(it->label, -bw * 0.5f + 4, -bh * 0.5f + 9);
        ofSetColor(80, 220, 140, alpha);
        ofDrawBitmapString(it->text,  -bw * 0.5f + 4,  bh * 0.5f - 3);
        ofPopMatrix();
        ++it;
    }
    ofDisableBlendMode();
    ofPopStyle();
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
    // Synchronise les flags du DemoFx avec ScopeToggles (touches 0-9).
    demo_.scrollerEnabled()  = scope4_.scroller;
    demo_.copperEnabled()    = scope4_.copperBars;
    demo_.bobsEnabled()      = scope4_.bobs;
    demo_.starfieldEnabled() = scope4_.starfield;

    // 1) Fond : selon scène narrative active (BgKind), sinon tunnel/starfield
    //    classique en mode live.
    BgKind bg = BgKind::Tunnel;
    if (narrativeMode_ && currentDemo_ < (int)demos_.size() &&
        narrativeIdx_ < (int)demos_[currentDemo_].scenes.size()) {
        bg = demos_[currentDemo_].scenes[narrativeIdx_].background;
    } else if (scope4_.starfield) {
        bg = BgKind::Starfield;
    } else if (!scope4_.tunnel) {
        bg = BgKind::Tunnel; // pas de fond -> tunnel skip below
    }
    switch (bg) {
        case BgKind::Tunnel:
            if (scope4_.tunnel) tunnel_->draw(0, 0, W, H);
            else                ofBackground(0);
            break;
        case BgKind::Starfield: ofBackground(0); demo_.drawStarfield(W, H); break;
        case BgKind::Metaballs: metaballs_->draw(0, 0, W, H); break;
        case BgKind::Voronoi:   voronoi_->draw(0, 0, W, H);   break;
        case BgKind::Twister:   twister_->draw(0, 0, W, H);   break;
        case BgKind::PlasmaFbm: plasmaFbm_->draw(0, 0, W, H); break;
        case BgKind::Rotozoom:  rotozoom_->draw(0, 0, W, H);  break;
        case BgKind::Truchet:   truchet_->draw(0, 0, W, H);   break;
        case BgKind::SdfTunnel: sdfTunnel_->draw(0, 0, W, H); break;
        case BgKind::Kifs:        kifs_->draw(0, 0, W, H);        break;
        case BgKind::Fire:        fire_->draw(0, 0, W, H);        break;
        case BgKind::GridPersp:   gridPersp_->draw(0, 0, W, H);   break;
        case BgKind::TunnelCubes: tunnelCubes_->draw(0, 0, W, H); break;
        case BgKind::Caustics:    caustics_->draw(0, 0, W, H);    break;
        case BgKind::Vortex:      vortex_->draw(0, 0, W, H);      break;
        case BgKind::Octahedron:  octahedron_->draw(0, 0, W, H);  break;
    }

    // 1bis) HUD pseudo-aléatoire de valeurs sub-10 Hz.
    if (scope4_.tunnelHud) drawTunnelHud(W, H);

    // 1ter) Copper bars + logo bobs.
    if (scope4_.copperBars) demo_.drawCopperBars(W, H);
    if (scope4_.bobs)       demo_.drawBobs(W, H, "AV-LIVE");

    const float cx = W * 0.5f;
    const float cy = H * 0.5f;
    const float minSide = static_cast<float>(std::min(W, H));

    // 2) Polar central — toggle 8.
    if (scope4_.polar) {
        const int polarS = static_cast<int>(minSide * 0.55f);
        polar_->draw(static_cast<int>(cx) - polarS / 2,
                     static_cast<int>(cy) - polarS / 2,
                     polarS, polarS);
    }

    // 3) Spectro ring colorisé — toggle 7.
    if (scope4_.spectroRing) {
        const float ringInner = minSide * 0.27f;
        const float ringOuter = minSide * 0.36f;
        spectro_->drawCircular(cx, cy, ringInner, ringOuter);
    }

    // 4) Lissajous additif fullscreen pour le glow ambiant (sous le scope).
    ofEnableBlendMode(OF_BLENDMODE_ADD);
    ofPushStyle();
    ofSetColor(255, 255, 255, 70);
    lissajous_->draw(0, 0, W, H);
    ofPopStyle();
    ofDisableBlendMode();

    // 4bis) Overlay des multiplicateurs FX (a→z) en bas d'écran, toujours
    //       visible — phosphor vert, en blend additif pour s'intégrer.
    {
        const auto& m = tunnel_->mults();
        ofPushStyle();
        ofEnableBlendMode(OF_BLENDMODE_ADD);
        const int rowY = H - 22;
        const int padX = 14;
        ofSetColor(0, 0, 0, 0); // pure additif, pas de fond
        struct Slot { const char* label; const char* keys; float val; };
        Slot slots[] = {
            {"SPD", "a/z", m.speed},
            {"KCK", "s/x", m.kickBoost},
            {"ROLL","d/c", m.rollAmp},
            {"PAN", "e/v", m.panAmp},
            {"CRV", "t/n", m.curveAmp},
            {"TLX", "u/m", m.tileX},
            {"TLZ", "i/l", m.tileZ},
            {"DIR", "o/h", m.dirLerp},
        };
        const int nSlots = static_cast<int>(sizeof(slots) / sizeof(Slot));
        const int slotW = (W - padX * 2) / nSlots;
        for (int i = 0; i < nSlots; ++i) {
            const int sx = padX + i * slotW;
            // Color glow par valeur : 1.0 = vert calme, > 1.0 vire ambre,
            // < 1.0 vire bleu.
            const float v = slots[i].val;
            int rC = static_cast<int>(80 + std::max(0.0f, v - 1.0f) * 120);
            int gC = 230;
            int bC = static_cast<int>(80 + std::max(0.0f, 1.0f - v) * 120);
            rC = std::min(255, rC);
            bC = std::min(255, bC);
            ofSetColor(rC, gC, bC, 200);
            ofDrawBitmapString(slots[i].label, sx, rowY);
            ofSetColor(rC, gC, bC, 140);
            ofDrawBitmapString(slots[i].keys, sx, rowY + 12);
            // Valeur en chiffre
            ofSetColor(180, 255, 180, 230);
            ofDrawBitmapString(ofToString(v, 2) + "x", sx + 28, rowY);
            // Petite barre horizontale ; centre = 1.0, extrémités 0.05 / 12
            const float barW = static_cast<float>(slotW - 12);
            const float t = std::min(1.0f, std::max(0.0f,
                std::log(v) / std::log(12.0f) * 0.5f + 0.5f));
            ofSetColor(60, 130, 80, 90);
            ofDrawRectangle(sx, rowY + 16, barW, 2);
            ofSetColor(80, 220, 140, 200);
            ofDrawRectangle(sx, rowY + 16, barW * t, 2);
            // Marqueur central (= 1.0)
            ofSetColor(120, 200, 100, 130);
            ofDrawRectangle(sx + barW * 0.5f - 0.5f, rowY + 14, 1, 6);
        }
        // Hint reset à droite + nom de la démo en cours en magenta
        ofSetColor(140, 200, 200, 180);
        ofDrawBitmapString("[w] reset", W - 100, rowY);
        if (narrativeMode_ && currentDemo_ < (int)demos_.size()) {
            ofSetColor(255, 100, 200, 200);
            ofDrawBitmapString(std::string("[") +
                ofToString(currentDemo_ + 1) + "] " +
                demos_[currentDemo_].name, W - 240, rowY - 18);
        }
        ofDisableBlendMode();
        ofPopStyle();
    }

    // 5) WAVEFORM circulaire CRT rétro — toggle 9.
    if (scope4_.waveform) {
        waveform_->setCircular(true);
        waveform_->draw(0, 0, W, H);
        waveform_->setCircular(false);
    }

    // 6) Sine scroller — toggle 3 (synchronisé avec demo_.scrollerEnabled).
    demo_.drawScroller(W, H);

    // 7) Flash de transition entre scènes (cosine ease-out 0.45s).
    if (transitionFlash_ > 0.0f) {
        ofPushStyle();
        const float t = std::max(0.0f, std::min(1.0f, transitionFlash_));
        const int alpha = static_cast<int>(180 * t * t);  // ease square
        ofSetColor(255, 240, 220, alpha);
        ofDrawRectangle(0, 0, W, H);
        ofPopStyle();
    }

    // 8) Overlay narratif (titre acte + barre progression) si actif.
    drawNarrativeOverlay(W, H);
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
    // Touches 1..9 + 0 — lance une démoparty narrative complète.
    // 'q' reste libre pour le mode live (pas de scénario auto).
    switch (key) {
        case '1': launchDemo(0); break;  // AMIGA TRIBUTE
        case '2': launchDemo(1); break;  // C64 LOWLIFE
        case '3': launchDemo(2); break;  // ACID JOURNEY
        case '4': launchDemo(3); break;  // TUNNEL VISION
        case '5': launchDemo(4); break;  // FREQUENCIES
        case '6': launchDemo(5); break;  // GLITCH WORLD
        case '7': launchDemo(6); break;  // AMBIENT VOID
        case '8': launchDemo(7); break;  // RAVE
        case '9': launchDemo(8); break;  // MEMORY LANE
        case '0': launchDemo(9); break;  // GREETINGS
        // Demos 11..15 — symboles. Shift+1..5 sur US (! @ # $ %),
        // ou les chars correspondants sur AZERTY FR.
        case '!': launchDemo(10); break;  // FRACTAL DREAMS
        case '@': launchDemo(11); break;  // INFERNO
        case '#': launchDemo(12); break;  // OUTRUN
        case '$': launchDemo(13); break;  // CUBE STORM
        case '%': launchDemo(14); break;  // GRAND FINAL

        // Skip à la scène suivante de la démo en cours.
        case OF_KEY_RETURN:
            if (narrativeMode_) enterScene(narrativeIdx_ + 1);
            break;
        // Sortir du mode narratif (mode live).
        case 'q':
        case OF_KEY_ESC:
            narrativeMode_ = false;
            demo_.setText("");
            break;
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

        // FX live — multiplicateurs tunnel par paires (down/up). Chaque
        // pression scale ×0.83 (down) ou ×1.20 (up). Clamp 0.05..12.
        // 'w' = reset all to 1.0 (n'écrase pas qwerty mode_ déjà mappés).
        case 'a': case 'z': case 's': case 'x':
        case 'd': case 'c': case 'e': case 'v':
        case 't': case 'n': case 'u': case 'm':
        case 'i': case 'l': case 'o': case 'h':
        case 'j': case 'y':
        case 'w': {
            auto m = tunnel_->mults();
            auto bump = [](float v, bool up) {
                v *= up ? 1.20f : 0.83f;
                return std::max(0.05f, std::min(12.0f, v));
            };
            switch (key) {
                case 'a': m.speed     = bump(m.speed,     false); break;
                case 'z': m.speed     = bump(m.speed,     true);  break;
                case 's': m.kickBoost = bump(m.kickBoost, false); break;
                case 'x': m.kickBoost = bump(m.kickBoost, true);  break;
                case 'd': m.rollAmp   = bump(m.rollAmp,   false); break;
                case 'c': m.rollAmp   = bump(m.rollAmp,   true);  break;
                case 'e': m.panAmp    = bump(m.panAmp,    false); break;
                case 'v': m.panAmp    = bump(m.panAmp,    true);  break;
                case 't': m.curveAmp  = bump(m.curveAmp,  false); break;
                case 'n': m.curveAmp  = bump(m.curveAmp,  true);  break;
                case 'u': m.tileX     = bump(m.tileX,     false); break;
                case 'm': m.tileX     = bump(m.tileX,     true);  break;
                case 'i': m.tileZ     = bump(m.tileZ,     false); break;
                case 'l': m.tileZ     = bump(m.tileZ,     true);  break;
                case 'o': m.dirLerp   = bump(m.dirLerp,   false); break;
                case 'h': m.dirLerp   = bump(m.dirLerp,   true);  break;
                case 'j': m.speed     = bump(m.speed,     false);
                          m.kickBoost = bump(m.kickBoost, false); break;
                case 'y': m.speed     = bump(m.speed,     true);
                          m.kickBoost = bump(m.kickBoost, true);  break;
                case 'w': m = oscope::TunnelVis::Mults{};         break;
            }
            tunnel_->setMults(m);
            break;
        }
        default: break;
    }
}
