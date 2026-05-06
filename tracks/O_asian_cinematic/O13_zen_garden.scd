// =====================================================================
//  O13_zen_garden.scd  --  Album O "ZEN GARDEN", track 13/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O13 : "ZEN GARDEN" 4 minutes ----------------------
//   0:00 intro -> 0:48 build -> 1:48 drop -> 2:48 variation -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O13 0:00] intro -- shakuhachi solo + perc tom...".postln;
    ~bpm = 65;
    ~kickAmp = 0.5; ~hatAmp = 0.06; ~melodyAmp = 0.19;
    ~kickFreq = 49; ~kickPitchAmt = 3.7; ~kickDecay = 0.41;
    ~kickDrive = 1.2; ~kickClick = 0.22;
    ~melodyInst = \shakuhachi;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2819;
    ~melodyNotes = [0,0,0,0,64,0,57,69,0,0,0,0,74,57,0,0,0,0,0,0,0,0,0,74,0,0,74,0,66,66,0,0];
    ~kickSteps = [0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0];
    ~hatSteps = [0,0,1,0,0,0,0,0,1,0,0,1,0,1,0,0];
    ~percInst = \tom;
    ~percSteps = [0,1,1,0,0,0,1,0,1,1,0,1,1,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    48.wait;

    "[O13 0:48] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 61; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [64,62,64,66,0,64,59,0,0,0,0,0,59,74,0,0,0,0,66,67,57,67,0,62,0,0,0,71,0,0,67,67];
    ~melodyCutoff = 3319;
    ~percSteps = [0,0,1,1,0,1,0,0,0,1,0,1,1,0,0,1]; ~percAmp = 0.36;
    ~reload.value;
    12.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1416, 3819); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O13 1:48] drop -- variation + ensemble dense...".postln;
    ~bpm = 69; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.55;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,79,83,74,0,0,88,0,91,0,0,0,0,0,91,0,76,0,0,0,74,0,74,0,84,76,81,0,0,0,0,0];
    ~melodyAmp = 0.21;
    ~reload.value;
    10.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHirajoshi);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,1,1,0,1,0,0,0,1,0,1,1,0,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[O13 2:48] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 63; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \shakuhachi;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3619;
    ~melodyNotes = [0,0,38,53,0,0,43,36,0,46,0,36,0,0,45,0,0,0,0,41,0,0,0,41,0,0,45,36,0,0,0,43];
    ~melodyAmp = 0.19;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.19, 1416, \sin, 2819) };
    ~vcfOn !? { ~vcfOn.(\moog, 1616, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    42.wait;

    "[O13 3:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.19; ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2819);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O13 4:00] === fin ZEN GARDEN ===".postln;
}).play;
"=== TRACK O13 : ZEN GARDEN 4 min lancee ===".postln;
)
