// =====================================================================
//  J14_gong_threshold.scd  --  Album J, track 14/15
// =====================================================================

// --- TRACK J14 : "GONG THRESHOLD" 5 minutes --------------------------
//   0:00 gong + drone -> 1:30 vocalPad -> 3:00 didgeridoo -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J14 0:00] gongs + drone...".postln;
    ~bpm = 65;
    ~melodyInst = \drone; ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~melodyCutoff = 1200; ~melodyAmp = 0.20;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 60, \decay, 12, \amp, 0.6]);
    30.wait;
    Synth(\gong, [\freq, 50, \decay, 12, \amp, 0.5]);
    30.wait;
    Synth(\gong, [\freq, 45, \decay, 12, \amp, 0.5]);
    30.wait;

    "[J14 1:30] vocalPad seuil...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,0, 63,0,0,0, 67,0,0,0, 70,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 63,0,0,0];
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.05, 700, \sin, 2200) };
    ~reload.value;
    90.wait;

    "[J14 3:00] didgeridoo terre...".postln;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
    ~melodyAmp = 0.22;
    ~reload.value;
    90.wait;

    "[J14 4:30] outro -- gong threshold...".postln;
    Synth(\gong, [\freq, 35, \decay, 18, \amp, 0.7]);
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \drone;
    ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~reload.value;
    20.do { |k|
        var x = 1 - ((k + 1) / 20);
        ~melodyAmp = x * 0.22; ~melodyCutoff = 200 + (x * 800);
        ~reload.value; 1.5.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J14 5:00] === fin GONG THRESHOLD ===".postln;
}).play;
"=== TRACK J14 : GONG THRESHOLD 5 min lancee ===".postln;
)
