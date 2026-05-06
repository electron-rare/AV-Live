// =====================================================================
//  I11_breakbeat_soul.scd  --  Album I, track 11/15
// =====================================================================

// --- TRACK I11 : "BREAKBEAT SOUL" 7 minutes --------------------------
//   0:00 rhodes -> 1:00 break -> 2:30 stab -> 4:30 lead -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I11 0:00] rhodes soul intro...".postln;
    ~bpm = 174;
    ~melodyInst = \rhodes; ~melodyAttack = 0.01; ~melodyRelease = 0.7;
    ~melodyCutoff = 3500; ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.55, ~scaleDorian);
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    60.wait;

    "[I11 1:00] break soulful...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.48;
    ~kickFreq = 52; ~kickPitchAmt = 3.2; ~kickDecay = 0.22; ~kickClick = 0.20;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.48;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.11;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.25;
    ~reload.value;
    90.wait;

    "[I11 2:30] stab soulful...".postln;
    ~melodyInst = \stab;
    ~melodyAttack = 0.001; ~melodyRelease = 0.06; ~melodyDrive = 2.3;
    ~melodyCutoff = 3500; ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,67,0, 70,0,67,0, 65,0,72,0, 70,0,65,0,
                    63,0,67,0, 70,0,67,0, 60,0,65,0, 63,0,60,0];
    ~reload.value;
    24.do { |k|
        if (0.22.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleDorian);
            ~reload.value;
        };
        5.wait;
    };

    "[I11 4:30] fmLead soul...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
    ~melodyAmp = 0.18;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 3000, \sin, 5000) };
    ~reload.value;
    24.do { |k|
        if (0.22.coin) {
            ~melodyNotes = ~genMelody.(0.55,
                [~scaleMinorPent, ~scaleDorian].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[I11 6:30] outro...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.02; ~melodyRelease = 1.2;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.48; ~snareAmp = x * 0.48; ~hatAmp = x * 0.11;
        ~clapAmp = x * 0.25; ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I11 7:00] === fin BREAKBEAT SOUL ===".postln;
}).play;
"=== TRACK I11 : BREAKBEAT SOUL 7 min lancee ===".postln;
)
