// =====================================================================
//  examples/14_fx_chains_dynamic.scd  --  FX bus dynamique
//
//  TITRE       : Bus FX en send + LFO sur params FX + presets
//  DUREE       : ~6 minutes
//  NIVEAU      : avance
//  PREREQUIS   : CHARGER TOUT (00_load.scd)
//                + ouvrir fx_bus.scd, evaluer son SETUP (3 blocs en haut)
//
//  ATTENTION
//    fx_bus.scd a une signature different de live.scd :
//      ~send.(fxName, amount)       -- envoie LE BUS 0 ENTIER vers le FX
//                                      (donc tout le mix passe dedans)
//      ~setFx.(fxName, key, val)    -- modifie un parametre du FX
//      ~lfo.(fxName, key, rate, lo, hi, shape) -- LFO sur un param FX
//
//  FX dispos : \rev \dly \chr \phs \flg \crsh \tape \shim \dist
//  Presets   : \dub \space \trance \dubstep \retro \industrial
//              \dream \cosmic \drone \dry
// =====================================================================


// --- [etape 0] Verification ----------------------------------------
(
if (~send.isNil or: { ~fxFx.isNil }) {
    "!!! fx_bus.scd pas charge -- ouvre fx_bus.scd et evalue ses 3 SETUP".postln;
} {
    "fx_bus.scd OK".postln;
};
)


// --- [etape 1] Demarrer un beat de base ----------------------------
(
~kickAmp = 0.55; ~hatAmp = 0.18; ~melodyAmp = 0.18; ~acidAmp = 0.32;
~melodyInst = \lead;
~reload.value;
[\kickSeq, \hatSeq, \acidSeq, \melodySeq].do { |k| Pdef(k).play };
"beat lance".postln;
)


// --- [etape 2] Preset DUB -- reverb hall + delay long + tape ------
( ~fxPreset.(\dub); )
//  -- on entend tout le mix prendre une couleur dub. Laisser 16 beats.


// --- [etape 3] Reverb seule a 40% ---------------------------------
//   ~send.(fxName, amount) avec amount = 0.4 -> 40% du mix part dans
//   le bus reverb (reste 100% en dry).
( ~send.(\rev, 0.4); )

// Couper le delay du preset DUB (pour ne garder que la reverb)
( ~send.(\dly, 0); )
( ~send.(\tape, 0); )


// --- [etape 4] Delay 1/8 (375ms) avec feedback 50% ---------------
(
~send.(\dly, 0.3);
~setFx.(\dly, \delayTime, 0.375);    // 1/8 a 120 BPM
~setFx.(\dly, \feedback, 0.5);
"delay 1/8 fb 50%".postln;
)


// --- [etape 5] LFO sur le feedback du delay -----------------------
//   ~lfo.(fxName, param, rateHz, lo, hi, shape)
//   Le feedback oscille entre 30% et 80% a 0.2Hz (cycle 5s).
( ~lfo.(\dly, \feedback, 0.2, 0.3, 0.8, \sin); )
//  -- on entend le delay grossir/decroitre. Laisser tourner 30s.


// --- [etape 6] Stop le LFO sur ce param ---------------------------
( ~lfoStop.(\dly, \feedback); )


// --- [etape 7] Reverb FREEZE -- nappe figee infinie ---------------
( ~setFx.(\rev, \freeze, 1); "REV FREEZE ON".postln; )

// ... ecoute la nappe, joue avec d'autres params

( ~setFx.(\rev, \freeze, 0); "REV FREEZE OFF".postln; )


// --- [etape 8] Tap tempo -- ajuste le delay au tempo qu'on tape ---
//   Tape ~tap au moins 3 fois pour calibrer ; il calcule la moyenne
//   des intervalles et ajuste ~setFx.(\dly, \delayTime, ...).
( ~tap.(); )
( ~tap.(); )
( ~tap.(); )
( ~tap.(); )


// --- [etape 9] Preset SPACE -- shimmer + reverb + chorus ----------
( ~fxPreset.(\space); )


// --- [etape 10] Preset INDUSTRIAL -- distortion + flanger -------
( ~fxPreset.(\industrial); )


// --- [etape 11] Preset DRY -- mute tous les sends -----------------
( ~fxPreset.(\dry); )


// --- [etape 12] STOP global ----------------------------------------
(
~lfoStopAll !? { ~lfoStopAll.() };
~fxPreset.(\dry);
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)
