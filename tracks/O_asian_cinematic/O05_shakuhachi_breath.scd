// =====================================================================
//  O05_shakuhachi_breath.scd  --  Album O "SHAKUHACHI BREATH", track 05/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O05 : "SHAKUHACHI BREATH" 8 minutes ----------------------
//   0:00 intro -> 1:36 build -> 3:36 drop -> 5:36 variation -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O05 0:00] intro -- shakuhachi solo + perc tom...".postln;
    ~bpm = 72;
    ~kickAmp = 0.52; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 56; ~kickPitchAmt = 2.1; ~kickDecay = 0.51;
    ~kickDrive = 1.2; ~kickClick = 0.18;
    ~melodyInst = \shakuhachi;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3633;
    ~melodyNotes = [0,68,0,0,0,0,0,0,0,0,0,75,0,0,58,0,65,70,0,0,65,0,0,0,60,0,75,0,65,65,0,0];
    ~kickSteps = [0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0];
    ~hatSteps = [1,1,1,0,0,1,0,0,0,0,0,0,0,0,0,0];
    ~percInst = \tom;
    ~percSteps = [1,0,0,0,1,1,1,0,0,0,0,0,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    96.wait;

    "[O05 1:36] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 70; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [58,0,0,75,75,0,0,70,63,63,70,0,70,70,0,0,0,58,0,75,75,63,0,0,72,60,63,0,0,72,0,58];
    ~melodyCutoff = 4133;
    ~percSteps = [1,0,0,0,1,0,1,1,0,0,1,1,0,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(936, 4633); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O05 3:36] drop -- variation + ensemble dense...".postln;
    ~bpm = 72; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.57;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,83,88,91,0,0,0,91,86,91,0,0,79,91,83,83,76,76,0,0,88,0,81,86,0,88,0,0,0,74,0,0];
    ~melodyAmp = 0.25;
    ~reload.value;
    20.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHirajoshi);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,0,0,1,0,1,1,0,0,1,1,0,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[O05 5:36] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 68; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \shakuhachi;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4433;
    ~melodyNotes = [36,38,0,0,0,0,0,43,50,0,0,48,0,0,0,45,0,0,43,0,36,38,53,53,0,0,0,45,48,0,45,36];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.25, 936, \sin, 3633) };
    ~vcfOn !? { ~vcfOn.(\moog, 1136, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    114.wait;

    "[O05 7:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.52;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3633);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O05 8:00] === fin SHAKUHACHI BREATH ===".postln;
}).play;
"=== TRACK O05 : SHAKUHACHI BREATH 8 min lancee ===".postln;
)
