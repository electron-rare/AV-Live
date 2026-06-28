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
~fpDebug     = ~fpDebug     ? false;      // postln chaque frappe recue
~fpInst      = ~fpInst      ? \live;      // \live = suit ~melodyInst
// Fallback embarque : en mode data-only, palette/scales.scd n'est pas
// charge, donc ~scaleMinorPent est nil. On garantit une gamme valide.
~fpScaleArr  = ~fpScaleArr  ? (~scaleMinorPent ? [60, 63, 65, 67, 70, 72, 75, 79]);
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

// Gammes nommees accessibles via ~fpScale_
// Gammes nommees (fallback embarque si palette/scales.scd absent).
~fpScales = (
    minorPent: ~scaleMinorPent ? [60, 63, 65, 67, 70, 72, 75, 79],
    minor:     ~scaleMinor     ? [60, 62, 63, 65, 67, 68, 70, 72],
    dorian:    ~scaleDorian    ? [60, 62, 63, 65, 67, 69, 70, 72],
    phrygian:  ~scalePhrygian  ? [60, 61, 63, 65, 67, 68, 70, 72],
    blues:     ~scaleBlues     ? [60, 63, 65, 66, 67, 70, 72, 75],
    japanese:  ~scaleJapanese  ? [60, 62, 65, 67, 69, 72, 74, 77],
    hijaz:     ~scaleHijaz     ? [60, 61, 64, 65, 67, 68, 70, 72],
    hirajoshi: ~scaleHirajoshi ? [60, 62, 63, 67, 68, 72, 74, 75]
);

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
    note = ((~fpScaleArr ? [60, 63, 65, 67, 70, 72, 75, 79]).wrapAt(deg)
        + transpose).asInteger;
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
    if(~fpEnabled == true) {
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

// ---------- API LIVE (env-direct wrappers) ------------------------------
~fpOn        = { ~fpEnabled = true;  "[fp] air-piano ON".postln; };
~fpOff       = { ~fpEnabled = false; "[fp] air-piano OFF".postln; };
// ATTENTION : choisir un SynthDef gate/doneAction:2 (ex \pluck, \lead).
// Un SynthDef sans gate ne sera jamais libere par le gate=0 differe -> note bloquee.
~fpInst_     = { |sym| ~fpInst = sym; ("[fp] inst = " ++ sym).postln; };
~fpScale_    = { |name|
    ~fpScaleArr = ~fpScales[name] ? ~fpScaleArr;
    ("[fp] scale = " ++ name).postln;
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
    { true }           { ("[fp] cmd OSC inconnue: " ++ cmd).postln; };
}, '/control/fp');

"[OK] finger_piano : ~fpOn / ~fpScale_(\\dorian) / ~fpInst_(\\fm_bell)".postln;
"[OK] finger_piano OSC : /control/fp on|off|debug 1|scale <n>|inst <n>".postln;
)
