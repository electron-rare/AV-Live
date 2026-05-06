// =====================================================================
//  J11_neural_dreams.scd  --  Album J, track 11/15
// =====================================================================

// --- TRACK J11 : "NEURAL DREAMS" 7 minutes ---------------------------
//   0:00 drone -> 1:30 fmBell -> 3:00 vocalPad -> 4:30 handpan -> 6:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J11 0:00] drone neural...".postln;
    ~bpm = 75;
    ~melodyInst = \drone; ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~melodyCutoff = 1500; ~melodyAmp = 0.20;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 50, \decay, 10, \amp, 0.5]);
    90.wait;

    "[J11 1:30] fmBell dreams...".postln;
    ~melodyInst = \fmBell;
    ~melodyAttack = 0.005; ~melodyRelease = 1.2; ~melodyCutoff = 5000;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,67,0, 72,0,75,0, 70,0,72,0, 67,0,60,0,
                    63,0,67,0, 70,0,75,0, 72,0,67,0, 60,0,63,0];
    ~reload.value;
    90.wait;

    "[J11 3:00] vocalPad onirique...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 2500;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    70,0,0,0, 67,0,0,0, 65,0,0,0, 60,0,0,0];
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.06, 800, \sin, 2500) };
    ~reload.value;
    90.wait;

    "[J11 4:30] handpan reverie...".postln;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.8; ~melodyCutoff = 5000;
    ~melodyAmp = 0.22;
    ~melodyNotes = ~genMelody.(0.4, ~scaleMinorPent);
    ~reload.value;
    18.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[J11 6:00] outro...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \drone;
    ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~reload.value;
    40.do { |k|
        var x = 1 - ((k + 1) / 40);
        ~melodyAmp = x * 0.22; ~melodyCutoff = 200 + (x * 1000);
        ~reload.value; 1.5.wait;
    };
    Synth(\gong, [\freq, 35, \decay, 15, \amp, 0.6]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J11 7:00] === fin NEURAL DREAMS ===".postln;
}).play;
"=== TRACK J11 : NEURAL DREAMS 7 min lancee ===".postln;
)
