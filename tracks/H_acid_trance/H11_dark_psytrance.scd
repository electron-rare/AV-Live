// =====================================================================
//  H11_dark_psytrance.scd  --  Album H, track 11/15
// =====================================================================

// --- TRACK H11 : "DARK PSYTRANCE" 7 minutes --------------------------
//   0:00 drone dark -> 1:00 kick psy -> 2:30 reese + acid -> 4:30 hard -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H11 0:00] drone dark...".postln;
    ~bpm = 145;
    ~melodyInst = \drone; ~melodyAttack = 1.0; ~melodyRelease = 2.5;
    ~melodyCutoff = 1200; ~melodyAmp = 0.18;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    36,0,0,0,0,0,0,0, 39,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16);
    ~acidNotes = [36,36,48,36, 39,36,43,39, 36,41,36,39, 43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 700; ~acidRq = 0.12; ~acidDrive = 3.0; ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    60.wait;

    "[H11 1:00] kick psy hard...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.60;
    ~kickFreq = 62; ~kickPitchAmt = 4.0; ~kickDecay = 0.22; ~kickClick = 0.30;
    ~hatSteps = [0,1,1,1, 0,1,1,1, 0,1,1,1, 0,1,1,1]; ~hatAmp = 0.18;
    ~acidAmp = 0.35;
    ~reload.value;
    90.wait;

    "[H11 2:30] reese dark + acid...".postln;
    ~melodyInst = \reese;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 1500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [36,0,0,0, 39,0,0,0, 41,0,0,0, 36,0,0,0,
                    36,0,0,0, 41,0,0,0, 39,0,0,0, 36,0,0,0];
    ~vcfOn !? { ~vcfOn.(\ladder, 1500, 0.5) };
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~acidCutoff = rrand(700, 2000); ~reload.value };
        if (0.18.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scalePhrygian);
            ~reload.value;
        };
        5.wait;
    };

    "[H11 4:30] hardLead dark climax...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \hardLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.25; ~melodyCutoff = 5500;
    ~melodyAmp = 0.20;
    ~lfoTo !? { ~lfoTo.(\acidCutoff, 0.2, 700, \saw, 1800) };
    ~reload.value;
    120.wait;

    "[H11 6:30] outro...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\acidCutoff) };
    ~melodyInst = \drone;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.60; ~hatAmp = x * 0.18;
        ~acidAmp = x * 0.35; ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H11 7:00] === fin DARK PSYTRANCE ===".postln;
}).play;
"=== TRACK H11 : DARK PSYTRANCE 7 min lancee ===".postln;
)
