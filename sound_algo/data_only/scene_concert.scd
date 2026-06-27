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
~ccPose = {
    var kin = ~poseKin.notNil.if({ ~poseKin.values.detect({ |v| v.notNil }) });
    var st  = ~poseState.notNil.if({ ~poseState.values.detect({ |v| v.notNil }) });
    var ctr = ~poseCenter.notNil.if({ ~poseCenter.values.detect({ |v| v.notNil }) });
    (kin: (kin ? ()), state: (st ? ()), center: (ctr ? ()),
     hands: (~handFeat ? ()), hasBody: kin.notNil);
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
    var hf = pose[\hands];
    var crossed = pose[\hasBody] and: {
        ((hf[\rx] ? 0.5) < ((hf[\lx] ? 0.5) - 0.08))
        and: { (hf[\ry] ? 0).inRange(0.25, 0.75) }
        and: { (hf[\ly] ? 0).inRange(0.25, 0.75) }
    };
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
