// =====================================================================
//  H06_progressive_drift.scd  --  Album H, track 6/15
// =====================================================================

// --- TRACK H06 : "PROGRESSIVE DRIFT" 6 minutes -----------------------
//   0:00 pad -> 1:00 kick -> 2:30 acid evolve -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H06 0:00] pad progressive...".postln;
    ~bpm = 138;
    ~melodyInst = \warmPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    70,0,0,0, 65,0,0,0, 67,0,0,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16);
    ~acidNotes = [36,36,48,36, 39,36,43,39, 36,41,36,39, 43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 600; ~acidRq = 0.20; ~acidDrive = 2.0; ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    60.wait;

    "[H06 1:00] kick deep + acid soft...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.50;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.15;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.28;
    ~acidAmp = 0.25;
    ~reload.value;
    90.wait;

    "[H06 2:30] acid evolve + lfo...".postln;
    ~lfoTo !? { ~lfoTo.(\acidCutoff, 0.08, 600, \sin, 1800) };
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.2; ~melodyCutoff = 4500;
    ~melodyAmp = 0.16;
    ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[H06 4:30] outro...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\acidCutoff) };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.50; ~hatAmp = x * 0.13; ~clapAmp = x * 0.28;
        ~acidAmp = x * 0.25; ~melodyAmp = x * 0.16;
        ~acidCutoff = 200 + (x * 1300);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H06 5:00] === fin PROGRESSIVE DRIFT ===".postln;
}).play;
"=== TRACK H06 : PROGRESSIVE DRIFT 5 min lancee ===".postln;
)
