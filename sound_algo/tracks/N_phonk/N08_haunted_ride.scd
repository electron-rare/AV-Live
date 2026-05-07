// =====================================================================
//  N08_haunted_ride.scd  --  Album N "HAUNTED RIDE", track 08/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N08 : "HAUNTED RIDE" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N08 0:00] intro -- reese solo + perc cowbell...".postln;
    ~bpm = 136;
    ~kickAmp = 0.47; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 50; ~kickPitchAmt = 3.8; ~kickDecay = 0.42;
    ~kickDrive = 1.2; ~kickClick = 0.16;
    ~melodyInst = \reese;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2791;
    ~melodyNotes = [72,0,0,0,0,0,0,0,0,60,68,0,0,0,0,0,0,0,75,68,0,68,63,68,65,60,0,0,0,0,0,75];
    ~kickSteps = [1,0,0,0,1,1,0,0,0,0,0,0,0,1,0,0];
    ~hatSteps = [1,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0];
    ~percInst = \cowbell;
    ~percSteps = [1,0,0,0,0,0,0,1,1,1,0,0,1,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    72.wait;

    "[N08 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [70,60,0,0,0,0,72,60,0,58,0,72,0,0,0,60,0,70,65,65,72,60,70,0,0,75,67,0,0,58,58,70];
    ~melodyCutoff = 3291;
    ~percSteps = [0,1,1,0,0,0,0,0,0,0,1,1,0,0,1,0]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1177, 3791); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N08 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.52;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,67,0,74,0,0,0,76,81,76,0,69,0,76,0,76,69,69,0,0,76,72,81,0,67,0,67,69,84,0,74,81];
    ~melodyAmp = 0.24;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,0,0,0,0,0,0,0,1,1,0,0,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[N08 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \reese;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3591;
    ~melodyNotes = [0,0,45,45,45,0,0,0,48,0,0,0,0,41,45,53,41,0,36,0,0,45,46,0,0,38,0,45,36,0,45,0];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.21, 1177, \sin, 2791) };
    ~vcfOn !? { ~vcfOn.(\moog, 1377, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    78.wait;

    "[N08 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.47;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2791);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N08 6:00] === fin HAUNTED RIDE ===".postln;
}).play;
"=== TRACK N08 : HAUNTED RIDE 6 min lancee ===".postln;
)
