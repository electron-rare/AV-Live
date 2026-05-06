// =====================================================================
//  H08_hoover_storm.scd  --  Album H, track 8/15
// =====================================================================

// --- TRACK H08 : "HOOVER STORM" 6 minutes ----------------------------
//   0:00 pad -> 1:00 kick -> 2:30 hooverbass storm -> 4:30 climax -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H08 0:00] pad...".postln;
    ~bpm = 142;
    ~melodyInst = \warmPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,0,0, 63,0,0,0, 67,0,0,0, 72,0,0,0,
                    70,0,0,0, 67,0,0,0, 63,0,0,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    60.wait;

    "[H08 1:00] kick + clap...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 60; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.20;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~reload.value;
    90.wait;

    "[H08 2:30] hooverbass storm...".postln;
    ~melodyInst = \hooverbass;
    ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 1800;
    ~melodyAmp = 0.22;
    ~melodyNotes = [36,0,0,0, 39,0,0,0, 41,0,0,0, 36,0,0,0,
                    36,0,0,0, 41,0,0,0, 43,0,0,0, 39,0,0,0];
    ~vcfOn !? { ~vcfOn.(\moog, 1500, 0.45) };
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinor);
            ~reload.value;
        };
        if (0.10.coin) { ~melodyDrive = rrand(2.0, 3.5); ~reload.value };
        5.wait;
    };

    "[H08 4:30] climax -- supersaw layer...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 5000;
    ~melodyAmp = 0.20;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.3, 2500, \sin, 5000) };
    ~reload.value;
    60.wait;

    "[H08 5:30] outro...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.16; ~clapAmp = x * 0.32;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H08 6:00] === fin HOOVER STORM ===".postln;
}).play;
"=== TRACK H08 : HOOVER STORM 6 min lancee ===".postln;
)
