// =====================================================================
//  G04_jazz_machine.scd  --  Album G, track 4/15
// =====================================================================

// --- TRACK G04 : "JAZZ MACHINE" 7 minutes ----------------------------
//   0:00 rhodes -> 1:00 swing -> 2:30 stabs -> 4:30 fmLead -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G04 0:00] rhodes seul...".postln;
    ~bpm = 126;
    ~melodyInst = \rhodes; ~melodyAttack = 0.01; ~melodyRelease = 0.7;
    ~melodyCutoff = 3500; ~melodyAmp = 0.22;
    ~melodyNotes = ~genMelody.(0.55, ~scaleDorian);
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    60.wait;

    "[G04 1:00] groove swing -- kick + hats jazzy...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.48;
    ~kickFreq = 50; ~kickPitchAmt = 2.7; ~kickDecay = 0.30; ~kickClick = 0.10;
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,0,1]; ~hatAmp = 0.13;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.28;
    ~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,0,0,0];
    ~percAmp = 0.18;
    ~reload.value;
    90.wait;

    "[G04 2:30] stabs detroit jazzy...".postln;
    ~melodyInst = \stab;
    ~melodyAttack = 0.001; ~melodyRelease = 0.07; ~melodyCutoff = 3500;
    ~melodyDrive = 2.4; ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.45, ~scaleDorian);
    ~reload.value;
    24.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.3, ~scaleDorian);
            ~reload.value;
        };
        if (0.10.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-5,-3,3,5].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[G04 4:30] fmLead solo evolutif...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4500;
    ~melodyAmp = 0.18;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 2500, \sin, 4500) };
    ~reload.value;
    24.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.6,
                [~scaleDorian, ~scaleMinorPent, ~scaleBlues].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[G04 6:30] outro warmPad...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.48; ~hatAmp = x * 0.13; ~clapAmp = x * 0.28;
        ~percAmp = x * 0.18; ~melodyAmp = x * 0.18;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G04 7:00] === fin JAZZ MACHINE ===".postln;
}).play;
"=== TRACK G04 : JAZZ MACHINE 7 min lancee ===".postln;
)
