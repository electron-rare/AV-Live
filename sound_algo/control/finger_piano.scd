// =====================================================================
//  control/finger_piano.scd  --  Air-piano : doigts iPhone -> notes SC
//
//  Recoit /pose/finger (emis par data_only_viz quand FINGER_PIANO=1) :
//    /pose/finger <pid> <hand> <finger> <strikeSpeed> <z> <tipx> <tipy>
//  Chaque doigt = un degre de gamme. La position de main decale l'octave,
//  la vitesse de frappe donne la velocite. Module aussi des params globaux
//  depuis l'ecart des mains (~handFeat[\dist]).
//
//  NOTE : ~fpOff coupe UNIQUEMENT le declenchement des notes. La
//  modulation continue (~fpModTick) tourne des que le fichier est charge,
//  via le hook dans data_feeds.scd \poseHands (sorties sur ~fpCutBus/~fpFxBus).
//
//  Charge par data_only/boot.scd et boot.data-only.scd apres data_feeds.scd.
//  Un seul bloc top-level (compatible .load).
// =====================================================================
(
// ---------- ETAT / CONFIG (idempotent : ne reset pas si deja defini) ----
~fpEnabled   = ~fpEnabled   ? false;
~fpDebug     = ~fpDebug     ? false;      // postln chaque frappe/pincement
~fpMode      = ~fpMode      ? \clips;     // \clips | \piano | \both
// Chemin du fichier pour /control/fp reload (iteration clips sans reboot SC).
if(~repoRoot.notNil) { ~fpSelfPath = ~repoRoot ++ "control/finger_piano.scd" };
~fpInst      = ~fpInst      ? \live;      // \live = suit ~melodyInst
~fpScaleName = ~fpScaleName ? \minorPent; // nom de gamme dans ~scales
~fpRoot      = ~fpRoot      ? 60;         // fondamentale MIDI
~fpMap       = ~fpMap       ? [[0,1,2,3,4], [0,1,2,3,4]];  // [L, R] degres
~fpHandOct   = ~fpHandOct   ? [0, 12];    // L octave basse, R +1 octave
~fpBaseOct   = ~fpBaseOct   ? 0;          // octaves globales en plus
~fpOctSpan   = ~fpOctSpan   ? 1;          // +/- octaves selon x de la main
~fpSens      = ~fpSens      ? 1.0;
~fpVelSource = ~fpVelSource ? \strike;    // \strike ou \z
~fpHold      = ~fpHold      ? 0.35;       // duree avant gate=0 (sec)
~fpAmp       = ~fpAmp       ? 0.3;
~fpCut       = ~fpCut       ? 0.0;
~fpFx        = ~fpFx        ? 0.0;

// Bus de modulation continue (sorties a mapper sur un synth/param).
if(~fpCutBus.isNil and: { s.serverRunning }) {
    ~fpCutBus = Bus.control(s, 1);
    ~fpFxBus  = Bus.control(s, 1);
};


// ---------- RESOLUTION (pure, testable) ---------------------------------
~fpResolveInst = {
    if(~fpInst == \live or: { ~fpInst.isNil }) { ~melodyInst ? \pluck }
    { ~fpInst };
};

~fpResolve = { |hand, finger, strikeSpeed = 1.0, z = 0.0, tipx = 0.5, tipy = 0.5|
    var deg, handX, octFromX, transpose, note, vel, amp;
    deg = ~fpMap[hand][finger] ? 0;
    handX = if(hand == 0) { ~handFeat[\lx] ? 0.5 } { ~handFeat[\rx] ? 0.5 };
    // x autour de 0.5 -> +/- ~fpOctSpan octaves
    octFromX = ((handX - 0.5) * 2 * ~fpOctSpan).round(1.0).asInteger;
    transpose = (~fpHandOct[hand] ? 0) + (~fpBaseOct * 12) + (octFromX * 12);
    note = ~noteFor.(deg, ~fpScaleName, ~fpRoot, transpose div: 12);
    vel = if(~fpVelSource == \z) { z } { strikeSpeed };
    amp = (~fpAmp * (0.25 + (0.75 * vel)) * ~fpSens).clip(0.0, 1.0);
    (note: note, freq: note.midicps, amp: amp, inst: ~fpResolveInst.());
};

// ---------- MODULATION CONTINUE -----------------------------------------
// dist (0..1) -> cutoff exp 200..6000 Hz ; mean Y (0..1) -> fx 0..1
~fpModTick = {
    var dist, meanY, cutHz, fx;
    dist  = (~handFeat[\dist] ? 0.0).clip(0.0, 1.0);
    meanY = (((~handFeat[\ly] ? 0.5) + (~handFeat[\ry] ? 0.5)) * 0.5)
              .clip(0.0, 1.0);
    // lissage one-pole
    ~fpCut = ~fpCut + (0.2 * (dist - ~fpCut));
    ~fpFx  = ~fpFx  + (0.2 * (meanY - ~fpFx));
    cutHz = (200 * (30 ** ~fpCut));     // 200 -> 6000 Hz
    fx = ~fpFx;
    if(~fpCutBus.notNil) { ~fpCutBus.set(cutHz) };
    if(~fpFxBus.notNil)  { ~fpFxBus.set(fx) };
};

// ---------- OSC : declenchement note ------------------------------------
OSCdef(\poseFinger, { |msg|
    var ev, syn;
    if((~fpEnabled == true) and: { (~fpMode == \piano) or: { ~fpMode == \both } }) {
        // msg = [/pose/finger, pid, hand, finger, strikeSpeed, z, tipx, tipy]
        ev = ~fpResolve.(msg[2].asInteger, msg[3].asInteger,
                         msg[4], msg[5], msg[6], msg[7]);
        if(~fpDebug == true) {
            ("[fp] strike h" ++ msg[2].asInteger ++ " f" ++ msg[3].asInteger
                ++ " -> note " ++ ev[\note] ++ " amp " ++ ev[\amp].round(0.01)).postln;
        };
        if(s.serverRunning) {
            syn = Synth(ev[\inst], [\freq, ev[\freq], \amp, ev[\amp], \gate, 1]);
            SystemClock.sched(~fpHold, { syn.set(\gate, 0); nil });
        };
    };
}, '/pose/finger');

// ---------- CLIPS : pincement pouce+doigt -> arme un pattern launchpad ---
// Reutilise les patterns concert de launchpad.scd (sons soignes, sync
// horloge concert, volumes par voie, feedback surface) via ~lpArm, au lieu
// de reinventer des boucles. 8 clips = 2 mains x 4 doigts (index..auric.).
// ~lpArm / ~lp sont definis dans launchpad.scd (charge APRES ce fichier) :
// la reference est runtime, nil-guardee.
~fpClipMap = ~fpClipMap ? [
    [\kick, \hats, \clap, \sub],    // main G : fondation rythmique
    [\acid, \arp,  \lead, \pad]     // main D : mouvement / harmonie
];

~fpStopClips = {
    if(~lp.notNil and: { ~lpArm.notNil }) {
        ~lp[\armed].copy.do { |nm| ~lpArm.(nm, false) };
        "[fp] all clips OFF".postln;
    };
};

~fpToggleClip = { |hand, finger|
    var name = (~fpClipMap[hand] ? []).at(finger - 1);
    if(name.notNil and: { ~lpArm.notNil and: { ~lp.notNil } }) {
        var on = ~lp[\armed].includes(name.asSymbol).not;   // toggle
        ~lpArm.(name, on);
        ("[fp] clip " ++ name ++ on.if({ " ON" }, { " OFF" })).postln;
    } {
        ("[fp] launchpad absent (h" ++ hand ++ " f" ++ finger ++ ")").postln;
    };
};

OSCdef(\posePinch, { |msg|
    // msg = [/pose/pinch, pid, hand, finger(1..4)]
    if((~fpEnabled == true) and: { (~fpMode == \clips) or: { ~fpMode == \both } }) {
        if(~fpDebug == true) {
            ("[fp] pinch h" ++ msg[2].asInteger ++ " f" ++ msg[3].asInteger).postln;
        };
        ~fpToggleClip.(msg[2].asInteger, msg[3].asInteger);
    };
}, '/pose/pinch');

// ---------- API LIVE (env-direct wrappers) ------------------------------
~fpOn        = { ~fpEnabled = true;  "[fp] air-piano ON".postln; };
~fpOff       = { ~fpEnabled = false; ~fpStopClips.value; "[fp] OFF".postln; };
// ATTENTION : choisir un SynthDef gate/doneAction:2 (ex \pluck, \lead).
// Un SynthDef sans gate ne sera jamais libere par le gate=0 differe -> note bloquee.
~fpInst_     = { |sym| ~fpInst = sym; ("[fp] inst = " ++ sym).postln; };
~fpScale_    = { |name|
    (~scales[name].notNil).if({ ~fpScaleName = name });
    ("[fp] scale = " ++ ~fpScaleName).postln;
};
~fpSens_     = { |v| ~fpSens = v; };
~fpOctave_   = { |n| ~fpBaseOct = n; };
~fpVelSource_ = { |sym| ~fpVelSource = sym; };

// ---------- CONTROLE OSC DISTANT (concert / sclang headless) ------------
// /control/fp <cmd> [arg] : on, off, debug 0|1, scale <nom>, inst <nom>,
//   sens <f>, octave <n>, velsrc <strike|z>
OSCdef(\fpCtl, { |msg|
    var cmd = msg[1].asSymbol;
    case
    { cmd == \on }     { ~fpEnabled = true;  "[fp] ON (osc)".postln; }
    { cmd == \off }    { ~fpEnabled = false; "[fp] OFF (osc)".postln; }
    { cmd == \debug }  { ~fpDebug = (msg[2] ? 1) > 0;
                         ("[fp] debug = " ++ ~fpDebug).postln; }
    { cmd == \scale }  { ~fpScale_.(msg[2].asSymbol); }
    { cmd == \inst }   { ~fpInst_.(msg[2].asSymbol); }
    { cmd == \sens }   { ~fpSens = msg[2]; }
    { cmd == \octave } { ~fpBaseOct = msg[2].asInteger; }
    { cmd == \velsrc } { ~fpVelSource = msg[2].asSymbol; }
    { cmd == \mode }   { ~fpMode = msg[2].asSymbol;
                         ("[fp] mode = " ++ ~fpMode).postln; }
    { cmd == \clipsoff }{ ~fpStopClips.value; }
    { cmd == \reload } { ~fpSelfPath !? { |p| p.load;
                         ("[fp] reloaded " ++ p).postln }; }
    { cmd == \bpm }    { ~setTempo.(msg[2]);
                         ("[fp] bpm = " ++ msg[2]).postln; }
    { true }           { ("[fp] cmd OSC inconnue: " ++ cmd).postln; };
}, '/control/fp');

"[OK] finger_piano : mode=clips, pincement pouce+doigt -> toggle boucle".postln;
"[OK] finger_piano OSC : /control/fp on|off|mode clips|piano|both|bpm <n>|clipsoff".postln;
)
