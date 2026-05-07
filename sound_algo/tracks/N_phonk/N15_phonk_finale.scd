// =====================================================================
//  N15_phonk_finale.scd  --  Album N "PHONK FINALE", track 15/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N15 : "PHONK FINALE" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N15 0:00] intro -- subBoom solo + perc cowbell...".postln;
    ~bpm = 138;
    ~kickAmp = 0.5; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 54; ~kickPitchAmt = 3.9; ~kickDecay = 0.46;
    ~kickDrive = 1.2; ~kickClick = 0.17;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2230;
    ~melodyNotes = [0,0,62,70,70,0,74,0,0,0,0,0,72,0,0,0,0,69,0,0,0,69,0,0,0,72,60,0,0,0,70,62];
    ~kickSteps = [0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0];
    ~hatSteps = [1,1,0,0,1,0,0,0,0,0,1,0,0,0,0,0];
    ~percInst = \cowbell;
    ~percSteps = [0,1,0,1,1,1,0,0,1,0,0,0,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    72.wait;

    "[N15 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,69,0,0,74,0,0,70,0,69,72,0,65,0,0,70,60,77,0,65,77,67,70,0,65,67,65,0,72,0,74,77];
    ~melodyCutoff = 2730;
    ~percSteps = [0,1,0,1,1,0,1,0,1,1,1,1,0,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1274, 3230); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N15 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.55;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,0,0,0,0,86,84,74,84,77,0,81,0,0,81,0,72,0,0,0,0,0,77,0,0,0,84,72,0,82];
    ~melodyAmp = 0.25;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scalePhrygian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,0,1,1,0,1,0,1,1,1,1,0,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[N15 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 142; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3030;
    ~melodyNotes = [33,40,0,40,48,31,0,0,40,0,40,38,48,31,0,33,0,0,38,33,31,43,0,0,45,48,36,0,43,36,41,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.18, 1274, \sin, 2230) };
    ~vcfOn !? { ~vcfOn.(\moog, 1474, 0.4) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    78.wait;

    "[N15 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2230);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N15 6:00] === fin PHONK FINALE ===".postln;
}).play;
"=== TRACK N15 : PHONK FINALE 6 min lancee ===".postln;
)
