// =====================================================================
//  I03_rhodes_rain.scd  --  Album I, track 3/15
// =====================================================================

// --- TRACK I03 : "RHODES RAIN" 6 minutes -----------------------------
//   0:00 rhodes solo -> 1:00 amen -> 2:30 sub -> 4:30 lead -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I03 0:00] rhodes solo pluvieux...".postln;
    ~bpm = 174;
    ~melodyInst = \rhodes; ~melodyAttack = 0.01; ~melodyRelease = 0.7;
    ~melodyCutoff = 3500; ~melodyAmp = 0.22;
    ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    60.wait;

    "[I03 1:00] amen entre...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.48;
    ~kickFreq = 52; ~kickPitchAmt = 3.5; ~kickDecay = 0.20; ~kickClick = 0.25;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.45;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.10;
    ~reload.value;
    90.wait;

    "[I03 2:30] subBoom rain...".postln;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.005; ~melodyRelease = 0.6; ~melodyCutoff = 800;
    ~melodyAmp = 0.25;
    ~melodyNotes = [36,0,0,0, 36,0,0,0, 39,0,0,0, 41,0,0,0,
                    36,0,0,0, 36,0,0,0, 41,0,0,0, 39,0,0,0];
    ~reload.value;
    120.wait;

    "[I03 4:30] fmLead delicate...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 5000;
    ~melodyAmp = 0.18;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.55, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[I03 5:30] outro -- rhodes fade...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.02; ~melodyRelease = 1.2;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.48; ~snareAmp = x * 0.45; ~hatAmp = x * 0.10;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I03 6:00] === fin RHODES RAIN ===".postln;
}).play;
"=== TRACK I03 : RHODES RAIN 6 min lancee ===".postln;
)
