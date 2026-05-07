#pragma once

// Orchestrateur principal :
// - démarre le scope Hantek + thread USB
// - démarre le client OSC
// - gère le mode courant (8 visualizers + Hybrid)
// - applique la chaîne PostFx avant l'écran (chromatic ab, bloom,
//   scanlines, glitch, feedback, kaleido, etc.)

#include "ofMain.h"
#include "ofxGui.h"

#include "DemoFx.h"
#include "HantekDevice.h"
#include "OscClient.h"
#include "PostFx.h"
#include "visualizers/LissajousVis.h"
#include "visualizers/ReactiveVis.h"
#include "visualizers/SpectrogramVis.h"
#include "visualizers/WaveformVis.h"
#include "visualizers/PolarVis.h"
#include "visualizers/PlasmaVis.h"
#include "visualizers/ParticleVis.h"
#include "visualizers/KaleidoVis.h"
#include "visualizers/TunnelVis.h"
#include "visualizers/MeshVis.h"
#include "visualizers/ShaderVis.h"
#include "visualizers/VectorCubesVis.h"
#include "visualizers/ModelVis.h"
#include "visualizers/SphereWaveVis.h"

#include <memory>

class ofApp : public ofBaseApp {
public:
    enum class Mode {
        Lissajous, Spectrogram, Reactive, Waveform,
        Polar, Plasma, Particles, Kaleido,
        Tunnel, Mesh,
        Scope4,   // waveform + spectrogram + polar pulsing + lissajous
        Hybrid
    };

    void setup() override;
    void update() override;
    void draw() override;
    void exit() override;
    void keyPressed(int key) override;
    void windowResized(int w, int h) override;

private:
    void loadSettings();
    void drawHud();
    void drawMode(Mode m, int x, int y, int w, int h);
    void drawHybrid(int W, int H);
    void drawScope4(int W, int H);
    void drawPanelLabel(int x, int y, const char* title, const std::string& metric);
    void drawTunnelHud(int W, int H);

    // HUD pseudo-aléatoire sur les "carreaux" du tunnel : labels Hz < 10
    // (composantes LF / sub-bass extraites de la magnitude FFT).
    struct HudItem {
        float u, v;       // pos écran 0..1
        float life;       // secondes restantes
        float born;       // âge total pour fade-in
        float scale;
        std::string text;
        std::string label;
    };
    std::vector<HudItem> tunnelHud_;
    float tunnelHudNext_ = 0.0f;
    void applyOscFx();

    oscope::HantekDevice scope_;
    oscope::OscClient osc_;
    oscope::PostFx postfx_;
    oscope::AudioAnalyzer audio_;
    oscope::DemoFx demo_;

    // Toggles Scope4 — modulés par les presets demoparty 0-9.
    struct ScopeToggles {
        bool tunnel       = true;
        bool starfield    = false;
        bool scroller     = true;
        bool copperBars   = true;
        bool bobs         = true;
        bool tunnelHud    = true;
        bool spectroRing  = true;
        bool polar        = true;
        bool waveform     = true;
    } scope4_;

    // 10 démoparties narratives multi-actes (touches 1..9 + 0).
    // Chaque démo = liste de scènes qui défilent dans le temps avec
    // narration scénarisée + track SC + transitions.
    enum class BgKind { Tunnel, Starfield, Metaballs, Voronoi, Twister,
                        PlasmaFbm, Rotozoom, Truchet, SdfTunnel,
                        Kifs, Fire, GridPersp, TunnelCubes,
                        Caustics, Vortex, Octahedron, VectorCubes,
                        Mobius, Klein, TrefoilTube, TwistedTorus, Lucy,
                        Helix, Catenoid, Hyperboloid, Boys, Lemniscate,
                        Penrose, Sphere3D, IcoMesh, DodMesh, TorusMesh,
                        Supershape, Lorenz, Hopf, Enneper, HopfLink,
                        BoingBall, Mode7, PlasmaC64, DotTunnel,
                        Gear, Cone, Pyramid, Rose3d, Geosphere, DNA,
                        Workbench, MacOSClassic, AtariFuji, OceanLoader, Win95,
                        SphereWave };
    struct DemoScene {
        const char*           name;
        float                 durSec;
        ScopeToggles          toggles;
        oscope::ScrollerStyle scroller;
        const char*           narration;
        const char*           albumLetter;
        BgKind                background = BgKind::Tunnel;
    };
    struct Demo {
        const char*            name;
        std::vector<DemoScene> scenes;
    };
    std::vector<Demo> demos_;
    int   currentDemo_   = 0;
    int   narrativeIdx_  = 0;
    float narrativeT_    = 0.0f;
    bool  narrativeMode_ = false;
    float transitionFlash_ = 0.0f;   // 1.0 au début d'une scène, decay vers 0

