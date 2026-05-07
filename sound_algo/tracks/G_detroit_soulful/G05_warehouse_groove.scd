// =====================================================================
//  G05_warehouse_groove.scd  --  Album G, track 5/15
// =====================================================================

// --- TRACK G05 : "WAREHOUSE GROOVE" 8 minutes ------------------------
//   0:00 pad -> 1:00 kick -> 2:30 organ -> 4:30 supersaw -> 6:30 stab -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G05 0:00] pad chaleureux...".postln;
    ~bpm = 125;
    ~melodyInst = \warmPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 1800; ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 70,0,0,0, 75,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    60.wait;

    "[G05 1:00] kick warehouse + clap...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 52; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.18;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
    ~reload.value;
    90.wait;

    "[G05 2:30] organ stab...".postln;
    ~melodyInst = \organLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.18; ~melodyCutoff = 4500;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[G05 4:30] supersaw layer + vcf moog...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.01; ~melodyRelease = 0.4; ~melodyCutoff = 4500;
    ~melodyAmp = 0.18;
    ~vcfOn !? { ~vcfOn.(\moog, 2200, 0.4) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.25, 2500, \sin, 4500) };
    ~reload.value;
    120.wait;

    "[G05 6:30] stab final + drive...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \stab;
    ~melodyAttack = 0.001; ~melodyRelease = 0.08; ~melodyDrive = 3.0;
    ~melodyAmp = 0.20;
    ~reload.value;
    60.wait;

    "[G05 7:30] outro...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.16; ~clapAmp = x * 0.35;
        ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G05 8:00] === fin WAREHOUSE GROOVE ===".postln;
}).play;
"=== TRACK G05 : WAREHOUSE GROOVE 8 min lancee ===".postln;
)
