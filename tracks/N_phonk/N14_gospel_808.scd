// =====================================================================
//  N14_gospel_808.scd  --  Album N "808 GOSPEL", track 14/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N14 : "808 GOSPEL" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N14 0:00] intro -- bass808 solo + perc cowbell...".postln;
    ~bpm = 130;
    ~kickAmp = 0.55; ~hatAmp = 0.06; ~melodyAmp = 0.21;
    ~kickFreq = 41; ~kickPitchAmt = 2.8; ~kickDecay = 0.46;
    ~kickDrive = 1.2; ~kickClick = 0.3;
    ~melodyInst = \bass808;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3027;
    ~melodyNotes = [0,0,0,0,0,74,71,0,0,76,67,0,72,0,76,62,76,0,72,0,0,64,0,0,0,0,0,69,0,72,76,0];
    ~kickSteps = [0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,1];
    ~hatSteps = [0,0,0,0,1,1,0,0,0,0,1,0,0,0,0,0];
    ~percInst = \cowbell;
    ~percSteps = [0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    60.wait;

    "[N14 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 128; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [79,0,0,0,0,0,76,0,62,0,0,0,67,71,67,0,69,79,71,0,67,79,64,74,0,0,0,0,0,0,0,76];
    ~melodyCutoff = 3527;
    ~percSteps = [0,0,0,1,0,1,0,0,0,0,0,0,0,1,0,0]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1340, 4027); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N14 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.6;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [72,74,0,0,0,0,79,84,0,72,0,0,76,0,77,0,0,69,81,74,72,0,0,67,0,0,81,0,0,69,0,72];
    ~melodyAmp = 0.23;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,0,1,0,1,0,0,0,0,0,0,0,1,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[N14 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 128; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \bass808;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3827;
    ~melodyNotes = [0,47,0,0,0,0,0,48,55,0,43,40,48,47,0,52,55,0,45,0,0,0,0,0,0,0,0,43,50,0,38,0];
    ~melodyAmp = 0.21;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.24, 1340, \sin, 3027) };
    ~vcfOn !? { ~vcfOn.(\moog, 1540, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    60.wait;

    "[N14 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.21; ~kickAmp = x * 0.55;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3027);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N14 5:00] === fin 808 GOSPEL ===".postln;
}).play;
"=== TRACK N14 : 808 GOSPEL 5 min lancee ===".postln;
)
