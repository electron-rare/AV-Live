// =====================================================================
//  G14_choir_breakdown.scd  --  Album G, track 14/15
// =====================================================================

// --- TRACK G14 : "CHOIR BREAKDOWN" 5 minutes -------------------------
//   0:00 choir intro -> 1:00 break drums -> 2:30 climax -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G14 0:00] choir intro...".postln;
    ~bpm = 123;
    ~melodyInst = \choir; ~melodyAttack = 0.4; ~melodyRelease = 1.5;
    ~melodyCutoff = 2800; ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    70,0,0,0, 67,0,0,0, 65,0,0,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    60.wait;

    "[G14 1:00] drums entrent doucement...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.48;
    ~kickFreq = 50; ~kickPitchAmt = 2.5; ~kickDecay = 0.35;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.28;
    ~reload.value;
    90.wait;

    "[G14 2:30] climax -- supersaw + choir layered...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.01; ~melodyRelease = 0.4; ~melodyCutoff = 4500;
    ~melodyAmp = 0.20;
    ~vcfOn !? { ~vcfOn.(\moog, 2200, 0.4) };
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[G14 4:30] outro -- choir fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \choir;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.48; ~hatAmp = x * 0.13; ~clapAmp = x * 0.28;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G14 5:00] === fin CHOIR BREAKDOWN ===".postln;
}).play;
"=== TRACK G14 : CHOIR BREAKDOWN 5 min lancee ===".postln;
)
