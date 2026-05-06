// =====================================================================
//  O08_bamboo_grove.scd  --  Album O "BAMBOO GROVE", track 08/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O08 : "BAMBOO GROVE" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O08 0:00] intro -- shakuhachi solo + perc tom...".postln;
    ~bpm = 80;
    ~kickAmp = 0.49; ~hatAmp = 0.06; ~melodyAmp = 0.21;
    ~kickFreq = 58; ~kickPitchAmt = 2.2; ~kickDecay = 0.41;
    ~kickDrive = 1.2; ~kickClick = 0.11;
    ~melodyInst = \shakuhachi;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3101;
    ~melodyNotes = [0,0,55,62,0,0,64,0,0,0,69,0,60,0,60,0,0,0,60,0,0,0,0,55,0,0,65,0,0,0,65,0];
    ~kickSteps = [0,1,0,0,1,0,0,0,0,0,0,1,0,0,1,1];
    ~hatSteps = [1,1,1,0,0,1,0,1,1,1,0,0,0,0,0,0];
    ~percInst = \tom;
    ~percSteps = [1,0,0,0,0,0,0,0,0,1,0,0,1,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    72.wait;

    "[O08 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 76; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,69,0,72,72,0,0,60,69,0,65,0,64,0,62,67,60,0,0,0,0,65,62,60,0,0,0,0,65,55,0,67];
    ~melodyCutoff = 3601;
    ~percSteps = [1,1,1,0,0,1,1,1,0,0,1,1,0,1,1,1]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1136, 4101); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O08 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 80; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.54;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [83,0,91,84,0,0,88,0,0,0,0,0,0,0,0,0,0,91,91,84,83,0,0,88,83,76,0,0,0,76,88,0];
    ~melodyAmp = 0.23;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHirajoshi);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,0,0,1,1,1,0,0,1,1,0,1,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[O08 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 86; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \shakuhachi;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3901;
    ~melodyNotes = [38,48,0,0,47,38,0,0,0,0,0,0,0,0,0,52,38,52,0,0,0,45,38,43,0,0,0,0,0,0,0,55];
    ~melodyAmp = 0.21;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.16, 1136, \sin, 3101) };
    ~vcfOn !? { ~vcfOn.(\moog, 1336, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    78.wait;

    "[O08 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.21; ~kickAmp = x * 0.49;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3101);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O08 6:00] === fin BAMBOO GROVE ===".postln;
}).play;
"=== TRACK O08 : BAMBOO GROVE 6 min lancee ===".postln;
)
