// =====================================================================
//  G11_galactic_soul.scd  --  Album G, track 11/15
// =====================================================================

// --- TRACK G11 : "GALACTIC SOUL" 7 minutes ---------------------------
//   0:00 vocalPad -> 1:00 kick spatial -> 2:30 fmLead -> 4:30 supersaw -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G11 0:00] vocalPad cosmique...".postln;
    ~bpm = 124;
    ~melodyInst = \vocalPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~melodyCutoff = 2500; ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 72,0,0,0, 75,0,0,0,
                    72,0,0,0, 67,0,0,0, 60,0,0,0, 65,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    60.wait;

    "[G11 1:00] kick spatial...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.50;
    ~kickFreq = 50; ~kickPitchAmt = 3.0; ~kickDecay = 0.35; ~kickClick = 0.12;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.14;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
    ~reload.value;
    90.wait;

    "[G11 2:30] fmLead galactic...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4500;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.55, ~scaleMinorPent);
    ~reload.value;
    24.do { |k|
        if (0.22.coin) {
            ~melodyNotes = ~genMelody.(0.55,
                [~scaleMinorPent, ~scaleDorian, ~scaleHigh].choose);
            ~reload.value;
        };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.25); ~reload.value };
        5.wait;
    };

    "[G11 4:30] supersaw cosmic...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4500;
    ~melodyAmp = 0.20;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.15, 2500, \sin, 4500) };
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~reload.value;
    120.wait;

    "[G11 6:30] outro -- vocalPad...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.50; ~hatAmp = x * 0.14; ~clapAmp = x * 0.30;
        ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G11 7:00] === fin GALACTIC SOUL ===".postln;
}).play;
"=== TRACK G11 : GALACTIC SOUL 7 min lancee ===".postln;
)
