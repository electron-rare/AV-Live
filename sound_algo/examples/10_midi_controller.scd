// =====================================================================
//  examples/10_midi_controller.scd  --  Setup MIDI
//
//  TITRE       : Mapper un controller MIDI sur les variables
//  DUREE       : ~3 minutes
//  NIVEAU      : avance
//  PREREQUIS   : CHARGER TOUT (00_load.scd)
//                + un controller MIDI USB branche
//
//  CONCEPTS
//    midi.scd cree des MIDIFunc.cc(...) qui :
//      1. Recoivent un CC du controller
//      2. Mappent la valeur 0-127 sur une plage utile (linlin / linexp)
//      3. Set la variable d'environnement (~kickAmp, ~melodyCutoff, ...)
//      4. Appellent ~debouncedReload (50ms debounce -> evite le spam)
//
//  Le mapping de defaut cible un Launch Control XL (8 fad + 8 pots),
//  adapte les numeros CC selon ton controller.
// =====================================================================


// --- [etape 0] Verification ----------------------------------------
(
if (~reload.isNil) {
    "!!! engine pas charge -- evalue CHARGER TOUT dans 00_load.scd".postln;
} {
    "engine OK".postln;
};
)


// --- [etape 1] INIT MIDI -- lister les devices --------------------
//   Reproduit le 1er bloc de control/midi.scd. La console affiche les sources
//   et destinations. Si tu vois ton controller, c'est OK.
(
MIDIClient.init;
"=== MIDI sources disponibles ===".postln;
MIDIClient.sources.do { |src, i|
    ("  [" ++ i ++ "] " ++ src.device ++ " : " ++ src.name).postln;
};
"=== MIDI destinations ===".postln;
MIDIClient.destinations.do { |dst, i|
    ("  [" ++ i ++ "] " ++ dst.device ++ " : " ++ dst.name).postln;
};
MIDIIn.connectAll;
"=== MIDIIn.connectAll OK ===".postln;
)


// --- [etape 2] MAPPING DEFAULT -- charger control/midi.scd --------
//   .load execute le 2e bloc de control/midi.scd qui cree ~midiFuncs
//   avec les 16 mappings standards (CC 13-20 = volumes, CC 29-36 =
//   filtres, CC 49-56 = wobble/sidechain, notes 36-42 = oneshot FX).
(
(~base ++ "control/midi.scd").load;
)
//  -- la console doit afficher "=== MIDI MAPPING ACTIF ===".


// --- [etape 3] Demarrer un beat pour entendre les changements -----
(
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
)
//  -- bouge tes potards : CC 13 = kickAmp, CC 29 = melodyCutoff, etc.


// --- [etape 4] DEBUG -- afficher tous les CC recus ----------------
//   Utile pour decouvrir les numeros CC envoyes par TON controller.
(
~midiDebug = MIDIFunc.cc({ |val, num, chan|
    ("[CC] " ++ num ++ " = " ++ val ++ " ch" ++ chan).postln;
});
"MIDI debug ON -- bouge un potard".postln;
)


// --- [etape 5] Couper le debug -------------------------------------
( ~midiDebug !? { ~midiDebug.free; ~midiDebug = nil }; "MIDI debug OFF".postln; )


// --- [etape 6] STOP MIDI -- libere tous les MIDIFunc --------------
(
~midiFuncs !? { ~midiFuncs.do { |f| f.free }; ~midiFuncs = nil };
~midiDebug !? { ~midiDebug.free; ~midiDebug = nil };
"=== MIDI STOPPED ===".postln;
)


// --- [etape 7] STOP global ----------------------------------------
(
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)
