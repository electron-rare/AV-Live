// =====================================================================
//  G02_rhodes_dreams.scd  --  Album G "Detroit Soulful", track 2/15
// =====================================================================

// --- TRACK G02 : "RHODES DREAMS" 5 minutes ---------------------------
//   0:00 rhodes solo -> 1:00 kick groove -> 2:30 lead -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G02 0:00] rhodes intro...".postln;
    ~bpm = 122;
    ~melodyInst = \rhodes; ~melodyAttack = 0.01; ~melodyRelease = 0.8;
    ~melodyCutoff = 3500; ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,67,0, 70,0,72,0, 67,0,70,0, 65,0,63,0,
                    60,0,67,0, 72,0,70,0, 67,0,63,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    60.wait;

    "[G02 1:00] kick deep + hats subtils...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
    ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.40; ~kickClick = 0.08;
    ~hatSteps = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]; ~hatAmp = 0.10;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.25;
    ~reload.value;
    90.wait;

    "[G02 2:30] fmLead jazzy par-dessus...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.45; ~melodyCutoff = 4200;
    ~melodyAmp = 0.16;
    ~melodyNotes = ~genMelody.(0.55, ~scaleDorian);
    ~reload.value;
    24.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleDorian);
            ~reload.value;
        };
        if (0.15.coin) { ~melodyCutoff = rrand(3500, 5000); ~reload.value };
        5.wait;
    };

    "[G02 4:30] outro -- rhodes fade...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.02; ~melodyRelease = 1.2;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.45; ~hatAmp = x * 0.10; ~clapAmp = x * 0.25;
        ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G02 5:00] === fin RHODES DREAMS ===".postln;
}).play;
"=== TRACK G02 : RHODES DREAMS 5 min lancee ===".postln;
)
