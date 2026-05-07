// =====================================================================
//  V10_autechre_machine.scd  --  Album V "Glitch IDM", track 10/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK V10 : "AUTECHRE MACHINE" 8 minutes ----------------------
//   0:00 intro -> 0:48 build -> 2:00 main -> 5:54 variations -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[V10 0:00] intro autechre_machine...".postln;
    ~bpm = 145;
    ~kickFreq = 55; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.3;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [68,67,0,0,63,0,0,0,61,0,0,0,70,0,0,0,72,0,63,0,65,67,63,61,65,0,0,72,72,63,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,1,0,0,0,1,0,0,0,1,0,0,0,1,1,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    48.wait;

    "[V10 0:48] build kick + hat...".postln;
    ~kickSteps = [1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,1,0,1, 0,1,1,0]; ~hatAmp = 0.1;
    ~clapSteps = [0,0,1,0, 1,0,0,1, 0,1,0,0, 0,0,1,0]; ~clapAmp = 0.3;
    ~melodyAmp = 0.180;
    ~reload.value;
    72.wait;

    "[V10 2:00] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [63,63,60,0,63,63,70,60,0,0,0,0,72,0,70,63,67,68,0,61,70,60,70,0,63,60,0,61,63,0,60,0];
    ~acidAmp = 0.22;
    ~reload.value;
    234.wait;

    "[V10 5:54] variations + mutations...".postln;
    ~melodyNotes = [0,70,60,0,72,0,61,67,65,0,70,60,0,0,61,70,0,0,68,70,0,70,67,0,65,72,72,67,70,0,0,0];
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.55, [~scalePhrygian, ~scaleMinorPent, ~scaleDorian].choose);
        };
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2);
        };
        if (0.15.coin) {
            ~melodyCutoff = rrand(1500, 5500);
        };
        if (0.10.coin) {
            ~melodyNotes = ~octavate.(~melodyNotes, 0.25);
        };
        ~reload.value;
        4.wait;
    };

    "[V10 7:30] outro -- fade...".postln;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.180;
        ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.1;
        ~clapAmp = x * 0.3;
        ~acidAmp = x * 0.22;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[V10 8:00] === fin AUTECHRE MACHINE ===".postln;
}).play;
"=== TRACK V10 : AUTECHRE MACHINE 8 min lancee ===".postln;
)