    // Transitions FBO entre scènes (crossfade / dissolve / wipe)
    enum class TransKind { Crossfade, Dissolve, Wipe };
    ofFbo  sceneFbo_[2];           // ping-pong : prev + cur
    int    sceneFboIdx_   = 0;     // index courant
    bool   sceneFboReady_ = false;
    float  transitionT_   = 1.0f;  // 0..1, =1 quand pas de transition active
    float  transitionDur_ = 0.7f;  // secondes
    TransKind transKind_  = TransKind::Crossfade;
    ofShader transShader_[3];      // crossfade / dissolve / wipe

    // Beat-sync : queue une démo, fire au prochain kick
    bool   beatSyncEnabled_ = false;
    int    pendingDemoIdx_  = -1;
    float  prevKick_        = 0.0f;

    // Live FX selector : une lettre sélectionne un paramètre, flèches
    // haut/bas pour ajuster la valeur du paramètre sélectionné.
    int  selectedFx_ = 0;   // 0..16, index du paramètre FX live actif
    BgKind liveBg_ = BgKind::Tunnel;     // override du fond en mode live
    bool   liveBgOverride_ = false;      // true = utiliser liveBg_

    void   initTransitions();
    void   beginTransition();
    void   drawTransitionComposite(int W, int H);

    void initDemos();
    void launchDemo(int demoIdx);
    void enterScene(int sceneIdx);
    void updateNarrative(float dt);
    void drawNarrativeOverlay(int W, int H);

