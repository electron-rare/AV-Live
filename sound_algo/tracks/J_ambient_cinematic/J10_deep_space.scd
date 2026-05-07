// =====================================================================
//  J10_deep_space.scd  --  Album J, track 10/15
// =====================================================================

// --- TRACK J10 : "DEEP SPACE" 8 minutes ------------------------------
//   0:00 drone -> 1:30 vocalPad -> 3:00 strings -> 4:30 didgeridoo -> 6:00 handpan -> 7:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J10 0:00] drone galactique...".postln;
    ~bpm = 65;
    ~melodyInst = \drone; ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~melodyCutoff = 1500; ~melodyAmp = 0.20;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    55,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 50, \decay, 12, \amp, 0.5]);
    90.wait;

    "[J10 1:30] vocalPad cosmic...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 2500;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,0, 63,0,0,0, 67,0,0,0, 70,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 63,0,0,0];
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.05, 800, \sin, 2500) };
    ~reload.value;
    90.wait;

    "[J10 3:00] strings stellaires...".postln;
    ~melodyInst = \strings;
    ~melodyAttack = 0.5; ~melodyRelease = 1.5; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~reload.value;
    18.do { |k|
        if (0.18.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[J10 4:30] didgeridoo planete...".postln;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
    ~melodyAmp = 0.22;
    ~reload.value;
    90.wait;

    "[J10 6:00] handpan etoiles...".postln;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.8; ~melodyCutoff = 5000;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,67,0, 70,0,72,0, 75,0,72,70, 67,0,63,60,
                    63,0,67,0, 70,0,75,0, 79,0,75,72, 70,0,65,60];
    ~reload.value;
    60.wait;

    "[J10 7:00] outro grand fade...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \drone;
    ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~reload.value;
    40.do { |k|
        var x = 1 - ((k + 1) / 40);
        ~melodyAmp = x * 0.22; ~melodyCutoff = 200 + (x * 1000);
        ~reload.value; 1.5.wait;
    };
    Synth(\gong, [\freq, 30, \decay, 18, \amp, 0.7]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J10 8:00] === fin DEEP SPACE ===".postln;
}).play;
"=== TRACK J10 : DEEP SPACE 8 min lancee ===".postln;
)
