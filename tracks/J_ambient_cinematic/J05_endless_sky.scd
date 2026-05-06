// =====================================================================
//  J05_endless_sky.scd  --  Album J, track 5/15
// =====================================================================

// --- TRACK J05 : "ENDLESS SKY" 8 minutes -----------------------------
//   0:00 drone -> 1:30 strings -> 3:00 flute -> 4:30 handpan -> 6:00 vocalPad -> 7:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J05 0:00] drone celeste...".postln;
    ~bpm = 70;
    ~melodyInst = \drone; ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~melodyCutoff = 1500; ~melodyAmp = 0.18;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 50, \decay, 10, \amp, 0.5]);
    90.wait;

    "[J05 1:30] strings...".postln;
    ~melodyInst = \strings;
    ~melodyAttack = 0.4; ~melodyRelease = 1.2; ~melodyCutoff = 3500;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    74,0,0,0, 72,0,0,0, 67,0,0,0, 65,0,0,0];
    ~reload.value;
    90.wait;

    "[J05 3:00] flute melodique...".postln;
    ~melodyInst = \flute;
    ~melodyAttack = 0.08; ~melodyRelease = 0.5; ~melodyCutoff = 4000;
    ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.45, ~scaleMinorPent);
    ~reload.value;
    18.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[J05 4:30] handpan jardin...".postln;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.8; ~melodyCutoff = 5000;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,67,0, 70,0,72,0, 75,0,72,70, 67,0,63,60,
                    63,0,67,0, 70,0,75,0, 79,0,75,72, 70,0,65,60];
    ~reload.value;
    90.wait;

    "[J05 6:00] vocalPad spirit...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.08, 700, \sin, 2200) };
    ~reload.value;
    60.wait;

    "[J05 7:00] outro grand fade...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \drone;
    ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~reload.value;
    40.do { |k|
        var x = 1 - ((k + 1) / 40);
        ~melodyAmp = x * 0.22; ~melodyCutoff = 200 + (x * 1000);
        ~reload.value; 1.5.wait;
    };
    Synth(\gong, [\freq, 35, \decay, 15, \amp, 0.6]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J05 8:00] === fin ENDLESS SKY ===".postln;
}).play;
"=== TRACK J05 : ENDLESS SKY 8 min lancee ===".postln;
)
