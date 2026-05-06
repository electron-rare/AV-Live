// =====================================================================
//  J15_eternity_fade.scd  --  Album J, track 15/15
// =====================================================================

// --- TRACK J15 : "ETERNITY FADE" 6 minutes ---------------------------
//   0:00 drone -> 1:00 strings -> 2:30 choir -> 4:00 vocalPad -> 5:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J15 0:00] drone eternite...".postln;
    ~bpm = 60;
    ~melodyInst = \drone; ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~melodyCutoff = 1500; ~melodyAmp = 0.20;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 50, \decay, 12, \amp, 0.5]);
    60.wait;

    "[J15 1:00] strings infinies...".postln;
    ~melodyInst = \strings;
    ~melodyAttack = 0.6; ~melodyRelease = 1.5; ~melodyCutoff = 3500;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    74,0,0,0, 72,0,0,0, 67,0,0,0, 65,0,0,0];
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.05, 1500, \sin, 3500) };
    ~reload.value;
    90.wait;

    "[J15 2:30] choir cosmic...".postln;
    ~melodyInst = \choir;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8; ~melodyCutoff = 2800;
    ~melodyAmp = 0.24;
    ~reload.value;
    90.wait;

    "[J15 4:00] vocalPad horizon...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 2500;
    ~melodyAmp = 0.22;
    ~reload.value;
    60.wait;

    "[J15 5:00] outro grand fade vers eternite...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \drone;
    ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~reload.value;
    40.do { |k|
        var x = 1 - ((k + 1) / 40);
        ~melodyAmp = x * 0.24; ~melodyCutoff = 200 + (x * 1300);
        ~reload.value; 1.5.wait;
    };
    Synth(\gong, [\freq, 30, \decay, 20, \amp, 0.8]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J15 6:00] === fin ETERNITY FADE ===".postln;
}).play;
"=== TRACK J15 : ETERNITY FADE 6 min lancee ===".postln;
)
