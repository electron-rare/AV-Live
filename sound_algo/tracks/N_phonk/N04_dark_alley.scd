// =====================================================================
//  N04_dark_alley.scd  --  Album N "DARK ALLEY", track 04/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N04 : "DARK ALLEY" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N04 0:00] intro -- warmPad solo + perc cowbell...".postln;
    ~bpm = 138;
    ~kickAmp = 0.52; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 56; ~kickPitchAmt = 3.5; ~kickDecay = 0.31;
    ~kickDrive = 1.2; ~kickClick = 0.13;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3422;
    ~melodyNotes = [0,0,62,0,0,0,0,64,0,57,0,62,0,0,0,0,0,0,69,67,0,0,0,0,72,69,0,0,62,0,60,0];
    ~kickSteps = [0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,0,1,0,0,0,1,0,1,1,0,1,0,1,0];
    ~percInst = \cowbell;
    ~percSteps = [1,1,1,0,1,0,1,0,0,0,0,1,1,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    84.wait;

    "[N04 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 138; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [69,60,0,60,67,69,0,0,57,65,0,64,0,0,0,0,0,64,0,60,0,0,0,67,0,64,0,62,64,0,0,0];
    ~melodyCutoff = 3922;
    ~percSteps = [1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1352, 4422); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N04 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 140; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.57;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,69,0,0,77,77,0,0,0,72,0,0,0,0,0,0,67,81,0,0,0,0,0,0,76,77,84,84,72,0,69];
    ~melodyAmp = 0.25;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scalePhrygian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[N04 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4222;
    ~melodyNotes = [0,50,0,0,0,45,38,52,0,0,50,52,0,55,0,0,52,0,48,47,0,0,48,0,0,0,55,45,0,48,0,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.21, 1352, \sin, 3422) };
    ~vcfOn !? { ~vcfOn.(\moog, 1552, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    96.wait;

    "[N04 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.52;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3422);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N04 7:00] === fin DARK ALLEY ===".postln;
}).play;
"=== TRACK N04 : DARK ALLEY 7 min lancee ===".postln;
)
