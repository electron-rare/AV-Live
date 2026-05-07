// =====================================================================
//  N06_anguish_808.scd  --  Album N "808 ANGUISH", track 06/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N06 : "808 ANGUISH" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N06 0:00] intro -- subBoom solo + perc cowbell...".postln;
    ~bpm = 134;
    ~kickAmp = 0.48; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 40; ~kickPitchAmt = 2.2; ~kickDecay = 0.51;
    ~kickDrive = 1.2; ~kickClick = 0.2;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2533;
    ~melodyNotes = [67,0,65,65,68,0,0,63,0,65,60,0,65,0,67,65,65,68,65,0,0,68,0,0,0,0,0,0,0,0,0,68];
    ~kickSteps = [0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0];
    ~hatSteps = [1,0,1,0,0,0,0,0,1,1,0,0,0,0,0,0];
    ~percInst = \cowbell;
    ~percSteps = [1,0,1,0,1,0,0,1,1,0,0,0,1,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    72.wait;

    "[N06 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [58,0,65,0,67,0,0,75,0,0,0,70,70,0,0,70,67,65,63,0,0,60,65,72,0,0,0,0,0,72,0,60];
    ~melodyCutoff = 3033;
    ~percSteps = [1,1,1,1,0,1,1,0,0,1,1,1,1,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1191, 3533); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N06 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 138; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.53;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [69,77,76,81,69,84,0,0,0,84,72,0,0,76,72,76,76,72,76,77,84,67,77,0,0,76,0,0,74,81,0,0];
    ~melodyAmp = 0.24;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,1,0,1,1,0,0,1,1,1,1,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[N06 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 138; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3333;
    ~melodyNotes = [38,0,0,0,50,0,50,0,0,47,0,52,0,0,40,40,48,52,0,0,0,0,0,0,52,0,48,0,0,0,0,0];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.22, 1191, \sin, 2533) };
    ~vcfOn !? { ~vcfOn.(\moog, 1391, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    78.wait;

    "[N06 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.48;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2533);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N06 6:00] === fin 808 ANGUISH ===".postln;
}).play;
"=== TRACK N06 : 808 ANGUISH 6 min lancee ===".postln;
)
