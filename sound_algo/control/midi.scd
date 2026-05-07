// =====================================================================
//  midi.scd  --  Mapping MIDI controller (CC + Notes)
//
//  Branche un controller (Launch Control, BCR2000, Midi Fighter, etc.)
//  et map les CC sur les parametres essentiels du moteur.
//
//  USAGE :
//    1. Cmd+Entree sur INIT MIDI (initialise + liste devices)
//    2. Cmd+Entree sur MAPPING DEFAULT (ou copier-coller pour customiser)
//    3. Tweak en temps reel via le controller MIDI
// =====================================================================


// --- INIT MIDI -- liste les devices disponibles --------------------
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


// --- MAPPING DEFAULT (16 CC standard) ------------------------------
//   Adapte les numeros CC selon ton controller (ici : Launch Control XL like)
(
~midiFuncs !? { ~midiFuncs.do { |f| f.free } };
~midiFuncs = List.new;

// Debounce ~reload pour eviter le spam (~reload reconstruit 8 Pdef !)
~reloadPending = ~reloadPending ?? false;
~debouncedReload = {
    if (~reloadPending.not) {
        ~reloadPending = true;
        AppClock.sched(0.05, { ~reloadPending = false; ~reload.value; nil });
    };
};

// CC 13-20 = potards rangée 1 (volumes par voix)
~midiFuncs.add(MIDIFunc.cc({ |val| ~kickAmp     = val.linlin(0,127, 0,1);    ~debouncedReload.() }, 13));
~midiFuncs.add(MIDIFunc.cc({ |val| ~hatAmp      = val.linlin(0,127, 0,0.4);  ~debouncedReload.() }, 14));
~midiFuncs.add(MIDIFunc.cc({ |val| ~snareAmp    = val.linlin(0,127, 0,0.8);  ~debouncedReload.() }, 15));
~midiFuncs.add(MIDIFunc.cc({ |val| ~clapAmp     = val.linlin(0,127, 0,0.6);  ~debouncedReload.() }, 16));
~midiFuncs.add(MIDIFunc.cc({ |val| ~percAmp     = val.linlin(0,127, 0,0.5);  ~debouncedReload.() }, 17));
~midiFuncs.add(MIDIFunc.cc({ |val| ~acidAmp     = val.linlin(0,127, 0,0.5);  ~debouncedReload.() }, 18));
~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyAmp   = val.linlin(0,127, 0,0.4);  ~debouncedReload.() }, 19));
~midiFuncs.add(MIDIFunc.cc({ |val| ~harmonyAmp  = val.linlin(0,127, 0,0.4);  ~debouncedReload.() }, 20));

// CC 29-36 = potards rangée 2 (cutoffs / filtres)
~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyCutoff = val.linexp(0,127, 100,12000); ~debouncedReload.() }, 29));
~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyRq     = val.linlin(0,127, 0.05,0.8);  ~debouncedReload.() }, 30));
~midiFuncs.add(MIDIFunc.cc({ |val| ~acidCutoff   = val.linexp(0,127, 100,8000);  ~debouncedReload.() }, 31));
~midiFuncs.add(MIDIFunc.cc({ |val| ~acidRq       = val.linlin(0,127, 0.05,0.5);  ~debouncedReload.() }, 32));
~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyDrive  = val.linlin(0,127, 0.5,5.0);   ~debouncedReload.() }, 33));
~midiFuncs.add(MIDIFunc.cc({ |val| ~acidDrive    = val.linlin(0,127, 0.5,5.0);   ~debouncedReload.() }, 34));
~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyBoost  = val.linlin(0,127, 0.5,3.0);   ~debouncedReload.() }, 35));
~midiFuncs.add(MIDIFunc.cc({ |val| TempoClock.default.tempo = val.linlin(0,127, 60,200) / 60 }, 36));

