// =====================================================================
//  J02_drone_meditation.scd  --  Album J, track 2/15
// =====================================================================

// --- TRACK J02 : "DRONE MEDITATION" 5 minutes ------------------------
//   0:00 drone -> 1:30 didgeridoo -> 3:00 vocalPad -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J02 0:00] drone profond...".postln;
    ~bpm = 60;
    ~melodyInst = \drone; ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~melodyCutoff = 1200; ~melodyAmp = 0.20;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    36,0,0,0,0,0,0,0, 43,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 45, \decay, 10, \amp, 0.5]);
    90.wait;

    "[J02 1:30] didgeridoo terrestre...".postln;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
    ~melodyAmp = 0.22;
    ~reload.value;
    90.wait;

    "[J02 3:00] vocalPad spirit...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,0,0,0,0,0, 65,0,0,0,0,0,0,0,
                    67,0,0,0,0,0,0,0, 60,0,0,0,0,0,0,0];
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.08, 700, \sin, 2200) };
    ~reload.value;
    90.wait;

    "[J02 4:30] outro...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \drone;
    ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~reload.value;
    20.do { |k|
        var x = 1 - ((k + 1) / 20);
        ~melodyAmp = x * 0.22; ~melodyCutoff = 200 + (x * 1000);
        ~reload.value; 1.5.wait;
    };
    Synth(\gong, [\freq, 35, \decay, 15, \amp, 0.6]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J02 5:00] === fin DRONE MEDITATION ===".postln;
}).play;
"=== TRACK J02 : DRONE MEDITATION 5 min lancee ===".postln;
)
