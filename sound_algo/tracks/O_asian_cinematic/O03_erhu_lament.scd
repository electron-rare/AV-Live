// =====================================================================
//  O03_erhu_lament.scd  --  Album O "ERHU LAMENT", track 03/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O03 : "ERHU LAMENT" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O03 0:00] intro -- erhu solo + perc tom...".postln;
    ~bpm = 70;
    ~kickAmp = 0.45; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 58; ~kickPitchAmt = 2.6; ~kickDecay = 0.5;
    ~kickDrive = 1.2; ~kickClick = 0.26;
    ~melodyInst = \erhu;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3450;
    ~melodyNotes = [64,0,0,0,0,0,64,0,0,64,0,66,62,0,0,0,0,0,0,67,67,0,57,66,0,0,0,0,69,64,57,0];
    ~kickSteps = [0,0,1,0,1,1,1,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,1];
    ~percInst = \tom;
    ~percSteps = [1,1,0,1,1,1,0,1,0,0,1,1,1,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    72.wait;

    "[O03 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 70; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,71,0,0,66,69,62,0,0,0,71,0,0,62,0,71,59,0,0,59,69,71,57,69,0,62,64,0,0,59,0,71];
    ~melodyCutoff = 3950;
    ~percSteps = [0,1,0,1,1,0,0,0,0,0,0,0,0,1,0,0]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1161, 4450); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O03 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 68; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.5;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,76,0,74,72,76,79,0,0,81,76,0,0,0,79,72,81,0,69,0,0,0,79,0,81,84,0,0,74,79];
    ~melodyAmp = 0.24;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleJapanese);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,0,1,1,0,0,0,0,0,0,0,0,1,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[O03 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 66; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \erhu;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4250;
    ~melodyNotes = [0,38,0,0,0,0,38,0,0,0,35,40,0,0,38,0,0,0,0,38,0,47,0,0,38,0,38,0,40,0,0,33];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.34, 1161, \sin, 3450) };
    ~vcfOn !? { ~vcfOn.(\moog, 1361, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    78.wait;

    "[O03 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.45;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3450);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O03 6:00] === fin ERHU LAMENT ===".postln;
}).play;
"=== TRACK O03 : ERHU LAMENT 6 min lancee ===".postln;
)
