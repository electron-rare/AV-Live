// =====================================================================
//  E_vietnam_hard.scd
//
//  Hard dubstep vietnamien -- 8 minutes, 150 BPM half-time
//  - Melodie en pentatonique vietnamienne (Đờn ca tài tử)
//    notes : C D F G A (60, 62, 65, 67, 69) en majeur, 60 63 65 67 70 en mineur
//  - Synthe melodique \pipa (luth) puis \erhu (violon) + \growl (drop)
//  - Kick T4 distordu + snare crack + hat 16ths
//  - 2 drops, breakdown au gong, build avec snare roll
//
//  PREREQUIS : engine.scd ET synthdefs_asia.scd evalues.
//  Pour stopper en cours : (~track.stop;)
// =====================================================================

(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
[~chaosRoutine, ~breathRoutine, ~rythmRoutine, ~accelRoutine,
 ~filterSweep, ~introRoutine, ~outroRoutine,
 ~melodyEvolve, ~lRotate, ~randomLoop].do { |r| r !? { r.stop } };
~track !? { ~track.stop };

// Pentatonique vietnamienne (Đờn ca tài tử style)
~scaleVietnamMin = [60, 63, 65, 67, 70, 72, 75, 77];   // pent mineure
~scaleVietnamMaj = [60, 62, 65, 67, 69, 72, 74, 77];   // pent majeure (đờn xuân)

~track = Routine({
    "[E 0:00] === HARD DUBSTEP VIETNAM -- 8 min 150 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 150 / 60;

    // ------ 0:00 INTRO -- gong + pipa solo (melodie vietnamienne) ----
    "[E 0:00] intro gong + pipa...".postln;
    Synth(\gong, [\freq, 55, \decay, 6, \amp, 0.55]);
    ~melodyInst = \pipa;
    ~melodyAttack = 0.001; ~melodyRelease = 0.6;
    ~melodyCutoff = 4000; ~melodyDrive = 1.4;
    ~melodyAmp = 0.24;  ~melodyBoost = 1.8;
    // Phrase pent vietnamienne -- mineur ascendant (si bemol est la couleur asiatique)
    ~melodyNotes = [ 60, 0, 63,  0, 65, 67, 70,  0,
                     72, 0,  0, 70, 67,  0, 63, 60,
                     63, 0, 65,  0, 67, 70, 72, 75,
                     70, 67, 0, 65, 67, 0, 63, 60 ];
    ~kickSteps = (0 ! 16); ~snareSteps = (0 ! 16);
    ~hatSteps = (0 ! 16); ~clapSteps = (0 ! 16);
    ~percSteps = (0 ! 16); ~acidAmp = 0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\dubBass);
    20.wait;

    // ------ 0:20 ERHU vibrato par-dessus pipa ------------------------
    "[E 0:20] passage erhu (violon chinois)...".postln;
    ~melodyInst = \erhu;
    ~melodyAttack = 0.05; ~melodyRelease = 0.4;
    ~melodyCutoff = 2200;
    ~reload.value;
    20.wait;

    // ------ 0:40 KICK + HAT entrent (montee) ------------------------
    "[E 0:40] kick T4 + hat 16ths...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
    ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28;
    ~kickDrive = 3.5; ~kickClick = 0.3; ~kickAmp = 0.55;   // T4 distordu
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~snareAmp = 0.5; ~snareFreq = 230; ~snareNoiseAmt = 0.7; ~snareDecay = 0.13;
    ~reload.value;
    25.wait;

    // ------ 1:05 RISER + IMPACT vers DROP 1 ------------------------
    "[E 1:05] build vers DROP...".postln;
    Synth(\riser, [\dur, 8, \startCutoff, 300, \endCutoff, 10000, \amp, 0.25]);
    8.wait;
    Synth(\impact, [\freq, 38, \decay, 2.0, \amp, 0.5]);    // moins fort

    // ------ 1:13 DROP 1 -- GROWL hard dubstep + melodie pipa ---------
    "[E 1:13] === DROP 1 GROWL DUBSTEP ===".postln;
    ~melodyInst = \growl;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3;
    ~melodyCutoff = 250; ~melodyDrive = 3.0;          // moins violent
    ~melodyWobbleRate = 4; ~melodyWobbleDepth = 2500; ~melodyWobbleShape = 0;
    ~melodySubAmt = 0.7;                              // sub modere
    ~melodyAmp = 0.16; ~melodyBoost = 1.4;
    // Notes graves vietnamiennes (pentatonique mineure, octave -2)
    ~melodyNotes = [ 36, 0, 0, 0, 36, 0, 0, 39,
                     36, 0, 0, 0, 41, 0, 0, 0,
                     36, 0, 0, 39, 36, 0, 0, 41,
                     43, 0, 41, 0, 39, 0, 36, 0 ];
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.4;
    ~reload.value;
    // 90s de drop avec wobble qui mute
    18.do { |k|
        if (0.4.coin) {
            ~melodyWobbleRate = [2, 4, 4, 8].choose;
            ~melodyWobbleShape = [0, 0, 1].choose;
            ~melodyWobbleDepth = rrand(2000, 3500);
            ~reload.value;
            ("  -> wobble " ++ ~melodyWobbleRate ++ "Hz shape" ++ ~melodyWobbleShape).postln;
        };
        if (0.25.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2,
                [24, 36, 36, 39, 41, 43, 48]);
            ~reload.value;
        };
        5.wait;
    };
    // 2:43

    // ------ 2:43 BREAKDOWN -- erhu solo + gong --------------------
    "[E 2:43] breakdown erhu + gong vietnamien...".postln;
    Synth(\gong, [\freq, 70, \decay, 5, \amp, 0.5]);
    ~melodyInst = \erhu;
    ~melodyAttack = 0.05; ~melodyRelease = 0.5;
    ~melodyCutoff = 2000; ~melodyAmp = 0.22;
    ~kickSteps = (0 ! 16); ~snareSteps = (0 ! 16);
    ~clapSteps = (0 ! 16); ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
    ~hatAmp = 0.06;
    // Melodie expressive pentatonique majeure
    ~melodyNotes = [ 60, 0, 65, 0, 67, 0, 69, 0,
                     72, 0, 69, 67, 0, 65, 0, 60,
                     65, 0, 69, 0, 72, 0, 74, 0,
                     69, 67, 0, 65, 67, 0, 60, 0 ];
    ~reload.value;
    // Breakdown 30s avec mutations subtiles
    6.do { |k|
        if (0.3.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.15, ~scaleVietnamMaj);
            ~reload.value;
        };
        5.wait;
    };
    // 3:13

    // ------ 3:13 BUILD 2 -- snare roll + riser long --------------
    "[E 3:13] build 2 -- snare roll + riser...".postln;
    Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 12000, \amp, 0.4]);
    // Snare roll qui s'accelere
    16.do { |k|
        var rate = ((k / 4).floor + 2).min(8);
        if (k.mod((16 / rate).round.max(1)) == 0) {
            Synth(\snare, [\amp, 0.3 + (k * 0.015), \decay, 0.05]);
        };
        ~hatAmp = 0.06 + (k * 0.005);
        ~reload.value;
        1.wait;
    };
    // 3:29

    // ------ 3:29 DROP 2 -- GROWL CHOP + melodie hard ---------------
    "[E 3:29] === DROP 2 GROWL CHOP + Vietnam melody ===".postln;
    Synth(\impact, [\freq, 32, \decay, 2.5, \amp, 0.55]);
    0.1.wait;
    ~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.55;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.5;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
    ~melodyInst = \growl;
    ~melodyCutoff = 220; ~melodyDrive = 3.5;
    ~melodyWobbleRate = 8; ~melodyWobbleDepth = 3000;
    ~melodyWobbleShape = 1;          // CHOP
    ~melodySubAmt = 0.7;
    ~melodyAmp = 0.16;
    // Pattern hard syncope avec Bb (couleur asiatique)
    ~melodyNotes = [ 36, 0, 39, 0, 36, 0, 41, 0,
                     36, 39, 0, 41, 0, 0, 36, 0,
                     36, 0, 39, 41, 0, 43, 0, 41,
                     39, 0, 0, 36, 41, 0, 39, 36 ];
    ~reload.value;
    // 90s avec variations rapides
    18.do { |k|
        if (0.4.coin) {
            ~melodyWobbleRate = [4, 8, 8, 16].choose;
            ~melodyWobbleShape = [0, 1, 1].choose;
            ~melodyWobbleDepth = rrand(2200, 3800);
            ~reload.value;
        };
        if (0.3.coin) {
            // Garder l'ame vietnamienne dans les mutations
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, [24, 36, 39, 41, 43, 48]);
            ~reload.value;
        };
        if (0.1.coin) {
            // Snare ghost roll
            ~snareFill !? { ~snareFill.(4, 0.5, 0.3, 0.5) };
        };
        if (0.05.coin) { Synth(\impact, [\freq, 40, \decay, 1, \amp, 0.5]); };
        5.wait;
    };
    // 4:59

    // ------ 4:59 SECOND BREAKDOWN -- pipa + erhu duo ---------------
    "[E 4:59] duo pipa + erhu...".postln;
    Synth(\gong, [\freq, 60, \decay, 5, \amp, 0.45]);
    ~melodyInst = \pipa;
    ~melodyAttack = 0.001; ~melodyRelease = 0.5;
    ~melodyCutoff = 4500; ~melodyAmp = 0.22;
    ~kickSteps = (0 ! 16); ~snareSteps = (0 ! 16);
    ~clapSteps = (0 ! 16); ~hatSteps = (0 ! 16);
    ~melodyNotes = [ 72, 70, 67, 65, 63, 60, 0, 0,
                     65, 67, 70, 72, 75, 0, 0, 0,
                     72, 70, 67, 65, 67, 70, 72, 0,
                     75, 72, 70, 67, 65, 63, 60, 0 ];
    ~reload.value;
    25.wait;

    // ------ 5:24 DROP 3 FINAL -- combo growl + reese hard ---------
    "[E 5:24] === DROP 3 FINAL chaos ===".postln;
    Synth(\impact, [\freq, 30, \decay, 2.5, \amp, 0.6]);
    0.1.wait;
    ~kickSteps  = [1,0,1,0, 0,0,0,0, 1,0,0,0, 0,0,1,0]; ~kickAmp = 0.5;
    ~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.5;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.4;
    ~melodyInst = \growl;
    ~melodyCutoff = 200; ~melodyDrive = 4.0;
    ~melodyWobbleRate = 8; ~melodyWobbleDepth = 3500;
    ~melodyWobbleShape = 1; ~melodySubAmt = 0.8; ~melodyAmp = 0.18;
    ~reload.value;
    // 70s avec rotation timbre + chaos max
    14.do { |k|
        if (0.5.coin) {
            ~melodyInst = [\growl, \reeseHard, \growl].choose;
            ~melodyWobbleRate = [4, 8, 16].choose;
            ~melodyWobbleShape = [0, 1, 1].choose;
            ~reload.value;
            ("  -> " ++ ~melodyInst ++ " wobble " ++ ~melodyWobbleRate).postln;
        };
        if (0.3.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, [24, 36, 39, 41, 43, 48]);
            ~reload.value;
        };
        if (0.1.coin) { ~snareFill !? { ~snareFill.(8, 0.5, 0.3, 0.55) } };
        5.wait;
    };
    // 6:34

    // ------ 6:34 OUTRO -- gong + erhu qui s'efface ----------------
    "[E 6:34] new -- taiko + shakuhachi + ml10 vietnam epic...".postln;
    ~melodyInst = \shakuhachi;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = (~ml10 ? [60,0,65,0,67,0,69,0, 72,0,69,67,65,0,60,0]).copy;
    ~percInst = \taiko; ~tomFreq = 75; ~percAmp = 0.4;
    ~percSteps = [1,0,0,0, 0,0,1,0, 1,0,0,0, 0,1,0,0];
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.25, 1200, \sin, 3500) };
    ~fxPreset !? { ~fxPreset.(\space) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    35.wait;

    "[E 7:09] new -- guzheng + tabla + tapeReverse cinematic...".postln;
    ~melodyInst = \guzheng;
    ~melodyAttack = 0.001; ~melodyRelease = 0.7; ~melodyCutoff = 4500;
    ~melodyAmp = 0.22;
    ~percInst = \tabla; ~percAmp = 0.32;
    ~percSteps = [1,0,1,0, 0,1,0,1, 1,0,1,0, 0,1,0,0];
    ~tapeReverse !? { ~tapeReverse.(2.5) };
    ~vcfOn !? { ~vcfOn.(\formant, 800, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    25.wait;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };

    "[E 7:34] outro gong + erhu fade...".postln;
    Synth(\gong, [\freq, 50, \decay, 8, \amp, 0.6]);
    ~melodyInst = \erhu;
    ~melodyAttack = 0.06; ~melodyRelease = 0.6;
    ~melodyCutoff = 1800; ~melodyAmp = 0.22;
    ~melodyNotes = [ 60, 0, 0, 0, 65, 0, 0, 0,
                     67, 0, 0, 0, 70, 0, 0, 0,
                     67, 0, 0, 0, 65, 0, 0, 0,
                     63, 0, 0, 0, 60, 0, 0, 0 ];
    ~reload.value;
    // 90s d'outro avec fade lent
    45.do { |k|
        var x = 1 - ((k + 1) / 45);
        ~kickAmp = x * 0.55;
        ~snareAmp = x * 0.5;
        ~hatAmp = x * 0.10;
        ~clapAmp = x * 0.4;
        ~melodyAmp = x * 0.22;
        ~melodyCutoff = 200 + (x * 1600);
        ~reload.value;
        2.wait;
    };
    // 8:04
    Synth(\gong, [\freq, 40, \decay, 10, \amp, 0.7]);

    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[E 9:04] === fin HARD DUBSTEP VIETNAM ===".postln;
}).play;
"=== TRACK E : HARD DUBSTEP VIETNAM 8 min lancee ===".postln;
)


// =====================================================================
//  TWEAKS LIVE -- voir palette/tweaks_template.scd (charge dans 00_load)
//                 Ouvrir tweaks_template.scd et Cmd+Entree sur une ligne.
// =====================================================================

// =====================================================================
//  SECTIONS / JUMP TO -- voir jump.scd
//  Ouvrir jump.scd, evaluer SETUP JUMP, puis le bloc TRACK X correspondant,
//  puis Cmd+Entree sur la ligne ~jumpTo.('X', 'slug').
// =====================================================================
