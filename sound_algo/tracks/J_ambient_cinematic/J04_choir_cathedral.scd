// =====================================================================
//  J04_choir_cathedral.scd  --  Album J, track 4/15
// =====================================================================

// --- TRACK J04 : "CHOIR CATHEDRAL" 7 minutes -------------------------
//   0:00 drone -> 1:30 choir -> 3:00 strings -> 4:30 organ -> 6:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J04 0:00] drone cathedral...".postln;
    ~bpm = 65;
    ~melodyInst = \drone; ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~melodyCutoff = 1500; ~melodyAmp = 0.18;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    55,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 45, \decay, 12, \amp, 0.5]);
    90.wait;

    "[J04 1:30] choir entre...".postln;
    ~melodyInst = \choir;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8; ~melodyCutoff = 2800;
    ~melodyAmp = 0.24;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    70,0,0,0, 67,0,0,0, 65,0,0,0, 60,0,0,0];
    ~reload.value;
    90.wait;

    "[J04 3:00] strings + choir layered...".postln;
    ~melodyInst = \strings;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 3500;
    ~melodyAmp = 0.22;
    ~reload.value;
    18.do { |k|
        if (0.18.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleHarmonicMin);
            ~reload.value;
        };
        5.wait;
    };

    "[J04 4:30] organ liturgique...".postln;
    ~melodyInst = \organLead;
    ~melodyAttack = 0.05; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 72,0,0,0, 75,0,0,0,
                    77,0,0,0, 75,0,0,0, 72,0,0,0, 67,0,0,0];
    ~reload.value;
    90.wait;

    "[J04 6:00] outro...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~reload.value;
    40.do { |k|
        var x = 1 - ((k + 1) / 40);
        ~melodyAmp = x * 0.24; ~melodyCutoff = 200 + (x * 1000);
        ~reload.value; 1.5.wait;
    };
    Synth(\gong, [\freq, 35, \decay, 15, \amp, 0.6]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J04 7:00] === fin CHOIR CATHEDRAL ===".postln;
}).play;
"=== TRACK J04 : CHOIR CATHEDRAL 7 min lancee ===".postln;
)
