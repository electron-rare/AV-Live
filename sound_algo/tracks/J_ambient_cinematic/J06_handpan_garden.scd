// =====================================================================
//  J06_handpan_garden.scd  --  Album J, track 6/15
// =====================================================================

// --- TRACK J06 : "HANDPAN GARDEN" 6 minutes --------------------------
//   0:00 drone -> 1:00 handpan -> 2:30 perc tom doux -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J06 0:00] drone jardin...".postln;
    ~bpm = 80;
    ~melodyInst = \drone; ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~melodyCutoff = 1500; ~melodyAmp = 0.18;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 55,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    60.wait;

    "[J06 1:00] handpan principal...".postln;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.8; ~melodyCutoff = 5000;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,67,0, 70,0,72,0, 75,0,72,70, 67,0,63,60,
                    63,0,67,0, 70,0,75,0, 79,0,75,72, 70,0,65,60];
    ~reload.value;
    90.wait;

    "[J06 2:30] tom doux + handpan...".postln;
    ~percInst = \tom;
    ~percSteps = [1,0,0,0, 0,0,0,1, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.18;
    ~tomFreq = 70;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[J06 4:30] outro...".postln;
    ~percSteps=(0!16);
    ~melodyInst = \drone;
    ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~percAmp = x * 0.18;
        ~melodyCutoff = 200 + (x * 1000);
        ~reload.value; 1.wait;
    };
    Synth(\gong, [\freq, 40, \decay, 12, \amp, 0.5]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J06 6:00] === fin HANDPAN GARDEN ===".postln;
}).play;
"=== TRACK J06 : HANDPAN GARDEN 6 min lancee ===".postln;
)