    std::unique_ptr<oscope::LissajousVis>   lissajous_;
    std::unique_ptr<oscope::SpectrogramVis> spectro_;
    std::unique_ptr<oscope::ReactiveVis>    reactive_;
    std::unique_ptr<oscope::WaveformVis>    waveform_;
    std::unique_ptr<oscope::PolarVis>       polar_;
    std::unique_ptr<oscope::PlasmaVis>      plasma_;
    std::unique_ptr<oscope::ParticleVis>    particles_;
    std::unique_ptr<oscope::KaleidoVis>     kaleido_;
    std::unique_ptr<oscope::TunnelVis>      tunnel_;
    std::unique_ptr<oscope::MeshVis>        mesh_;
    // Demoscene fullscreen FX (shader-based, frag-only).
    std::unique_ptr<oscope::ShaderVis>      metaballs_;
    std::unique_ptr<oscope::ShaderVis>      voronoi_;
    std::unique_ptr<oscope::ShaderVis>      twister_;
    std::unique_ptr<oscope::ShaderVis>      plasmaFbm_;
    std::unique_ptr<oscope::ShaderVis>      rotozoom_;
    std::unique_ptr<oscope::ShaderVis>      truchet_;
    std::unique_ptr<oscope::ShaderVis>      sdfTunnel_;
    std::unique_ptr<oscope::ShaderVis>      kifs_;
    std::unique_ptr<oscope::ShaderVis>      fire_;
    std::unique_ptr<oscope::ShaderVis>      gridPersp_;
    std::unique_ptr<oscope::ShaderVis>      tunnelCubes_;
    std::unique_ptr<oscope::ShaderVis>      caustics_;
    std::unique_ptr<oscope::ShaderVis>      vortex_;
    std::unique_ptr<oscope::ShaderVis>      octahedron_;
    std::unique_ptr<oscope::VectorCubesVis> vectorCubes_;
    // 3D models (.ply) — formes paramétriques type Escher / Möbius / Klein
    std::unique_ptr<oscope::ModelVis> modelMobius_;
    std::unique_ptr<oscope::ModelVis> modelKlein_;
    std::unique_ptr<oscope::ModelVis> modelTrefoil_;
    std::unique_ptr<oscope::ModelVis> modelTwistedTorus_;
    std::unique_ptr<oscope::ModelVis> modelLucy_;
    std::unique_ptr<oscope::ModelVis> modelHelix_;
    std::unique_ptr<oscope::ModelVis> modelCatenoid_;
    std::unique_ptr<oscope::ModelVis> modelHyperboloid_;
    std::unique_ptr<oscope::ModelVis> modelBoys_;
    std::unique_ptr<oscope::ModelVis> modelLemniscate_;
    std::unique_ptr<oscope::ModelVis> modelPenrose_;
    std::unique_ptr<oscope::ModelVis> modelSphere_;
    std::unique_ptr<oscope::ModelVis> modelIco_;
    std::unique_ptr<oscope::ModelVis> modelDod_;
    std::unique_ptr<oscope::ModelVis> modelTorus_;
    std::unique_ptr<oscope::ModelVis> modelSupershape_;
    std::unique_ptr<oscope::ModelVis> modelLorenz_;
    std::unique_ptr<oscope::ModelVis> modelHopf_;
    std::unique_ptr<oscope::ModelVis> modelEnneper_;
    std::unique_ptr<oscope::ModelVis> modelHopfLink_;
    std::unique_ptr<oscope::ShaderVis> boing_;
    std::unique_ptr<oscope::ShaderVis> mode7_;
    std::unique_ptr<oscope::ShaderVis> plasmaC64_;
    std::unique_ptr<oscope::ShaderVis> dotTunnel_;
    std::unique_ptr<oscope::ModelVis> modelGear_;
    std::unique_ptr<oscope::ModelVis> modelCone_;
    std::unique_ptr<oscope::ModelVis> modelPyramid_;
    std::unique_ptr<oscope::ModelVis> modelRose_;
    std::unique_ptr<oscope::ModelVis> modelGeosphere_;
    std::unique_ptr<oscope::ModelVis> modelDNA_;
    std::unique_ptr<oscope::ShaderVis> workbench_;
    std::unique_ptr<oscope::ShaderVis> macosClassic_;
    std::unique_ptr<oscope::ShaderVis> atariFuji_;
    std::unique_ptr<oscope::ShaderVis> oceanLoader_;
    std::unique_ptr<oscope::ShaderVis> win95_;
    std::unique_ptr<oscope::SphereWaveVis> sphereWave_;

    std::vector<float> ch1_, ch2_;
    Mode mode_ = Mode::Scope4;
    bool showGui_ = true;
    bool fullscreen_ = false;
    bool postFxEnabled_ = true;
    bool autoGlitchOnKick_ = true;

    // GUI - scope
    ofxPanel gui_;
    ofxFloatSlider gainCh1_, gainCh2_;
    ofxFloatSlider trailFade_;
    ofxIntSlider sampleRateHz_;
    ofxFloatSlider timeMsPerDiv_;
    ofxFloatSlider slowMsPerDiv_;
    ofxToggle      slowOverlayEnabled_;
    ofxFloatSlider scrollSpeed_;
    int   lastSampleRateApplied_ = 0;
    int   pendingSampleRate_     = 0;
    float pendingSampleRateAt_   = 0.0f;
    ofxLabel scopeStatusLabel_;
    ofxLabel oscStatusLabel_;
    ofxLabel modeLabel_;

    // GUI - postfx
    ofxPanel fxGui_;
    ofxFloatSlider fxChroma_, fxBloom_, fxRgbShift_, fxSat_;
    ofxFloatSlider fxScan_, fxVignette_, fxGrain_, fxPixelate_;
    ofxFloatSlider fxKaleido_, fxFeedback_, fxFbZoom_, fxFbRot_;
    ofxFloatSlider fxGlitch_, fxGlitchProb_;
    ofxToggle      fxEnableToggle_;

    // Settings persistants.
    int oscListenPort_ = 57122;
    std::string oscSendHost_ = "127.0.0.1";
    int oscSendPort_ = 57121;
    int bufferSize_ = 4096;
};
