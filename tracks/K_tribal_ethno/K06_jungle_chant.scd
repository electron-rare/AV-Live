// =====================================================================
//  K06_jungle_chant.scd  --  Album K "JUNGLE CHANT", track 06/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K06 : "JUNGLE CHANT" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K06 0:00] intro -- flute solo + perc tom...".postln;
    ~bpm = 108;
    ~kickAmp = 0.5; ~hatAmp = 0.06; ~melodyAmp = 0.19;
    ~kickFreq = 57; ~kickPitchAmt = 2.2; ~kickDecay = 0.48;
    ~kickDrive = 1.2; ~kickClick = 0.23;
    ~melodyInst = \flute;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3706;
    ~melodyNotes = [74,67,0,0,69,69,0,77,67,77,0,69,0,0,0,0,0,0,0,0,0,70,62,69,72,0,60,0,0,74,0,0];
    ~kickSteps = [0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0];
    ~hatSteps = [0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0];
    ~percInst = \tom;
    ~percSteps = [0,0,1,0,0,0,1,0,0,1,0,0,0,0,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    72.wait;

    "[K06 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 108; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,69,0,0,0,62,74,0,62,0,0,0,70,62,0,62,72,0,77,0,0,0,72,62,0,0,60,0,69,60,77,70];
    ~melodyCutoff = 4206;
    ~percSteps = [0,0,1,1,0,1,1,0,0,0,0,1,0,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(926, 4706); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K06 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 106; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.55;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,91,0,81,79,81,0,0,0,86,0,0,0,0,0,0,0,84,0,0,0,0,86,81,91,0,0,76,0,74];
    ~melodyAmp = 0.21;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,1,1,0,1,1,0,0,0,0,1,0,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[K06 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 104; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \flute;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4506;
    ~melodyNotes = [0,0,40,0,52,42,0,35,0,0,0,37,52,0,40,42,42,0,0,40,49,0,37,0,0,44,37,45,45,0,47,0];
    ~melodyAmp = 0.19;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.19, 926, \sin, 3706) };
    ~vcfOn !? { ~vcfOn.(\moog, 1126, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    78.wait;

    "[K06 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.19; ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3706);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K06 6:00] === fin JUNGLE CHANT ===".postln;
}).play;
"=== TRACK K06 : JUNGLE CHANT 6 min lancee ===".postln;
)
