// =====================================================================
//  J09_oceanic.scd  --  Album J, track 9/15
// =====================================================================

// --- TRACK J09 : "OCEANIC" 7 minutes ---------------------------------
//   0:00 drone ocean -> 1:30 strings vagues -> 3:00 vocalPad -> 4:30 flute -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J09 0:00] drone oceanique...".postln;
    ~bpm = 70;
    ~melodyInst = \drone; ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~melodyCutoff = 1500; ~melodyAmp = 0.20;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 45, \decay, 10, \amp, 0.5]);
    90.wait;

    "[J09 1:30] strings vagues...".postln;
    ~melodyInst = \strings;
    ~melodyAttack = 0.6; ~melodyRelease = 1.5; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    74,0,0,0, 72,0,0,0, 67,0,0,0, 65,0,0,0];
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.06, 1500, \sin, 3500) };
    ~reload.value;
    90.wait;

    "[J09 3:00] vocalPad ondulee...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 2500;
    ~melodyAmp = 0.22;
    ~reload.value;
    90.wait;

    "[J09 4:30] flute aquatique...".postln;
    ~melodyInst = \flute;
    ~melodyAttack = 0.08; ~melodyRelease = 0.5; ~melodyCutoff = 4000;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.4, ~scaleMinorPent);
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[J09 6:30] outro...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \drone;
    ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~reload.value;
    20.do { |k|
        var x = 1 - ((k + 1) / 20);
        ~melodyAmp = x * 0.22; ~melodyCutoff = 200 + (x * 1000);
        ~reload.value; 1.5.wait;
    };
    Synth(\gong, [\freq, 35, \decay, 15, \amp, 0.6]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J09 7:00] === fin OCEANIC ===".postln;
}).play;
"=== TRACK J09 : OCEANIC 7 min lancee ===".postln;
)
