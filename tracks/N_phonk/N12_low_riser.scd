// =====================================================================
//  N12_low_riser.scd  --  Album N "LOW RISER", track 12/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N12 : "LOW RISER" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N12 0:00] intro -- reese solo + perc cowbell...".postln;
    ~bpm = 132;
    ~kickAmp = 0.47; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 41; ~kickPitchAmt = 3.5; ~kickDecay = 0.31;
    ~kickDrive = 1.2; ~kickClick = 0.13;
    ~melodyInst = \reese;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2552;
    ~melodyNotes = [62,0,79,0,79,76,67,69,0,0,64,76,0,71,0,0,0,71,69,0,72,0,62,79,62,0,0,0,0,0,79,79];
    ~kickSteps = [0,1,0,1,0,0,0,0,0,0,1,1,0,1,0,1];
    ~hatSteps = [0,0,0,1,0,0,0,1,1,0,1,1,0,1,1,0];
    ~percInst = \cowbell;
    ~percSteps = [0,1,1,1,1,0,0,0,0,0,1,0,0,0,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    60.wait;

    "[N12 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [62,71,79,0,72,0,0,0,64,69,72,0,0,0,0,0,0,67,72,0,0,0,72,69,0,0,0,0,69,64,69,0];
    ~melodyCutoff = 3052;
    ~percSteps = [0,0,1,1,1,1,0,0,1,1,1,1,1,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1097, 3552); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N12 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 128; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.52;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [91,74,0,84,0,91,84,0,0,86,76,79,0,0,81,0,86,79,0,0,76,84,86,0,0,76,83,84,0,74,0,0];
    ~melodyAmp = 0.25;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scalePhrygian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,1,1,1,1,0,0,1,1,1,1,1,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[N12 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \reese;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3352;
    ~melodyNotes = [52,0,0,38,0,0,45,50,48,0,0,0,0,0,0,40,0,43,38,0,40,45,0,0,0,0,48,0,0,0,0,55];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.18, 1097, \sin, 2552) };
    ~vcfOn !? { ~vcfOn.(\moog, 1297, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    60.wait;

    "[N12 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.47;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2552);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N12 5:00] === fin LOW RISER ===".postln;
}).play;
"=== TRACK N12 : LOW RISER 5 min lancee ===".postln;
)
