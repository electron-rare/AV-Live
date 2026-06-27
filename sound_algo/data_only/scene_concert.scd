// =====================================================================
//  data_only/scene_concert.scd -- moteur de concert (setlist techno).
//  Setlist sequentielle, geste bras-croises = morceau suivant, crossfade.
//  Active via ~doScene.(\concert). Les morceaux s'enregistrent via
//  ~concertAdd depuis morceaux/NN_*.scd (charges apres ce fichier).
// =====================================================================
(
~ccCtlDur   = 0.05;   // periode du tick de controle, en BEATS
~ccCrossHold = 1.5;   // duree de maintien du geste bras-croises (s)
~ccCrossCool = 3.0;   // cooldown apres declenchement (s)

// -- snapshot pose (premiere personne), tout nil-garde --
// Wrist-derived hand-features. At full-body (concert) distance MediaPipe can't
// see the hands (/pose/hands all zero), but the body WRISTS are tracked. We
// shape the wrists exactly like ~handFeat so every morceau (which reads
// pose[\hands]) is driven by the arms transparently — no morceau changes.
// openness -> arm spread ; speed -> per-tick wrist motion (gain'd into a usable
// range, tune thresholds live).
~ccWristFeat = {
    var w = (~poseWrist.notNil.if({ ~poseWrist.values.detect({ |v| v.notNil }) })) ? ();
    var lx = (w[\lx] ? 0.5); var ly = (w[\ly] ? 0.5);
    var rx = (w[\rx] ? 0.5); var ry = (w[\ry] ? 0.5);
    var spread = (rx - lx).abs;
    var rsp = 0; var lsp = 0; var prev = ~concert[\wprev];
    if(prev.notNil) {
        rsp = (((rx - prev[\rx]).squared + (ry - prev[\ry]).squared).sqrt * 8).min(1);
        lsp = (((lx - prev[\lx]).squared + (ly - prev[\ly]).squared).sqrt * 8).min(1);
    };
    ~concert[\wprev] = (lx: lx, ly: ly, rx: rx, ry: ry);
    (lx: lx, ly: ly, rx: rx, ry: ry,
     lopen: spread, ropen: spread, lspeed: lsp, rspeed: rsp, dist: spread);
};
~ccPose = {
    var kin = ~poseKin.notNil.if({ ~poseKin.values.detect({ |v| v.notNil }) });
    var st  = ~poseState.notNil.if({ ~poseState.values.detect({ |v| v.notNil }) });
    var ctr = ~poseCenter.notNil.if({ ~poseCenter.values.detect({ |v| v.notNil }) });
    var hf  = ~handFeat ? ();
    var handsLive = ((hf[\rx] ? 0) > 0.001) or: { (hf[\lx] ? 0) > 0.001 };
    var hands = handsLive.if({ hf }, { ~ccWristFeat.value });
    (kin: (kin ? ()), state: (st ? ()), center: (ctr ? ()),
     hands: hands, hasBody: kin.notNil);
};

// -- registre des morceaux --
~concert = ~concert ? ();
~concert[\morceaux] = [];
~concertAdd = { |m| ~concert[\morceaux] = ~concert[\morceaux].add(m) };

~concert[\running]  = false;
~concert[\idx]      = 0;
~concert[\clock]    = nil;
~concert[\routine]  = nil;
~concert[\ctx]      = nil;       // (m: module, ctx: scratch) du morceau courant
~concert[\crossT]   = 0.0;
~concert[\lastFire] = -100.0;

~concert[\startMorceau] = { |i|
    var m = ~concert[\morceaux][i];
    var ctx = ();
    m[\start].(ctx);
    ~concert[\ctx] = (m: m, ctx: ctx);
    ("[concert] " ++ (i + 1) ++ "/" ++ ~concert[\morceaux].size
        ++ " : " ++ m[\name]).postln;
};

~concert[\stopMorceau] = {
    ~concert[\ctx] !? { |c| c[\m][\stop].(c[\ctx]) };
    ~concert[\ctx] = nil;
};

~concert[\next] = {
    if(~concert[\idx] < (~concert[\morceaux].size - 1)) {
        ~concert[\stopMorceau].();              // fade out (stop releve les gates)
        ~concert[\idx] = ~concert[\idx] + 1;
        ~concert[\startMorceau].(~concert[\idx]);  // fade in
    } {
        "[concert] derniere piste (fin de set)".postln;
    };
};

// geste bras-croises : main D a gauche de main G, a mi-hauteur, maintenu
~concert[\detectCross] = { |pose, now|
    // Detect via BODY WRISTS (skeleton), not hands: at full-body distance the
    // hands aren't detected and crossing occludes them. Clear X cross = the
    // right wrist swaps to the LEFT of the left wrist. Require the performer
    // centered (not at a frame edge) + wrists at chest height.
    var w = (~poseWrist.notNil.if({ ~poseWrist.values.detect({ |v| v.notNil }) })) ? ();
    var lx = (w[\lx] ? 0.5); var rx = (w[\rx] ? 0.5);
    var ly = (w[\ly] ? 0.5); var ry = (w[\ry] ? 0.5);
    var centered = (lx > 0.15) and: { lx < 0.85 } and: { rx > 0.15 } and: { rx < 0.85 };
    var midH = (ly > 0.2) and: { ly < 0.85 } and: { ry > 0.2 } and: { ry < 0.85 };
    var crossed = pose[\hasBody] and: { centered } and: { midH }
        and: { rx < (lx - 0.10) };
    if(crossed) {
        if(~concert[\crossT] <= 0) { ~concert[\crossT] = now };
        if(((now - ~concert[\crossT]) >= ~ccCrossHold)
            and: { (now - ~concert[\lastFire]) > ~ccCrossCool }) {
            ~concert[\lastFire] = now;
            ~concert[\crossT] = 0;
            ~concert[\next].();
        };
    } { ~concert[\crossT] = 0 };
};

~concert[\start] = {
    if(~concert[\running]) { "[concert] deja en cours".postln } {
        if(~concert[\morceaux].size < 1) {
            "[concert] aucun morceau enregistre".warn;
        } {
            ~concert[\running] = true;
            ~concert[\idx] = 0;
            ~concert[\clock] = TempoClock(126/60).permanent_(true);
            ~concert[\startMorceau].(0);
            ~concert[\routine] = Routine({
                var beat = 0;
                inf.do {
                    var pose = ~ccPose.value;
                    var now = thisThread.seconds;
                    var c;
                    ~concert[\detectCross].(pose, now);
                    c = ~concert[\ctx];          // relire (next a pu permuter)
                    c !? { |cc|
                        cc[\m][\update].(cc[\ctx], pose);
                        cc[\m][\tick] !? { |t| t.(cc[\ctx], pose, beat) };
                    };
                    beat = beat + 1;
                    ~ccCtlDur.wait;
                };
            }).play(~concert[\clock]);
            "[concert] STARTED".postln;
        };
    };
};

~concert[\stop] = {
    ~concert[\routine] !? { |r| r.stop };
    ~concert[\stopMorceau].();
    ~concert[\clock] !? { |c| c.stop };
    ~concert[\clock] = nil;
    ~concert[\running] = false;
    "[concert] STOPPED".postln;
};

~doSceneConcert = {
    ~concert[\start].();
    ~doRegisterPriv.(\concert, { ~concert[\stop].() });
};

"[data-only/scene_concert] engine ready".postln;
)
