// =====================================================================
//  live/midi_init.scd  --  Auto-init MIDI au boot
//
//  Charge MIDIClient + MIDIIn.connectAll + mapping CC/note par defaut
//  en UN SEUL bloc top-level (.load-compatible, contrairement a
//  control/midi.scd qui est decoupe pour l'IDE).
//
//  IDEMPOTENT : libere les MIDIFunc precedentes avant de remapper.
//
//  Mapping :
//    Notes 36-47 (C2-B2)  : albums A-L  -> ~playAlbum
//    Notes 48-59 (C3-B3)  : albums M-W  -> ~playAlbum (12 albums M..X)
//    Notes 60-71 (C4-B4)  : kicks index 0..11  -> ~kkAt
//    Notes 72-83 (C5-B5)  : melodies index 0..11 -> ~mmAt
//    Notes 84-95 (C6-B6)  : fx index 0..11      -> ~ffAt
//    CC 13-20             : volumes par voix    (kick/hat/snare/clap/...)
//    CC 29-36             : cutoffs / drive / bpm
//    CC 49-56             : wobble / sidechain / FX
//    CC 7   (master)      : master volume       -> ~masterVol
//
//  Customisation : surcharge ~midiMapDefault avant le boot, ou re-map
//  apres avec control/midi.scd (Cmd+Entree dans l'IDE).
// =====================================================================
(
~midiAutoInit !? { ~midiAutoInit.value };  // teardown precedent

~midiSafe = { |func, label = "midi"|
    { func.value }.try { |err|
        ("[" ++ label ++ "] error: " ++ err.errorString).postln;
        err.dumpBackTrace;
    };
};

~midiAutoInit = {
    "[midi_init] freeing previous MIDIFunc...".postln;
    ~midiFuncs !? { ~midiFuncs.do { |f| f.free } };
    ~midiFuncs = nil;
    ~midiInitialized = false;
};

// --- Sortie ordonnee par index (helpers d'acces aux dicts existants) ---
~kkAt = ~kkAt ?? { |i|
    ~kkBank !? {
        var keys = ~kkBank.keys.asArray.sort;
        i = i.clip(0, keys.size - 1);
        ~kk.(keys[i]);
    };
};
~mmAt = ~mmAt ?? { |i|
    ~mmBank !? {
        var keys = ~mmBank.keys.asArray.sort;
        i = i.clip(0, keys.size - 1);
        ~mm.(keys[i]);
    };
};
~ffAt = ~ffAt ?? { |i|
    ~ffBank !? {
        var keys = ~ffBank.keys.asArray.sort;
        i = i.clip(0, keys.size - 1);
        ~ff.(keys[i]);
    };
};

~midiMapDefault = {
    ~midiFuncs = List.new;

    // Debounce ~reload (evite spam)
    ~reloadPending = ~reloadPending ?? false;
    ~debouncedReload = {
        if (~reloadPending.not) {
            ~reloadPending = true;
            AppClock.sched(0.05, { ~reloadPending = false; ~reload.value; nil });
        };
    };

    // ---- CC : volumes par voix ----
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~kickAmp     = val.linlin(0,127, 0,1);   ~debouncedReload.() }, 13));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~hatAmp      = val.linlin(0,127, 0,0.4); ~debouncedReload.() }, 14));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~snareAmp    = val.linlin(0,127, 0,0.8); ~debouncedReload.() }, 15));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~clapAmp     = val.linlin(0,127, 0,0.6); ~debouncedReload.() }, 16));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~percAmp     = val.linlin(0,127, 0,0.5); ~debouncedReload.() }, 17));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~acidAmp     = val.linlin(0,127, 0,0.5); ~debouncedReload.() }, 18));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyAmp   = val.linlin(0,127, 0,0.4); ~debouncedReload.() }, 19));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~harmonyAmp  = val.linlin(0,127, 0,0.4); ~debouncedReload.() }, 20));

    // ---- CC : filtres / drive / bpm ----
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyCutoff = val.linexp(0,127, 100,12000); ~debouncedReload.() }, 29));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyRq     = val.linlin(0,127, 0.05,0.8);  ~debouncedReload.() }, 30));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~acidCutoff   = val.linexp(0,127, 100,8000);  ~debouncedReload.() }, 31));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~acidRq       = val.linlin(0,127, 0.05,0.5);  ~debouncedReload.() }, 32));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyDrive  = val.linlin(0,127, 0.5,5.0);   ~debouncedReload.() }, 33));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~acidDrive    = val.linlin(0,127, 0.5,5.0);   ~debouncedReload.() }, 34));
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~melodyBoost  = val.linlin(0,127, 0.5,3.0);   ~debouncedReload.() }, 35));
    ~midiFuncs.add(MIDIFunc.cc({ |val| TempoClock.default.tempo = val.linlin(0,127, 60,200) / 60 }, 36));

    // ---- CC : wobble / sidechain / FX ----
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

    // ---- CC : master ----
    ~midiFuncs.add(MIDIFunc.cc({ |val|
        ~masterVol !? { ~masterVol.(val.linlin(0,127, 0, 1.5)) };
    }, 7));

    // ---- Notes 36-47 : albums A-L ----
    12.do { |i|
        var letter = "ABCDEFGHIJKL"[i].asString.asSymbol;
        ~midiFuncs.add(MIDIFunc.noteOn({
            ~playAlbum !? { ~playAlbum.(letter) };
        }, 36 + i));
    };
    // ---- Notes 48-59 : albums M-X ----
    12.do { |i|
        var letter = "MNOPQRSTUVWX"[i].asString.asSymbol;
        ~midiFuncs.add(MIDIFunc.noteOn({
            ~playAlbum !? { ~playAlbum.(letter) };
        }, 48 + i));
    };
    // ---- Notes 60-71 : kicks 0..11 ----
    12.do { |i|
        ~midiFuncs.add(MIDIFunc.noteOn({ ~kkAt.(i) }, 60 + i));
    };
    // ---- Notes 72-83 : melodies 0..11 ----
    12.do { |i|
        ~midiFuncs.add(MIDIFunc.noteOn({ ~mmAt.(i) }, 72 + i));
    };
    // ---- Notes 84-95 : fx 0..11 ----
    12.do { |i|
        ~midiFuncs.add(MIDIFunc.noteOn({ ~ffAt.(i) }, 84 + i));
    };

    "[midi_init] mapping default applique :".postln;
    ("  notes 36-59 = albums A-X (~playAlbum)").postln;
    ("  notes 60-71 = kicks 0-11 (~kkAt)").postln;
    ("  notes 72-83 = melodies 0-11 (~mmAt)").postln;
    ("  notes 84-95 = fx 0-11 (~ffAt)").postln;
    ("  CC 7        = master volume").postln;
    ("  CC 13-20    = volumes par voix").postln;
    ("  CC 29-36    = cutoffs / drive / bpm").postln;
    ("  CC 49-56    = wobble / sidechain / FX").postln;
};

// Defer init so MIDIClient discovery doesn't block the main load
AppClock.sched(0.5, {
    ~midiSafe.({
        MIDIClient.init;
        var nSrc = MIDIClient.sources.size;
        ("[midi_init] " ++ nSrc ++ " MIDI source(s) detected").postln;
        if (nSrc > 0) {
            MIDIClient.sources.do { |src, i|
                ("  [" ++ i ++ "] " ++ src.device ++ " : " ++ src.name).postln;
            };
            MIDIIn.connectAll;
            ~midiMapDefault.value;
            ~midiInitialized = true;
            "[midi_init] OK".postln;
        } {
            "[midi_init] no MIDI device, skipping mapping (re-run live/midi_init.scd to retry)".postln;
            ~midiInitialized = false;
        };
    }, "midi_init");
    nil;
});
)