// CC 49-56 = potards rangée 3 (wobble / sidechain)
~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyWobbleRate  = val.linexp(0,127, 0.5,32);   ~debouncedReload.() }, 49));
~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyWobbleDepth = val.linlin(0,127, 0,4500);   ~debouncedReload.() }, 50));
~midiFuncs.add(MIDIFunc.cc({ |val| ~melodySubAmt      = val.linlin(0,127, 0,1.5);    ~debouncedReload.() }, 51));
~midiFuncs.add(MIDIFunc.cc({ |val| ~acidScAmt         = val.linlin(0,127, 0,1);      ~debouncedReload.() }, 52));
~midiFuncs.add(MIDIFunc.cc({ |val| ~leadScAmt         = val.linlin(0,127, 0,1);      ~debouncedReload.() }, 53));
~midiFuncs.add(MIDIFunc.cc({ |val| ~kickScShape       = val.linlin(0,127, 0.05,0.5); ~debouncedReload.() }, 54));
~midiFuncs.add(MIDIFunc.cc({ |val|
    ~fxFx !? { ~fxFx[\rev] !? { |s| s.set(\mix, val.linlin(0,127, 0,1)) } };
}, 55));
~midiFuncs.add(MIDIFunc.cc({ |val|
    ~fxFx !? { ~fxFx[\dly] !? { |s| s.set(\feedback, val.linlin(0,127, 0,0.95)) } };
}, 56));

// NOTES MIDI : 36-51 = pads de declenchement FX / fills
~midiFuncs.add(MIDIFunc.noteOn({ Synth(\impact, [\freq, 40, \decay, 2, \amp, 0.6]) }, 36));
~midiFuncs.add(MIDIFunc.noteOn({ Synth(\riser, [\dur, 4, \startCutoff, 400, \endCutoff, 11000, \amp, 0.3]) }, 37));
~midiFuncs.add(MIDIFunc.noteOn({ Synth(\sweep, [\dur, 4, \startCutoff, 8000, \endCutoff, 200, \amp, 0.3]) }, 38));
~midiFuncs.add(MIDIFunc.noteOn({ Synth(\crash, [\decay, 3, \amp, 0.4]) }, 39));
~midiFuncs.add(MIDIFunc.noteOn({ Synth(\gong, [\freq, 50, \decay, 8, \amp, 0.5]) }, 40));
~midiFuncs.add(MIDIFunc.noteOn({ ~snareFill !? { ~snareFill.value } }, 41));
~midiFuncs.add(MIDIFunc.noteOn({ ~tomFill !? { ~tomFill.value } }, 42));

// NOTES 48-59 = recall scenes (si scenes definies)
12.do { |i|
    var name = ("scene_" ++ (i + 1)).asSymbol;
    ~midiFuncs.add(MIDIFunc.noteOn({
        ~loadScene !? { ~loadScene.(name) };
    }, 48 + i));
};

"=== MIDI MAPPING ACTIF ===".postln;
"   CC 13-20  : volumes par voix".postln;
"   CC 29-36  : cutoffs / drive / bpm".postln;
"   CC 49-56  : wobble / sidechain / FX".postln;
"   Notes 36-42 : FX oneshot (impact/riser/sweep/crash/gong/fills)".postln;
"   Notes 48-59 : recall scene_1 a scene_12".postln;
)


// --- DEBUG -- print tous les MIDI in entrants ----------------------
(
~midiDebug = MIDIFunc.cc({ |val, num, chan|
    ("[CC] " ++ num ++ " = " ++ val ++ " ch" ++ chan).postln;
});
)
( ~midiDebug !? { ~midiDebug.free; ~midiDebug = nil }; "MIDI debug OFF".postln; )


// --- STOP MIDI (libere tous les mappings) --------------------------
(
~midiFuncs !? { ~midiFuncs.do { |f| f.free }; ~midiFuncs = nil };
~midiDebug !? { ~midiDebug.free; ~midiDebug = nil };
"=== MIDI STOPPED ===".postln;
)
