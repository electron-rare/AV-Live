// =====================================================================
//  M01_pixel_intro.scd  --  Album M "PIXEL INTRO", track 01/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M01 : "PIXEL INTRO" 4 minutes ----------------------
//   0:00 intro -> 0:48 build -> 1:48 drop -> 2:48 variation -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M01 0:00] intro -- squareLead solo + perc tom...".postln;
    ~bpm = 140;
    ~kickAmp = 0.5; ~hatAmp = 0.06; ~melodyAmp = 0.21;
    ~kickFreq = 63; ~kickPitchAmt = 2.9; ~kickDecay = 0.3;
    ~kickDrive = 1.2; ~kickClick = 0.29;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3164;
    ~melodyNotes = [0,77,0,70,70,62,72,0,0,0,65,0,0,0,0,74,0,0,0,0,0,62,72,0,0,0,0,77,0,0,67,0];
    ~kickSteps = [1,1,0,1,0,0,0,1,1,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,1,0,0,1,0,0,0,0,1,0,0,1,1,0];
    ~percInst = \tom;
    ~percSteps = [0,0,0,1,0,0,1,0,1,0,0,1,0,0,1,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\arp);
    48.wait;

    "[M01 0:48] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 140; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,69,60,67,0,0,62,60,74,67,74,69,60,65,62,77,0,65,69,62,67,70,0,62,0,0,65,0,67,77,65,0];
    ~melodyCutoff = 3664;
    ~percSteps = [1,0,1,1,1,1,1,1,1,0,1,0,0,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    12.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1071, 4164); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M01 1:48] drop -- variation + ensemble dense...".postln;
    ~bpm = 142; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.55;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [83,74,0,0,74,0,0,0,0,0,81,74,86,0,0,79,74,74,79,0,76,0,0,78,69,83,79,0,0,86,79,83];
    ~melodyAmp = 0.23;
    ~reload.value;
    10.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,1,1,1,1,1,1,1,0,1,0,0,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[M01 2:48] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 144; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3964;
    ~melodyNotes = [53,0,46,0,48,0,43,0,0,0,0,0,0,0,0,0,43,0,0,0,0,0,0,50,0,0,41,0,0,46,0,0];
    ~melodyAmp = 0.21;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.25, 1071, \sin, 3164) };
    ~vcfOn !? { ~vcfOn.(\moog, 1271, 0.4) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    42.wait;

    "[M01 3:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.21; ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3164);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M01 4:00] === fin PIXEL INTRO ===".postln;
}).play;
"=== TRACK M01 : PIXEL INTRO 4 min lancee ===".postln;
)
