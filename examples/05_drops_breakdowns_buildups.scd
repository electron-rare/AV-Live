// =====================================================================
//  examples/05_drops_breakdowns_buildups.scd  --  Tricks scéniques
//
//  TITRE       : Les "tricks" classiques d'une perf live
//  DUREE       : ~10 minutes (en testant tout)
//  NIVEAU      : intermediaire
//  PREREQUIS   : CHARGER TOUT (00_load.scd) + SETUP de live.scd
//
//  BUT
//    Helpers ergonomiques de live.scd pour les transitions :
//    drop, breakdown, buildup, tape stop, freeze, glitch, stutter...
//
//    Tous ces helpers sont des Routines : ils tournent jusqu'a la
//    fin de la duree donnee, puis restaurent l'etat precedent
//    automatiquement.
// =====================================================================


// --- [etape 0] Verification ----------------------------------------
(
if (~drop.isNil) {
    "!!! live.scd pas charge -- ouvre live.scd et evalue son SETUP".postln;
} {
    "live.scd OK".postln;
};
)


// --- [etape 1] Demarrer un beat de base ----------------------------
(
~kickAmp = 0.55; ~hatAmp = 0.18; ~melodyAmp = 0.18; ~acidAmp = 0.3;
~melodyInst = \lead;
~reload.value;
[\kickSeq, \hatSeq, \acidSeq, \melodySeq].do { |k| Pdef(k).play };
"beat lance -- pret pour les tricks".postln;
)
//  -- laisse tourner 16-32 beats avant de tenter un drop.


// --- [etape 2] DROP -- silence sec puis blast (4s de buildup) -------
//   ~drop.(buildDur)
//   Coupe tout, monte un riser, puis re-explose la rythmique a fond.
( ~drop.(4); )
//  -- attendre 8s, le drop fait son cycle complet.


// --- [etape 3] BREAKDOWN -- mute drums, garde melodie + reverb ------
//   ~breakdown.(dur)
//   Coupe kick + hat, ajoute reverb sur la melodie, restaure apres dur.
( ~breakdown.(8); )
//  -- attendre 8s.


// --- [etape 4] BUILDUP -- crescendo qui monte sur dur secondes ------
//   ~buildup.(dur)
//   Snare roll + filtre qui s'ouvre + amp qui monte.
( ~buildup.(8); )


// --- [etape 5] HANDS UP -- cut sub + boost lead --------------------
//   Effet typique festival : on enleve le bas + clap et on pousse le lead.
( ~handsUp.(); )
//  -- attendre 4s.


// --- [etape 6] TAPE STOP -- ralentissement du tempo (2s) -----------
//   ~tapeStop.(dur)
//   Tempo descend a 0 sur dur secondes ; effet bande magnetique.
( ~tapeStop.(2); )


// --- [etape 7] FREEZE -- gel tout en reverb (4s) -------------------
//   Reverb saturee + master mute = effet "vide aspirant" puis retour.
( ~freeze.(4); )


// --- [etape 8] GLITCH -- bitcrush + rate variations sur 2s ----------
( ~glitch.(2); )


// --- [etape 9] STUTTER -- repete tres vite a 8Hz pendant 1s --------
//   ~stutter.(rateHz, dur)
( ~stutter.(8, 1); )
//  -- on entend un effet "bbbbbbbb" tres serre.


// --- [etape 10] JUMP CUT -- silence sec de 0.5s --------------------
//   Effet "pause" tres courte, comme une coupe au montage video.
( ~jumpCut.(0.5); )


// --- [etape 11] REVERB TAIL -- queue de reverb 4s ------------------
//   Mute la rythmique, garde uniquement la queue de reverb.
( ~reverbTail.(4); )


// --- [etape 12] BIT CRUSH NOW -- bitcrush sur 1s ------------------
//   ~bitCrushNow.(bits, sr, dur)
( ~bitCrushNow.(6, 6000, 1); )


// --- [etape 13] RING MOD -- mod en anneau a 200Hz pendant 1s ------
( ~ringMod.(200, 1); )


// --- [etape 14] TAPE REVERSE -- inverse la lecture 2s -------------
( ~tapeReverse.(2); )


// --- [etape 15] COMBO classique : breakdown -> buildup -> drop -----
//   Chaine 3 helpers en sequence (separes par .wait).
//   Ce bloc est un Routine asynchrone qui dure ~24 secondes au total.
(
Routine({
    "[combo] BREAKDOWN".postln;
    ~breakdown.(8);
    8.wait;
    "[combo] BUILDUP".postln;
    ~buildup.(8);
    8.wait;
    "[combo] DROP".postln;
    ~drop.(4);
}).play;
)


// --- [etape 16] STOP global ----------------------------------------
(
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)
