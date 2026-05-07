// =====================================================================
//  G09_underground_resistance.scd  --  Album G, track 9/15
// =====================================================================

// --- TRACK G09 : "UNDERGROUND RESISTANCE" 7 minutes ------------------
//   0:00 acid bass -> 1:00 kick hard -> 2:30 stab militant -> 4:30 lead -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G09 0:00] acid bass UR style...".postln;
    ~bpm = 128;
    ~acidNotes = [36,36,48,36, 39,36,43,39, 36,41,36,39, 43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 700; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0.30;
    ~melodyInst = \warmPad; ~melodyAmp = 0.10;
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16);
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    60.wait;

    "[G09 1:00] kick hard Detroit...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 58; ~kickPitchAmt = 4.0; ~kickDecay = 0.25; ~kickClick = 0.30;
    ~kickDrive = 2.0;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
    ~reload.value;
    90.wait;

    "[G09 2:30] stab militant...".postln;
    ~melodyInst = \stab;
    ~melodyAttack = 0.001; ~melodyRelease = 0.06; ~melodyDrive = 3.5;
    ~melodyCutoff = 3500; ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,67,0, 63,0,60,0, 65,0,72,0, 67,0,65,0,
                    60,0,67,0, 63,0,60,0, 65,0,70,0, 67,0,65,0];
    ~reload.value;
    24.do { |k|
        if (0.25.coin) { ~acidCutoff = rrand(700, 1500); ~reload.value };
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.3, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[G09 4:30] supersaw lead militant...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 4500;
    ~melodyAmp = 0.20;
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~lfoTo !? { ~lfoTo.(\acidCutoff, 0.15, 700, \saw, 1500) };
    ~reload.value;
    120.wait;

    "[G09 6:30] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\acidCutoff) };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.18; ~clapAmp = x * 0.35;
        ~acidAmp = x * 0.30; ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G09 7:00] === fin UNDERGROUND RESISTANCE ===".postln;
}).play;
"=== TRACK G09 : UNDERGROUND RESISTANCE 7 min lancee ===".postln;
)
