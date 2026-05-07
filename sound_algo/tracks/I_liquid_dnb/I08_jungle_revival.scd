// =====================================================================
//  I08_jungle_revival.scd  --  Album I, track 8/15
// =====================================================================

// --- TRACK I08 : "JUNGLE REVIVAL" 6 minutes --------------------------
//   0:00 pad -> 1:00 amen jungle -> 2:30 sub808 -> 4:30 lead -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I08 0:00] pad reggae...".postln;
    ~bpm = 174;
    ~melodyInst = \warmPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 2000; ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 70,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    60.wait;

    "[I08 1:00] amen jungle classic...".postln;
    ~kickSteps  = [1,0,0,1, 0,0,1,0, 0,1,1,0, 1,0,0,0]; ~kickAmp = 0.52;
    ~kickFreq = 50; ~kickPitchAmt = 3.5; ~kickDecay = 0.20; ~kickClick = 0.28;
    ~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,1,0, 1,0,0,1]; ~snareAmp = 0.50;
    ~snareFreq = 250; ~snareNoiseAmt = 0.75; ~snareDecay = 0.09;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
    ~reload.value;
    90.wait;

    "[I08 2:30] bass808 jungle...".postln;
    ~melodyInst = \bass808;
    ~melodyAttack = 0.005; ~melodyRelease = 0.5; ~melodyCutoff = 800;
    ~melodyAmp = 0.25;
    ~melodyNotes = [36,0,0,0, 39,0,0,0, 41,0,0,0, 36,0,0,0,
                    36,0,0,0, 41,0,0,0, 43,0,0,0, 39,0,0,0];
    ~reload.value;
    120.wait;

    "[I08 4:30] fmLead jungle...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 4500;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.55, ~scaleMinor);
    ~reload.value;
    12.do { |k|
        if (0.22.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[I08 5:30] outro pad...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.52; ~snareAmp = x * 0.50; ~hatAmp = x * 0.10;
        ~melodyAmp = x * 0.25;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I08 6:00] === fin JUNGLE REVIVAL ===".postln;
}).play;
"=== TRACK I08 : JUNGLE REVIVAL 6 min lancee ===".postln;
)
