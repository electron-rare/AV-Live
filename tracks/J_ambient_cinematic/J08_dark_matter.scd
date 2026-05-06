// =====================================================================
//  J08_dark_matter.scd  --  Album J, track 8/15
// =====================================================================

// --- TRACK J08 : "DARK MATTER" 6 minutes -----------------------------
//   0:00 drone dark -> 1:30 didgeridoo -> 3:00 reese drone -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J08 0:00] drone dark matter...".postln;
    ~bpm = 60;
    ~melodyInst = \drone; ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~melodyCutoff = 1000; ~melodyAmp = 0.22;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    36,0,0,0,0,0,0,0, 39,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 35, \decay, 15, \amp, 0.6]);
    90.wait;

    "[J08 1:30] didgeridoo terre...".postln;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 1200;
    ~melodyAmp = 0.22;
    ~reload.value;
    90.wait;

    "[J08 3:00] reese drone obscur...".postln;
    ~melodyInst = \reese;
    ~melodyAttack = 0.5; ~melodyRelease = 1.5; ~melodyCutoff = 800;
    ~melodyDrive = 1.8; ~melodyAmp = 0.22;
    ~melodyNotes = [36,0,0,0, 0,0,0,0, 39,0,0,0, 0,0,0,0,
                    36,0,0,0, 0,0,0,0, 41,0,0,0, 0,0,0,0];
    ~vcfOn !? { ~vcfOn.(\ladder, 1000, 0.5) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.05, 600, \sin, 1500) };
    ~reload.value;
    90.wait;

    "[J08 4:30] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \drone;
    ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~melodyCutoff = 200 + (x * 800);
        ~reload.value; 1.wait;
    };
    Synth(\gong, [\freq, 30, \decay, 18, \amp, 0.7]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J08 6:00] === fin DARK MATTER ===".postln;
}).play;
"=== TRACK J08 : DARK MATTER 6 min lancee ===".postln;
)
