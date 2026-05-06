// =====================================================================
//  G08_organ_chapel.scd  --  Album G, track 8/15
// =====================================================================

// --- TRACK G08 : "ORGAN CHAPEL" 6 minutes ----------------------------
//   0:00 organ choeur -> 1:00 kick -> 2:30 stab -> 4:30 climax -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G08 0:00] organ chapel intro...".postln;
    ~bpm = 122;
    ~melodyInst = \organLead; ~melodyAttack = 0.05; ~melodyRelease = 0.6;
    ~melodyCutoff = 3500; ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    70,0,0,0, 67,0,0,0, 65,0,0,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    60.wait;

    "[G08 1:00] kick liturgique...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.50;
    ~kickFreq = 50; ~kickPitchAmt = 2.8; ~kickDecay = 0.40; ~kickClick = 0.10;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.28;
    ~reload.value;
    90.wait;

    "[G08 2:30] stab + variations modales...".postln;
    ~melodyInst = \stab;
    ~melodyAttack = 0.001; ~melodyRelease = 0.08; ~melodyDrive = 2.5;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.45, ~scaleHarmonicMin);
    ~reload.value;
    24.do { |k|
        if (0.22.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleHarmonicMin);
            ~reload.value;
        };
        5.wait;
    };

    "[G08 4:30] climax -- choir + supersaw...".postln;
    ~melodyInst = \choir;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2800;
    ~melodyAmp = 0.22;
    ~reload.value;
    60.wait;

    "[G08 5:30] outro -- organ fade...".postln;
    ~melodyInst = \organLead;
    ~melodyAttack = 0.05; ~melodyRelease = 1.2;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.50; ~hatAmp = x * 0.13; ~clapAmp = x * 0.28;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G08 6:00] === fin ORGAN CHAPEL ===".postln;
}).play;
"=== TRACK G08 : ORGAN CHAPEL 6 min lancee ===".postln;
)
