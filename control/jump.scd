// =====================================================================
//  jump.scd  --  Lance n'importe quelle section d'une track
//
//  USAGE :
//    1. Charger 00_load.scd
//    2. Cmd+Entree sur SETUP JUMP (1 fois)
//    3. Cmd+Entree sur ~jumpTo.(\X, \section_slug) au choix
// =====================================================================

(  // SETUP JUMP
~sections = ();
~jumpTo = { |trackLetter, sectionSlug|
    var trackSec = ~sections[trackLetter.asSymbol];
    var section = trackSec !? { trackSec[sectionSlug.asSymbol] };
    if (section.isNil) {
        ("!! [" ++ trackLetter ++ " " ++ sectionSlug ++ "] inexistante").postln;
    } {
        // Stoppe la Routine track en cours pour eviter qu'elle ecrase la section
        ~track !? { ~track.stop; ~track = nil };
        ~filterSweep !? { ~filterSweep.stop; ~filterSweep = nil };
        ~randomLoop !? { ~randomLoop.stop; ~randomLoop = nil };
        ~melodyEvolve !? { ~melodyEvolve.stop; ~melodyEvolve = nil };
        ~lRotate !? { ~lRotate.stop; ~lRotate = nil };
        // Applique la section, recharge les Pdef, relance
        section.value;
        ~reload.value;
        [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
         \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
        ("[JUMP] [" ++ trackLetter ++ " " ++ sectionSlug ++ "]").postln;
    };
};
"=== ~jumpTo pret ===".postln;
)



// =====================================================================
//  TRACK A -- 5 sections (auto-extraites des postln)
// =====================================================================
(
~sections['A'] = (
    // [0:00] minimal -- kick T5 sub + melody PAD...
    minimal_kick_t5_sub_melody_pad: {
        ~bpm = 124; ~acidCutoff = 500; ~acidRq = 0.25; ~acidDrive = 1.5; ~acidAmp = 0.3;
        ~kickAmp = 0.5; ~hatAmp = 0.08; ~melodyAmp = 0.14;
        ~kickFreq = 42; ~kickPitchAmt = 2.0; ~kickDecay = 0.5;
        ~kickDrive = 1.0; ~kickClick = 0.05;             // T5 sub deep
        ~melodyInst = \pad;                              // PAD pour l'intro
        ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 1500;
        ~melodyNotes = [60,0,0,0,0,0,0,0, 67,0,0,0,0,0,0,0,
                        60,0,0,0,0,0,0,0, 65,0,0,0,0,0,0,0];
        TempoClock.default.tempo = ~bpm/60; ~reload.value;
        ~enableHarmony.(\third);
    },
    // [2:00] acid rave -- kick T1 + melody LEAD + variations...
    acid_rave_kick_t1_melody_lead_variations: {
        ~bpm = 132; ~acidCutoff = 800; ~acidRq = 0.15; ~acidDrive = 2.5;
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
        ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
        ~kickDrive = 1.3; ~kickClick = 0.2;
        ~melodyInst = \lead;                             // LEAD pour le drop
        ~melodyAttack = 0.012; ~melodyRelease = 0.25; ~melodyCutoff = 2400;
        ~melodyAmp = 0.16;
        ~acidNotes = [36,36,48,36,39,36,43,39, 36,41,36,39,43,36,36,41];
        ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
        ~melodyNotes = [60,0,67,0,70,0,67,65, 63,0,60,0,0,67,70,72,
                        75,0,72,70,67,0,0,65, 63,60,0,67,70,0,72,0];
        TempoClock.default.tempo = ~bpm/60; ~reload.value;
        // 120s avec micro-variations toutes les 4s
    },
    // [4:00] detroit stabs -- kick T2 + melody STAB...
    detroit_stabs_kick_t2_melody_stab: {
        ~bpm = 128; ~acidCutoff = 700; ~acidDrive = 2.2;
        ~kickFreq = 65; ~kickPitchAmt = 4.0; ~kickDecay = 0.18;
        ~kickDrive = 1.8; ~kickClick = 0.45;
        ~melodyInst = \stab;                             // STAB style Detroit
        ~melodyDrive = 2.8; ~melodyCutoff = 1500;
        ~melodyNotes = [63,0,0,0,70,0,67,0, 65,0,0,0,70,0,72,0,
                        63,0,0,0,67,0,70,0, 65,0,60,0,67,0,0,0];
        ~melodyAttack = 0.001; ~melodyRelease = 0.06;
        TempoClock.default.tempo = ~bpm/60; ~reload.value;
        // 90s avec stabs qui mutent (Detroit = Cm avec variations chromatiques)
    },
    // [5:30] hard push -- kick T4 distordu...
    hard_push_kick_t4_distordu: {
        ~bpm = 140; ~acidCutoff = 1500; ~acidRq = 0.08; ~acidDrive = 3.8;
        ~kickSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
        ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28;
        ~kickDrive = 3.5; ~kickClick = 0.3;              // T4 distordu
        ~melodyAmp = 0;
        TempoClock.default.tempo = ~bpm/60; ~reload.value;
    },
    // [6:30] outro -- melody PAD qui s'efface...
    outro_melody_pad_qui_s_efface: {
        ~melodyInst = \pad;                              // PAD doux pour finir
        ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyAmp = 0.12;
        ~reload.value;
    },
);
"=== sections A chargees : ".post; ~sections['A'].keys.asArray.postln;
)

// --- Lancer une section TRACK A ---
( ~jumpTo.('A', 'minimal_kick_t5_sub_melody_pad'); )  // [0:00] minimal -- kick T5 sub + melody PAD...
( ~jumpTo.('A', 'acid_rave_kick_t1_melody_lead_variations'); )  // [2:00] acid rave -- kick T1 + melody LEAD + variations...
( ~jumpTo.('A', 'detroit_stabs_kick_t2_melody_stab'); )  // [4:00] detroit stabs -- kick T2 + melody STAB...
( ~jumpTo.('A', 'hard_push_kick_t4_distordu'); )  // [5:30] hard push -- kick T4 distordu...
( ~jumpTo.('A', 'outro_melody_pad_qui_s_efface'); )  // [6:30] outro -- melody PAD qui s'efface...


// =====================================================================
//  TRACK B -- 6 sections (auto-extraites des postln)
// =====================================================================
(
~sections['B'] = (
    // [0:00] dub start -- kick T3 boomy + melody PAD...
    dub_start_kick_t3_boomy_melody_pad: {
        ~bpm = 110; ~acidCutoff = 400; ~acidRq = 0.2; ~acidDrive = 1.6; ~acidAmp = 0.22;
        ~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
        ~kickAmp = 0.45; ~hatAmp = 0.08;
        ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.6;
        ~kickDrive = 1.2; ~kickClick = 0.08;
        ~melodyInst = \pad;                              // PAD pour dub
        ~hatSteps = [0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,1,0];
        ~melodyNotes = [60,0,0,0,63,0,0,0, 67,0,0,0,70,0,0,0,
                        72,0,0,0,70,0,0,0, 67,0,0,0,63,0,0,0];
        ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyAmp = 0.14;
        ~melodyCutoff = 1500;
        TempoClock.default.tempo = ~bpm/60; ~reload.value;
        ~enableHarmony.(\bassline);
        // 150s de dub avec nappes qui mutent doucement
    },
    // [2:30] tempo monte 110->125 -- melody SAW3 (epaissit)...
    tempo_monte_110_125_melody_saw3_epaissit: {
        ~melodyInst = \saw3;                             // SAW3 pour epaisseur
        ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyDrive = 1.4;
        ~reload.value;
        // 3:30
    },
    // [3:30] kick 4/4 + acid ouvre -- kick T1 + melody PLUCK...
    kick_4_4_acid_ouvre_kick_t1_melody_pluck: {
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
        ~kickAmp = 0.5;
        ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
        ~kickDrive = 1.3; ~kickClick = 0.2;
        ~melodyInst = \pluck;                            // PLUCK pour la transition
        ~melodyAttack = 0.001; ~melodyRelease = 0.5; ~melodyCutoff = 5000;
        ~acidCutoff = 900; ~acidDrive = 2.2; ~acidAmp = 0.28;
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
        ~hatAmp = 0.14;
        ~reload.value;
        // 90s avec acid qui mute progressivement
        // remettre kick 4/4 propre avant la suite
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~reload.value;
    },
    // [5:00] tempo monte 125->140...
    tempo_monte_125_140: {
        // 6:00
    },
    // [6:00] hard push -- kick T4 distordu...
    hard_push_kick_t4_distordu: {
        ~kickSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
        ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28;
        ~kickDrive = 3.5; ~kickClick = 0.3;              // T4 distordu
        ~hatSteps = [0,1,1,1, 0,1,1,0, 0,1,1,1, 0,1,1,0];
        ~hatAmp = 0.15;
        ~acidCutoff = 1500; ~acidRq = 0.08; ~acidDrive = 3.5;
        ~melodyAmp = 0;
        ~reload.value;
    },
    // [7:30] outro -- melody PAD qui revient...
    outro_melody_pad_qui_revient: {
        ~melodyInst = \pad;                              // PAD pour finir
        ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyAmp = 0.10;
        ~reload.value;
    },
);
"=== sections B chargees : ".post; ~sections['B'].keys.asArray.postln;
)

// --- Lancer une section TRACK B ---
( ~jumpTo.('B', 'dub_start_kick_t3_boomy_melody_pad'); )  // [0:00] dub start -- kick T3 boomy + melody PAD...
( ~jumpTo.('B', 'tempo_monte_110_125_melody_saw3_epaissit'); )  // [2:30] tempo monte 110->125 -- melody SAW3 (epaissit)...
( ~jumpTo.('B', 'kick_4_4_acid_ouvre_kick_t1_melody_pluck'); )  // [3:30] kick 4/4 + acid ouvre -- kick T1 + melody PLUCK...
( ~jumpTo.('B', 'tempo_monte_125_140'); )  // [5:00] tempo monte 125->140...
( ~jumpTo.('B', 'hard_push_kick_t4_distordu'); )  // [6:00] hard push -- kick T4 distordu...
( ~jumpTo.('B', 'outro_melody_pad_qui_revient'); )  // [7:30] outro -- melody PAD qui revient...


// =====================================================================
//  TRACK C -- 6 sections (auto-extraites des postln)
// =====================================================================
(
~sections['C'] = (
    // [0:00] hypnotic -- kick T6 + fmBell DUBSTEP wobble...
    hypnotic_kick_t6_fmbell_dubstep_wobble: {
        ~bpm = 126; ~acidCutoff = 600; ~acidRq = 0.2; ~acidDrive = 1.8; ~acidAmp = 0.26;
        ~kickFreq = 70; ~kickPitchAmt = 3.5; ~kickDecay = 0.22;
        ~kickDrive = 2.0; ~kickClick = 0.35;
        ~melodyInst = \fmBell;                           // FM Bell dubstep
        ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 400;
        ~melodyDrive = 3.5;
        ~melodyWobbleRate = 4;
        ~melodyWobbleDepth = 1800;
        ~melodyWobbleShape = 0;
        ~melodySubAmt = 0.9;          // SUB MASSIF dubstep
        ~acidNotes = [36,0,36,0,36,0,41,0, 36,0,36,0,36,0,39,0];
        ~acidAccents = [1,0,0,0,1,0,0,0, 1,0,0,0,1,0,0,0];
        ~acidSlides = [0,0,0,0,0,0,1,0, 0,0,0,0,0,0,1,0];
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
        ~kickAmp = 0.5;
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
        ~hatAmp = 0.10;
        ~melodyNotes = [60,0,0,67,0,70,0,67, 60,0,0,67,0,70,0,72,
                        60,0,0,67,0,70,0,67, 63,0,0,70,0,72,0,75];
        ~melodyAmp = 0.13;
        TempoClock.default.tempo = ~bpm/60; ~reload.value;
        ~enableHarmony.(\arp);
        // 120s avec ostinato qui mute lentement (mutations + scales variees)
    },
    // [2:00] cutoff up doucement...
    cutoff_up_doucement: {
        // 4:00
    },
    // [4:00] hat 16ths -- kick T1 + melody SAW3 + variations...
    hat_16ths_kick_t1_melody_saw3_variations: {
        ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
        ~hatAmp = 0.08;
        ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
        ~kickDrive = 1.3; ~kickClick = 0.2;
        ~melodyInst = \saw3;
        ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 2200;
        ~melodyDrive = 1.4;
        ~reload.value;
        // 120s avec melodie qui se transforme (mutate + transpose + scales)
    },
    // [6:00] resonance push -- kick T2 + melody mute progressivement...
    resonance_push_kick_t2_melody_mute_progressivement: {
        ~kickFreq = 65; ~kickPitchAmt = 4.0; ~kickDecay = 0.18;
        ~kickDrive = 1.8; ~kickClick = 0.45;
        // 7:00
    },
    // [7:00] full ressu + chaos + rotation timbres + wobble dubstep...
    full_ressu_chaos_rotation_timbres_wobble_dubstep: {
    },
    // [9:00] outro long -- melody PAD qui s'efface lentement...
    outro_long_melody_pad_qui_s_efface_lentement: {
        ~melodyInst = \pad;                              // PAD pour finir
        ~melodyAttack = 0.6; ~melodyRelease = 2.5;
        ~reload.value;
    },
);
"=== sections C chargees : ".post; ~sections['C'].keys.asArray.postln;
)

// --- Lancer une section TRACK C ---
( ~jumpTo.('C', 'hypnotic_kick_t6_fmbell_dubstep_wobble'); )  // [0:00] hypnotic -- kick T6 + fmBell DUBSTEP wobble...
( ~jumpTo.('C', 'cutoff_up_doucement'); )  // [2:00] cutoff up doucement...
( ~jumpTo.('C', 'hat_16ths_kick_t1_melody_saw3_variations'); )  // [4:00] hat 16ths -- kick T1 + melody SAW3 + variations...
( ~jumpTo.('C', 'resonance_push_kick_t2_melody_mute_progressivement'); )  // [6:00] resonance push -- kick T2 + melody mute progressivement...
( ~jumpTo.('C', 'full_ressu_chaos_rotation_timbres_wobble_dubstep'); )  // [7:00] full ressu + chaos + rotation timbres + wobble dubstep...
( ~jumpTo.('C', 'outro_long_melody_pad_qui_s_efface_lentement'); )  // [9:00] outro long -- melody PAD qui s'efface lentement...


// =====================================================================
//  TRACK D -- 9 sections (auto-extraites des postln)
// =====================================================================
(
~sections['D'] = (
    // [0:00] === WOBBLE DROP -- 7 minutes 140 BPM ===
    wobble_drop_7_minutes_140_bpm: {
        TempoClock.default.tempo = 140 / 60;

        // ------ 0:00 INTRO -- pad atmospherique seul ------
    },
    // [0:00] intro pad sombre...
    intro_pad_sombre: {
        ~melodyInst = \pad;
        ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 1200;
        ~melodyAmp = 0.18;
        ~melodyNotes = [60, 0, 0, 0, 0, 0, 0, 0, 63, 0, 0, 0, 0, 0, 0, 0,
                        65, 0, 0, 0, 0, 0, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0];
        ~kickSteps = (0 ! 16); ~snareSteps = (0 ! 16);
        ~hatSteps = (0 ! 16); ~acidAmp = 0;
        ~reload.value;
        ~enableHarmony.(\dubBass);

        // ------ 0:30 DRUM ENTRY -- kick + snare half-time ------
    },
    // [0:30] drum entry half-time...
    drum_entry_half_time: {
        ~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
        ~kickFreq = 48; ~kickPitchAmt = 3.5; ~kickDecay = 0.5;
        ~kickDrive = 1.5; ~kickClick = 0.15; ~kickAmp = 0.6;
        ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
        ~snareAmp = 0.45; ~snareFreq = 220; ~snareNoiseAmt = 0.65; ~snareDecay = 0.16;
        ~reload.value;

        // ------ 1:00 BUILD -- hat 16ths + riser ------
    },
    // [1:00] build avec hat 16ths + riser...
    build_avec_hat_16ths_riser: {
        ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
        ~reload.value;
        Synth(\riser, [\dur, 12, \startCutoff, 200, \endCutoff, 8000, \amp, 0.25]);

        // ------ 1:12 IMPACT + DROP 1 ------
    },
    // [1:12] === IMPACT + DROP 1 wobble dubstep ===
    impact_drop_1_wobble_dubstep: {
        Synth(\impact, [\freq, 45, \decay, 1.8, \amp, 0.7]);
        ~melodyInst = \fmBell;
        ~melodyAttack = 0.005; ~melodyRelease = 0.4;
        ~melodyCutoff = 350; ~melodyDrive = 4.0;
        ~melodyWobbleRate = 4; ~melodyWobbleDepth = 2200;
        ~melodyWobbleShape = 0; ~melodySubAmt = 0.95;
        ~melodyAmp = 0.20; ~melodyBoost = 1.8;
        ~melodyNotes = [36, 0, 0, 0, 36, 0, 0, 0,
                        39, 0, 0, 0, 39, 0, 0, 0,
                        36, 0, 0, 0, 36, 0, 0, 0,
                        41, 0, 0, 0, 39, 0, 0, 0];
        ~hatAmp = 0.08;
        ~reload.value;
        // 2:42

        // ------ 2:42 MID BREAKDOWN ------
    },
    // [2:42] mid breakdown -- pad seul...
    mid_breakdown_pad_seul: {
        ~kickSteps = (0 ! 16); ~snareSteps = (0 ! 16);
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
        ~melodyInst = \pad;
        ~melodyAttack = 0.6; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
        ~melodyAmp = 0.16;
        ~melodyNotes = [60, 0, 0, 0, 63, 0, 0, 0, 65, 0, 0, 0, 67, 0, 0, 0,
                        65, 0, 0, 0, 63, 0, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0];
        ~reload.value;

        // ------ 3:12 BUILD 2 -- snare roll + riser ------
    },
    // [3:12] build 2 avec snare roll...
    build_2_avec_snare_roll: {
        Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 9000, \amp, 0.3]);
        // 3:28

        // ------ 3:28 IMPACT + DROP 2 -- wobble CHOP ------
    },
    // [3:28] === IMPACT + DROP 2 wobble chop ===
    impact_drop_2_wobble_chop: {
        Synth(\impact, [\freq, 40, \decay, 2.0, \amp, 0.75]);
        ~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
        ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
        ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
        ~melodyInst = \fmBell;
        ~melodyAttack = 0.005; ~melodyRelease = 0.3;
        ~melodyCutoff = 300; ~melodyDrive = 4.5;
        ~melodyWobbleRate = 8; ~melodyWobbleDepth = 2800;
        ~melodyWobbleShape = 1;          // CHOP square wobble
        ~melodySubAmt = 1.0;
        ~melodyAmp = 0.22;
        ~melodyNotes = [36, 0, 39, 0, 36, 0, 0, 41,
                        36, 0, 39, 41, 0, 0, 36, 0,
                        36, 0, 39, 0, 36, 0, 43, 41,
                        39, 0, 0, 36, 0, 41, 39, 0];
        ~reload.value;
        // 5:08

        // ------ 5:08 OUTRO -- fade out ------
    },
    // [5:08] outro fade...
    outro_fade: {
        ~melodyInst = \pad;
        ~melodyAttack = 0.6; ~melodyRelease = 2.5; ~melodyCutoff = 800;
        ~reload.value;
        // 7:08
    },
);
"=== sections D chargees : ".post; ~sections['D'].keys.asArray.postln;
)

// --- Lancer une section TRACK D ---
( ~jumpTo.('D', 'wobble_drop_7_minutes_140_bpm'); )  // [0:00] === WOBBLE DROP -- 7 minutes 140 BPM ===
( ~jumpTo.('D', 'intro_pad_sombre'); )  // [0:00] intro pad sombre...
( ~jumpTo.('D', 'drum_entry_half_time'); )  // [0:30] drum entry half-time...
( ~jumpTo.('D', 'build_avec_hat_16ths_riser'); )  // [1:00] build avec hat 16ths + riser...
( ~jumpTo.('D', 'impact_drop_1_wobble_dubstep'); )  // [1:12] === IMPACT + DROP 1 wobble dubstep ===
( ~jumpTo.('D', 'mid_breakdown_pad_seul'); )  // [2:42] mid breakdown -- pad seul...
( ~jumpTo.('D', 'build_2_avec_snare_roll'); )  // [3:12] build 2 avec snare roll...
( ~jumpTo.('D', 'impact_drop_2_wobble_chop'); )  // [3:28] === IMPACT + DROP 2 wobble chop ===
( ~jumpTo.('D', 'outro_fade'); )  // [5:08] outro fade...


// =====================================================================
//  TRACK E -- 11 sections (auto-extraites des postln)
// =====================================================================
(
~sections['E'] = (
    // [0:00] === HARD DUBSTEP VIETNAM -- 8 min 150 BPM ===
    hard_dubstep_vietnam_8_min_150_bpm: {
        TempoClock.default.tempo = 150 / 60;

        // ------ 0:00 INTRO -- gong + pipa solo (melodie vietnamienne) ----
    },
    // [0:00] intro gong + pipa...
    intro_gong_pipa: {
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
        ~enableHarmony.(\dubBass);

        // ------ 0:20 ERHU vibrato par-dessus pipa ------------------------
    },
    // [0:20] passage erhu (violon chinois)...
    passage_erhu_violon_chinois: {
        ~melodyInst = \erhu;
        ~melodyAttack = 0.05; ~melodyRelease = 0.4;
        ~melodyCutoff = 2200;
        ~reload.value;

        // ------ 0:40 KICK + HAT entrent (montee) ------------------------
    },
    // [0:40] kick T4 + hat 16ths...
    kick_t4_hat_16ths: {
        ~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
        ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28;
        ~kickDrive = 3.5; ~kickClick = 0.3; ~kickAmp = 0.55;   // T4 distordu
        ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
        ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
        ~snareAmp = 0.5; ~snareFreq = 230; ~snareNoiseAmt = 0.7; ~snareDecay = 0.13;
        ~reload.value;

        // ------ 1:05 RISER + IMPACT vers DROP 1 ------------------------
    },
    // [1:05] build vers DROP...
    build_vers_drop: {
        Synth(\riser, [\dur, 8, \startCutoff, 300, \endCutoff, 10000, \amp, 0.25]);
        Synth(\impact, [\freq, 38, \decay, 2.0, \amp, 0.5]);    // moins fort

        // ------ 1:13 DROP 1 -- GROWL hard dubstep + melodie pipa ---------
    },
    // [1:13] === DROP 1 GROWL DUBSTEP ===
    drop_1_growl_dubstep: {
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
        // 2:43

        // ------ 2:43 BREAKDOWN -- erhu solo + gong --------------------
    },
    // [2:43] breakdown erhu + gong vietnamien...
    breakdown_erhu_gong_vietnamien: {
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
        // 3:13

        // ------ 3:13 BUILD 2 -- snare roll + riser long --------------
    },
    // [3:13] build 2 -- snare roll + riser...
    build_2_snare_roll_riser: {
        Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 12000, \amp, 0.4]);
        // Snare roll qui s'accelere
        // 3:29

        // ------ 3:29 DROP 2 -- GROWL CHOP + melodie hard ---------------
    },
    // [3:29] === DROP 2 GROWL CHOP + Vietnam melody ===
    drop_2_growl_chop_vietnam_melody: {
        Synth(\impact, [\freq, 32, \decay, 2.5, \amp, 0.55]);
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
        // 4:59

        // ------ 4:59 SECOND BREAKDOWN -- pipa + erhu duo ---------------
    },
    // [4:59] duo pipa + erhu...
    duo_pipa_erhu: {
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

        // ------ 5:24 DROP 3 FINAL -- combo growl + reese hard ---------
    },
    // [6:34] outro gong + erhu fade...
    outro_gong_erhu_fade: {
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
        // 8:04
        Synth(\gong, [\freq, 40, \decay, 10, \amp, 0.7]);
    },
);
"=== sections E chargees : ".post; ~sections['E'].keys.asArray.postln;
)

// --- Lancer une section TRACK E ---
( ~jumpTo.('E', 'hard_dubstep_vietnam_8_min_150_bpm'); )  // [0:00] === HARD DUBSTEP VIETNAM -- 8 min 150 BPM ===
( ~jumpTo.('E', 'intro_gong_pipa'); )  // [0:00] intro gong + pipa...
( ~jumpTo.('E', 'passage_erhu_violon_chinois'); )  // [0:20] passage erhu (violon chinois)...
( ~jumpTo.('E', 'kick_t4_hat_16ths'); )  // [0:40] kick T4 + hat 16ths...
( ~jumpTo.('E', 'build_vers_drop'); )  // [1:05] build vers DROP...
( ~jumpTo.('E', 'drop_1_growl_dubstep'); )  // [1:13] === DROP 1 GROWL DUBSTEP ===
( ~jumpTo.('E', 'breakdown_erhu_gong_vietnamien'); )  // [2:43] breakdown erhu + gong vietnamien...
( ~jumpTo.('E', 'build_2_snare_roll_riser'); )  // [3:13] build 2 -- snare roll + riser...
( ~jumpTo.('E', 'drop_2_growl_chop_vietnam_melody'); )  // [3:29] === DROP 2 GROWL CHOP + Vietnam melody ===
( ~jumpTo.('E', 'duo_pipa_erhu'); )  // [4:59] duo pipa + erhu...
( ~jumpTo.('E', 'outro_gong_erhu_fade'); )  // [6:34] outro gong + erhu fade...


// =====================================================================
//  TRACK F -- 10 sections (auto-extraites des postln)
// =====================================================================
(
~sections['F'] = (
    // [0:00] === TRANCE UPLIFTER 138 BPM ===
    trance_uplifter_138_bpm: {
        TempoClock.default.tempo = 138 / 60;
    },
    // [0:00] intro warmPad...
    intro_warmpad: {
        ~melodyInst = \warmPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
        ~melodyCutoff = 1800; ~melodyAmp = 0.18;
        ~melodyNotes = [60,0,0,0,67,0,0,0, 70,0,0,0,72,0,0,0,
                        72,0,0,0,70,0,0,0, 67,0,0,0,63,0,0,0];
        ~kickSteps = (0!16); ~hatSteps = (0!16); ~snareSteps = (0!16);
        ~clapSteps = (0!16); ~percSteps = (0!16); ~acidAmp = 0;
        ~reload.value;
        ~enableHarmony.(\tranceLayer);
    },
    // [0:45] kick 4/4 + hat offbeat...
    kick_4_4_hat_offbeat: {
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
        ~kickFreq = 50; ~kickPitchAmt = 2.8; ~kickDecay = 0.32; ~kickClick = 0.15;
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.3;
        ~reload.value;
    },
    // [1:30] arp squareLead entre...
    arp_squarelead_entre: {
        ~melodyInst = \squareLead;
        ~melodyAttack = 0.005; ~melodyRelease = 0.2; ~melodyCutoff = 5000;
        ~melodyAmp = 0.16;
        ~melodyNotes = [60, 67, 70, 72, 70, 67, 60, 67,
                        63, 70, 72, 75, 72, 70, 63, 70,
                        65, 72, 75, 77, 75, 72, 65, 72,
                        63, 70, 72, 75, 72, 70, 63, 60];
        ~reload.value;
    },
    // [2:30] BUILD vers DROP...
    build_vers_drop: {
        Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 11000, \amp, 0.3]);
        Synth(\impact, [\freq, 45, \decay, 2.5, \amp, 0.6]);
    },
    // [2:46] === DROP organLead trance ===
    drop_organlead_trance: {
        ~melodyInst = \organLead;
        ~melodyAttack = 0.005; ~melodyRelease = 0.15; ~melodyCutoff = 4500;
        ~melodyAmp = 0.20;
        ~kickAmp = 0.55;
        ~reload.value;
    },
    // [4:16] verse hardLead...
    verse_hardlead: {
        ~melodyInst = \hardLead;
        ~melodyAttack = 0.002; ~melodyRelease = 0.25; ~melodyCutoff = 5500;
        ~reload.value;
    },
    // [5:16] breakdown choir + strings...
    breakdown_choir_strings: {
        ~kickSteps = (0!16); ~hatAmp = 0.06; ~clapSteps = (0!16);
        ~melodyInst = \choir;
        ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [60, 0, 0, 0, 63, 0, 0, 0, 67, 0, 0, 0, 70, 0, 0, 0,
                        72, 0, 0, 0, 70, 0, 0, 0, 67, 0, 0, 0, 63, 0, 0, 0];
        ~reload.value;
    },
    // [6:01] BUILD 2 + impact final...
    build_2_impact_final: {
        Synth(\riser, [\dur, 16, \startCutoff, 500, \endCutoff, 12000, \amp, 0.4]);
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
        ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
        Synth(\impact, [\freq, 38, \decay, 3, \amp, 0.7]);
        Synth(\crash, [\decay, 4, \amp, 0.4]);
    },
    // [8:47] outro warmPad fade...
    outro_warmpad_fade: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.6; ~melodyRelease = 2.5; ~melodyCutoff = 1500;
        ~reload.value;
    },
);
"=== sections F chargees : ".post; ~sections['F'].keys.asArray.postln;
)

// --- Lancer une section TRACK F ---
( ~jumpTo.('F', 'trance_uplifter_138_bpm'); )  // [0:00] === TRANCE UPLIFTER 138 BPM ===
( ~jumpTo.('F', 'intro_warmpad'); )  // [0:00] intro warmPad...
( ~jumpTo.('F', 'kick_4_4_hat_offbeat'); )  // [0:45] kick 4/4 + hat offbeat...
( ~jumpTo.('F', 'arp_squarelead_entre'); )  // [1:30] arp squareLead entre...
( ~jumpTo.('F', 'build_vers_drop'); )  // [2:30] BUILD vers DROP...
( ~jumpTo.('F', 'drop_organlead_trance'); )  // [2:46] === DROP organLead trance ===
( ~jumpTo.('F', 'verse_hardlead'); )  // [4:16] verse hardLead...
( ~jumpTo.('F', 'breakdown_choir_strings'); )  // [5:16] breakdown choir + strings...
( ~jumpTo.('F', 'build_2_impact_final'); )  // [6:01] BUILD 2 + impact final...
( ~jumpTo.('F', 'outro_warmpad_fade'); )  // [8:47] outro warmPad fade...


// =====================================================================
//  TRACK G -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['G'] = (
    // [0:00] === DETROIT SOULFUL 124 BPM ===
    detroit_soulful_124_bpm: {
        TempoClock.default.tempo = 124 / 60;
    },
    // [0:00] intro warmPad accords...
    intro_warmpad_accords: {
        ~melodyInst = \warmPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
        ~melodyCutoff = 1800; ~melodyAmp = 0.18;
        ~melodyNotes = [60,0,0,0, 63,0,0,0, 67,0,0,0, 70,0,0,0,
                        72,0,0,0, 70,0,0,0, 67,0,0,0, 63,0,0,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\chord);
    },
    // [0:30] kick 4/4 + clap...
    kick_4_4_clap: {
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
        ~kickFreq = 50; ~kickPitchAmt = 2.8; ~kickDecay = 0.35; ~kickClick = 0.12;
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
        ~reload.value;
    },
    // [1:00] organ stabs Detroit...
    organ_stabs_detroit: {
        ~melodyInst = \organLead;
        ~melodyAttack = 0.005; ~melodyRelease = 0.15; ~melodyCutoff = 4500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [63,0,0,0, 67,0,70,0, 65,0,0,0, 70,0,72,0,
                        63,0,0,0, 67,0,70,0, 60,0,67,0, 63,0,0,0];
        ~reload.value;
    },
    // [2:00] verse hardLead phrase...
    verse_hardlead_phrase: {
        ~melodyInst = \hardLead;
        ~melodyAttack = 0.003; ~melodyRelease = 0.25; ~melodyCutoff = 5000;
        ~melodyNotes = [60,67,72,75, 70,67,63,60, 65,70,75,77, 72,70,67,63,
                        63,70,75,79, 75,72,70,67, 60,65,70,75, 67,63,60,0];
        ~reload.value;
    },
    // [3:00] breakdown strings + choir...
    breakdown_strings_choir: {
        ~kickSteps=(0!16); ~hatAmp=0.06; ~clapSteps=(0!16);
        ~melodyInst = \strings;
        ~melodyAttack = 0.3; ~melodyRelease = 1.2; ~melodyCutoff = 3500;
        ~melodyAmp = 0.20;
        ~melodyNotes = [60,0,0,0, 67,0,0,0, 70,0,0,0, 72,0,0,0,
                        70,0,0,0, 67,0,0,0, 63,0,0,0, 60,0,0,0];
        ~reload.value;
    },
    // [3:45] DROP retour + organ...
    drop_retour_organ: {
        Synth(\impact, [\freq, 45, \decay, 2, \amp, 0.5]);
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
        ~melodyInst = \organLead;
        ~melodyAttack = 0.005; ~melodyRelease = 0.15; ~melodyCutoff = 5500;
        ~reload.value;
    },
    // [5:45] outro warmPad fade...
    outro_warmpad_fade: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
        ~reload.value;
    },
);
"=== sections G chargees : ".post; ~sections['G'].keys.asArray.postln;
)

// --- Lancer une section TRACK G ---
( ~jumpTo.('G', 'detroit_soulful_124_bpm'); )  // [0:00] === DETROIT SOULFUL 124 BPM ===
( ~jumpTo.('G', 'intro_warmpad_accords'); )  // [0:00] intro warmPad accords...
( ~jumpTo.('G', 'kick_4_4_clap'); )  // [0:30] kick 4/4 + clap...
( ~jumpTo.('G', 'organ_stabs_detroit'); )  // [1:00] organ stabs Detroit...
( ~jumpTo.('G', 'verse_hardlead_phrase'); )  // [2:00] verse hardLead phrase...
( ~jumpTo.('G', 'breakdown_strings_choir'); )  // [3:00] breakdown strings + choir...
( ~jumpTo.('G', 'drop_retour_organ'); )  // [3:45] DROP retour + organ...
( ~jumpTo.('G', 'outro_warmpad_fade'); )  // [5:45] outro warmPad fade...


// =====================================================================
//  TRACK H -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['H'] = (
    // [0:00] === ACID TRANCE 145 BPM ===
    acid_trance_145_bpm: {
        TempoClock.default.tempo = 145 / 60;
    },
    // [0:00] intro pad...
    intro_pad: {
        ~melodyInst = \warmPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
        ~melodyCutoff = 1800; ~melodyAmp = 0.16;
        ~melodyNotes = [60,0,0,0,0,0,0,0, 67,0,0,0,0,0,0,0,
                        63,0,0,0,0,0,0,0, 70,0,0,0,0,0,0,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16);
        ~acidNotes = [36,36,48,36,39,36,43,39, 36,41,36,39,43,36,36,41];
        ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
        ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
        ~acidCutoff = 600; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0;
        ~reload.value;
        ~enableHarmony.(\tranceLayer);
    },
    // [0:30] kick 4/4 trance + acid entre...
    kick_4_4_trance_acid_entre: {
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
        ~kickFreq = 60; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.2;
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.3;
        ~acidAmp = 0.28;
        ~reload.value;
    },
    // [1:15] BUILD long vers DROP acid...
    build_long_vers_drop_acid: {
        Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 12000, \amp, 0.35]);
        Synth(\impact, [\freq, 45, \decay, 2.5, \amp, 0.6]);
    },
    // [1:31] === DROP ACID + lead arp ===
    drop_acid_lead_arp: {
        ~melodyInst = \squareLead;
        ~melodyAttack = 0.003; ~melodyRelease = 0.15; ~melodyCutoff = 6000;
        ~melodyAmp = 0.16;
        ~melodyNotes = [60, 67, 72, 75, 70, 67, 60, 67,
                        63, 70, 75, 77, 72, 70, 63, 67,
                        65, 72, 75, 79, 75, 72, 65, 67,
                        60, 67, 72, 75, 70, 67, 63, 60];
        ~reload.value;
    },
    // [3:01] breakdown choir + acid mute...
    breakdown_choir_acid_mute: {
        ~kickSteps=(0!16); ~hatAmp=0.05; ~clapSteps=(0!16);
        ~acidAmp = 0;
        ~melodyInst = \choir;
        ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2500;
        ~melodyAmp = 0.20;
        ~reload.value;
    },
    // [3:46] BUILD 2 + DROP FINAL...
    build_2_drop_final: {
        Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 13000, \amp, 0.4]);
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
        Synth(\impact, [\freq, 38, \decay, 3, \amp, 0.7]);
        Synth(\crash, [\decay, 4, \amp, 0.4]);
    },
    // [6:32] outro fade...
    outro_fade: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.6; ~melodyRelease = 2.5;
        ~reload.value;
    },
);
"=== sections H chargees : ".post; ~sections['H'].keys.asArray.postln;
)

// --- Lancer une section TRACK H ---
( ~jumpTo.('H', 'acid_trance_145_bpm'); )  // [0:00] === ACID TRANCE 145 BPM ===
( ~jumpTo.('H', 'intro_pad'); )  // [0:00] intro pad...
( ~jumpTo.('H', 'kick_4_4_trance_acid_entre'); )  // [0:30] kick 4/4 trance + acid entre...
( ~jumpTo.('H', 'build_long_vers_drop_acid'); )  // [1:15] BUILD long vers DROP acid...
( ~jumpTo.('H', 'drop_acid_lead_arp'); )  // [1:31] === DROP ACID + lead arp ===
( ~jumpTo.('H', 'breakdown_choir_acid_mute'); )  // [3:01] breakdown choir + acid mute...
( ~jumpTo.('H', 'build_2_drop_final'); )  // [3:46] BUILD 2 + DROP FINAL...
( ~jumpTo.('H', 'outro_fade'); )  // [6:32] outro fade...


// =====================================================================
//  TRACK I -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['I'] = (
    // [0:00] === LIQUID DNB 174 BPM ===
    liquid_dnb_174_bpm: {
        TempoClock.default.tempo = 174 / 60;
    },
    // [0:00] intro warmPad...
    intro_warmpad: {
        ~melodyInst = \warmPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
        ~melodyCutoff = 2000; ~melodyAmp = 0.18;
        ~melodyNotes = [60,0,0,0,0,0,0,0, 67,0,0,0,0,0,0,0,
                        63,0,0,0,0,0,0,0, 70,0,0,0,0,0,0,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\bassline);
    },
    // [0:20] amen break entre...
    amen_break_entre: {
        ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.5;
        ~kickFreq = 55; ~kickPitchAmt = 4.0; ~kickDecay = 0.18; ~kickClick = 0.3;
        ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.5;
        ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
        ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.12;
        ~reload.value;
    },
    // [1:00] smooth lead par-dessus...
    smooth_lead_par_dessus: {
        ~melodyInst = \fmLead;
        ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
        ~melodyAmp = 0.16;
        ~melodyNotes = [60,0,67,0,70,0,67,65, 63,0,60,0,0,67,70,72,
                        75,0,72,70,67,0,0,65, 63,60,0,67,70,0,72,0];
        ~reload.value;
    },
    // [2:20] reese sub bass entre...
    reese_sub_bass_entre: {
        ~acidAmp = 0;
        ~kickAmp = 0.55;
        // sub bass via melody 2eme couche par modification
        ~melodyInst = \subBoom;
        ~melodyAttack = 0.005; ~melodyRelease = 0.6;
        ~melodyAmp = 0.30;
        ~melodyNotes = [36,0,0,0, 36,0,0,0, 39,0,0,0, 41,0,0,0,
                        36,0,0,0, 36,0,0,0, 41,0,0,0, 39,0,0,0];
        ~reload.value;
    },
    // [3:20] breakdown smooth choir...
    breakdown_smooth_choir: {
        ~kickSteps=(0!16); ~snareSteps=(0!16); ~hatAmp=0.06;
        ~melodyInst = \choir;
        ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2800;
        ~melodyAmp = 0.20;
        ~melodyNotes = [60,0,0,0,67,0,0,0, 70,0,0,0,72,0,0,0,
                        70,0,0,0,67,0,0,0, 63,0,0,0,60,0,0,0];
        ~reload.value;
    },
    // [4:00] DROP retour amen + lead...
    drop_retour_amen_lead: {
        Synth(\impact, [\freq, 45, \decay, 2, \amp, 0.5]);
        ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0];
        ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1];
        ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.13;
        ~melodyInst = \fmLead;
        ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [60,67,72,75, 70,67,63,60, 65,70,75,77, 72,70,67,63,
                        63,70,75,79, 75,72,70,67, 60,65,70,75, 67,63,60,0];
        ~reload.value;
    },
    // [6:00] outro pad fade...
    outro_pad_fade: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.5; ~melodyRelease = 2.0;
        ~reload.value;
    },
);
"=== sections I chargees : ".post; ~sections['I'].keys.asArray.postln;
)

// --- Lancer une section TRACK I ---
( ~jumpTo.('I', 'liquid_dnb_174_bpm'); )  // [0:00] === LIQUID DNB 174 BPM ===
( ~jumpTo.('I', 'intro_warmpad'); )  // [0:00] intro warmPad...
( ~jumpTo.('I', 'amen_break_entre'); )  // [0:20] amen break entre...
( ~jumpTo.('I', 'smooth_lead_par_dessus'); )  // [1:00] smooth lead par-dessus...
( ~jumpTo.('I', 'reese_sub_bass_entre'); )  // [2:20] reese sub bass entre...
( ~jumpTo.('I', 'breakdown_smooth_choir'); )  // [3:20] breakdown smooth choir...
( ~jumpTo.('I', 'drop_retour_amen_lead'); )  // [4:00] DROP retour amen + lead...
( ~jumpTo.('I', 'outro_pad_fade'); )  // [6:00] outro pad fade...


// =====================================================================
//  TRACK J -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['J'] = (
    // [0:00] === AMBIENT CINEMATIQUE 80 BPM ===
    ambient_cinematique_80_bpm: {
        TempoClock.default.tempo = 80 / 60;
    },
    // [0:00] drone seul...
    drone_seul: {
        ~melodyInst = \drone;
        ~melodyAttack = 1.5; ~melodyRelease = 3.0; ~melodyCutoff = 1500;
        ~melodyAmp = 0.20;
        ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                        48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\cinematic);
        Synth(\gong, [\freq, 50, \decay, 8, \amp, 0.5]);
    },
    // [1:00] strings entrent...
    strings_entrent: {
        ~melodyInst = \strings;
        ~melodyAttack = 0.4; ~melodyRelease = 1.2; ~melodyCutoff = 3500;
        ~melodyAmp = 0.20;
        ~melodyNotes = [60,0,0,0, 63,0,0,0, 67,0,0,0, 70,0,0,0,
                        72,0,0,0, 70,0,0,0, 67,0,0,0, 63,0,0,0];
        ~reload.value;
    },
    // [2:30] choir mystique...
    choir_mystique: {
        Synth(\gong, [\freq, 60, \decay, 10, \amp, 0.4]);
        ~melodyInst = \choir;
        ~melodyAttack = 0.5; ~melodyRelease = 1.8; ~melodyCutoff = 2800;
        ~melodyAmp = 0.22;
        ~melodyNotes = [60,0,0,0,0,67,0,0, 70,0,0,0,72,0,0,0,
                        75,0,0,0,72,0,0,0, 70,0,0,0,67,0,0,0];
        ~reload.value;
    },
    // [4:30] handpan emerge (rythme doux)...
    handpan_emerge_rythme_doux: {
        ~percInst = \tom;
        ~percSteps = [1,0,0,0, 0,0,0,1, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.18;
        ~tomFreq = 70;
        ~melodyInst = \handpan;
        ~melodyAttack = 0.001; ~melodyRelease = 1.8; ~melodyCutoff = 5000;
        ~melodyAmp = 0.22;
        ~melodyNotes = [60,0,67,0,70,0,72,0, 75,0,72,70,67,0,63,60,
                        63,0,67,0,70,0,75,0, 79,0,75,72,70,0,65,60];
        ~reload.value;
    },
    // [6:30] flute melodique...
    flute_melodique: {
        ~melodyInst = \flute;
        ~melodyAttack = 0.08; ~melodyRelease = 0.5; ~melodyCutoff = 4000;
        ~melodyAmp = 0.20;
        ~melodyNotes = [72,0,75,0,77,0,75,72, 70,0,72,75,72,70,67,0,
                        77,0,79,0,82,0,79,77, 75,0,77,0,72,0,70,0];
        ~reload.value;
    },
    // [9:00] retour drone profond...
    retour_drone_profond: {
        Synth(\gong, [\freq, 40, \decay, 12, \amp, 0.6]);
        ~percSteps = (0!16);
        ~melodyInst = \drone;
        ~melodyAttack = 1.5; ~melodyRelease = 3.0; ~melodyCutoff = 1200;
        ~melodyAmp = 0.18;
        ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                        36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
        ~reload.value;
    },
    // [10:30] outro lent...
    outro_lent: {
        Synth(\gong, [\freq, 35, \decay, 15, \amp, 0.7]);
    },
);
"=== sections J chargees : ".post; ~sections['J'].keys.asArray.postln;
)

// --- Lancer une section TRACK J ---
( ~jumpTo.('J', 'ambient_cinematique_80_bpm'); )  // [0:00] === AMBIENT CINEMATIQUE 80 BPM ===
( ~jumpTo.('J', 'drone_seul'); )  // [0:00] drone seul...
( ~jumpTo.('J', 'strings_entrent'); )  // [1:00] strings entrent...
( ~jumpTo.('J', 'choir_mystique'); )  // [2:30] choir mystique...
( ~jumpTo.('J', 'handpan_emerge_rythme_doux'); )  // [4:30] handpan emerge (rythme doux)...
( ~jumpTo.('J', 'flute_melodique'); )  // [6:30] flute melodique...
( ~jumpTo.('J', 'retour_drone_profond'); )  // [9:00] retour drone profond...
( ~jumpTo.('J', 'outro_lent'); )  // [10:30] outro lent...


// =====================================================================
//  TRACK K -- 9 sections (auto-extraites des postln)
// =====================================================================
(
~sections['K'] = (
    // [0:00] === TRIBAL ETHNO 100 BPM ===
    tribal_ethno_100_bpm: {
        TempoClock.default.tempo = 100 / 60;
    },
    // [0:00] tom + handpan intro...
    tom_handpan_intro: {
        ~melodyInst = \handpan;
        ~melodyAttack = 0.001; ~melodyRelease = 1.5; ~melodyCutoff = 5000;
        ~melodyAmp = 0.22;
        ~melodyNotes = [60,0,67,0,70,0,72,0, 70,67,0,63,0,0,60,0,
                        63,0,67,0,70,0,75,0, 70,0,67,0,63,0,60,0];
        ~percInst = \tom; ~tomFreq = 90;
        ~percSteps = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0]; ~percAmp = 0.4;
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16); ~clapSteps=(0!16);
        ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\fifth);
    },
    // [0:45] kick lent + tom plus dense...
    kick_lent_tom_plus_dense: {
        ~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.5;
        ~kickFreq = 50; ~kickPitchAmt = 2.5; ~kickDecay = 0.4; ~kickClick = 0.1;
        ~percSteps = [1,0,1,1, 0,1,0,1, 1,0,1,0, 0,1,1,0]; ~percAmp = 0.35;
        ~reload.value;
    },
    // [1:30] flute chante par-dessus...
    flute_chante_par_dessus: {
        ~melodyInst = \flute;
        ~melodyAttack = 0.08; ~melodyRelease = 0.4; ~melodyCutoff = 3500;
        ~melodyAmp = 0.20;
        ~melodyNotes = [72,0,75,0,77,75,72,0, 70,0,72,0,75,0,77,0,
                        79,0,77,75,72,0,70,0, 72,0,75,0,77,0,79,0];
        ~reload.value;
    },
    // [2:30] hat secondaire entre...
    hat_secondaire_entre: {
        ~percInst = \openHat;
        ~hatSteps = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,1,0,0]; ~hatAmp = 0.10;
        ~percSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,1,0]; ~percAmp = 0.18;
        ~reload.value;
    },
    // [3:30] handpan duo avec flute...
    handpan_duo_avec_flute: {
        ~melodyInst = \handpan;
        ~melodyAttack = 0.001; ~melodyRelease = 1.2; ~melodyCutoff = 4500;
        ~melodyAmp = 0.22;
        ~melodyNotes = [72,0,79,0,75,72,67,0, 70,0,72,0,77,0,75,0,
                        79,0,82,79,77,72,67,0, 75,0,77,0,79,0,82,0];
        ~reload.value;
    },
    // [4:30] section dense full ensemble...
    section_dense_full_ensemble: {
        ~percInst = \tom; ~tomFreq = 90;
        ~percSteps = [1,0,1,0, 0,1,1,0, 1,0,0,1, 0,1,0,1]; ~percAmp = 0.38;
        ~hatSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.10;
        ~kickSteps = [1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,1,0];
        ~reload.value;
    },
    // [6:00] descente, juste flute + drone...
    descente_juste_flute_drone: {
        Synth(\gong, [\freq, 60, \decay, 6, \amp, 0.4]);
        ~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.4;
        ~percSteps = [1,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,0,0]; ~percAmp = 0.25;
        ~hatAmp = 0.06;
        ~melodyInst = \flute;
        ~melodyAttack = 0.1; ~melodyRelease = 0.6;
        ~melodyAmp = 0.18;
        ~reload.value;
    },
    // [7:00] outro fade...
    outro_fade: {
        Synth(\gong, [\freq, 45, \decay, 8, \amp, 0.5]);
    },
);
"=== sections K chargees : ".post; ~sections['K'].keys.asArray.postln;
)

// --- Lancer une section TRACK K ---
( ~jumpTo.('K', 'tribal_ethno_100_bpm'); )  // [0:00] === TRIBAL ETHNO 100 BPM ===
( ~jumpTo.('K', 'tom_handpan_intro'); )  // [0:00] tom + handpan intro...
( ~jumpTo.('K', 'kick_lent_tom_plus_dense'); )  // [0:45] kick lent + tom plus dense...
( ~jumpTo.('K', 'flute_chante_par_dessus'); )  // [1:30] flute chante par-dessus...
( ~jumpTo.('K', 'hat_secondaire_entre'); )  // [2:30] hat secondaire entre...
( ~jumpTo.('K', 'handpan_duo_avec_flute'); )  // [3:30] handpan duo avec flute...
( ~jumpTo.('K', 'section_dense_full_ensemble'); )  // [4:30] section dense full ensemble...
( ~jumpTo.('K', 'descente_juste_flute_drone'); )  // [6:00] descente, juste flute + drone...
( ~jumpTo.('K', 'outro_fade'); )  // [7:00] outro fade...


// =====================================================================
//  TRACK L -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['L'] = (
    // [0:00] === FUTURE GARAGE 130 BPM ===
    future_garage_130_bpm: {
        TempoClock.default.tempo = 130 / 60;
    },
    // [0:00] intro warmPad atmospherique...
    intro_warmpad_atmospherique: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.7; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [60,0,0,0,67,0,0,0, 70,0,0,0,72,0,0,0,
                        72,0,0,0,70,0,0,0, 67,0,0,0,63,0,0,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\dubBass);
    },
    // [0:25] beat 2-step + clap...
    beat_2_step_clap: {
        ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
        ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.5; ~kickClick = 0.1;
        ~hatSteps = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.10;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.32;
        ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,1,0,0]; ~snareAmp = 0.3;
        ~snareFreq = 220; ~snareNoiseAmt = 0.7;
        ~reload.value;
    },
    // [1:00] subBoom 808 entre...
    subboom_808_entre: {
        ~melodyInst = \subBoom;
        ~melodyAttack = 0.005; ~melodyRelease = 0.5; ~melodyAmp = 0.32;
        ~melodyNotes = [36,0,0,0, 36,0,0,0, 0,0,41,0, 39,0,0,0,
                        36,0,0,0, 38,0,0,0, 0,0,41,0, 39,0,0,0];
        ~reload.value;
    },
    // [2:00] section : warmPad lead par-dessus...
    section_warmpad_lead_par_dessus: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.3; ~melodyRelease = 1.2; ~melodyCutoff = 2200;
        ~melodyAmp = 0.18;
        ~melodyNotes = [60,0,0,67, 0,70,0,72, 70,0,67,0, 63,0,0,60,
                        65,0,0,72, 0,75,0,77, 75,0,72,0, 67,0,0,60];
        ~reload.value;
    },
    // [3:20] breakdown reverb-like...
    breakdown_reverb_like: {
        ~kickSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~kickAmp = 0.4;
        ~hatAmp = 0.05; ~clapAmp = 0;
        ~melodyInst = \choir;
        ~melodyAttack = 0.5; ~melodyRelease = 1.5; ~melodyCutoff = 2500;
        ~melodyAmp = 0.20;
        ~reload.value;
    },
    // [4:00] retour beat + sub massif...
    retour_beat_sub_massif: {
        Synth(\impact, [\freq, 35, \decay, 2.5, \amp, 0.55]);
        ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
        ~hatSteps = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.12;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.35;
        ~melodyInst = \subBoom;
        ~melodyAttack = 0.005; ~melodyRelease = 0.6; ~melodyAmp = 0.36;
        ~melodyNotes = [36,0,0,0, 36,0,0,0, 0,0,41,0, 39,0,0,0,
                        36,0,0,0, 38,0,0,0, 0,0,41,0, 36,0,0,0];
        ~reload.value;
    },
    // [5:40] outro pad fade...
    outro_pad_fade: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.7; ~melodyRelease = 2.0; ~melodyCutoff = 1200;
        ~melodyAmp = 0.18;
        ~reload.value;
    },
);
"=== sections L chargees : ".post; ~sections['L'].keys.asArray.postln;
)

// --- Lancer une section TRACK L ---
( ~jumpTo.('L', 'future_garage_130_bpm'); )  // [0:00] === FUTURE GARAGE 130 BPM ===
( ~jumpTo.('L', 'intro_warmpad_atmospherique'); )  // [0:00] intro warmPad atmospherique...
( ~jumpTo.('L', 'beat_2_step_clap'); )  // [0:25] beat 2-step + clap...
( ~jumpTo.('L', 'subboom_808_entre'); )  // [1:00] subBoom 808 entre...
( ~jumpTo.('L', 'section_warmpad_lead_par_dessus'); )  // [2:00] section : warmPad lead par-dessus...
( ~jumpTo.('L', 'breakdown_reverb_like'); )  // [3:20] breakdown reverb-like...
( ~jumpTo.('L', 'retour_beat_sub_massif'); )  // [4:00] retour beat + sub massif...
( ~jumpTo.('L', 'outro_pad_fade'); )  // [5:40] outro pad fade...


// =====================================================================
//  TRACK M -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['M'] = (
    // [0:00] === CHIPTUNE MADNESS 150 BPM ===
    chiptune_madness_150_bpm: {
        TempoClock.default.tempo = 150 / 60;
    },
    // [0:00] intro arp seul...
    intro_arp_seul: {
        ~melodyInst = \squareLead;
        ~melodyAttack = 0.003; ~melodyRelease = 0.15; ~melodyCutoff = 5500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [60,67,72,67, 60,65,72,65, 63,70,75,70, 63,67,72,67,
                        60,67,72,79, 75,72,67,60, 63,67,75,79, 75,72,67,63];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\arp);
    },
    // [0:20] kick chip + hat fast...
    kick_chip_hat_fast: {
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
        ~kickFreq = 70; ~kickPitchAmt = 4.0; ~kickDecay = 0.15; ~kickClick = 0.4;
        ~hatSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.12;
        ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.4;
        ~snareFreq = 280;
        ~reload.value;
    },
    // [1:00] arp variations...
    arp_variations: {
        ~melodyNotes = [60,67,72,75, 70,67,60,67, 63,70,75,77, 72,70,63,70,
                        65,72,77,79, 75,72,65,72, 60,67,72,79, 75,72,67,60];
        ~reload.value;
    },
    // [1:50] DROP square + sub punchy...
    drop_square_sub_punchy: {
        ~melodyInst = \squareLead;
        ~melodyCutoff = 6500; ~melodyAmp = 0.20;
        ~kickAmp = 0.5;
        Synth(\impact, [\freq, 50, \decay, 1.5, \amp, 0.4]);
        ~melodyNotes = [60, 0, 67, 60, 72, 67, 60, 67,
                        63, 0, 70, 63, 75, 70, 63, 70,
                        65, 0, 72, 65, 77, 72, 65, 72,
                        63, 0, 70, 63, 75, 70, 67, 60];
        ~reload.value;
    },
    // [3:00] breakdown handpan asiatique...
    breakdown_handpan_asiatique: {
        ~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
        ~hatAmp = 0.06;
        ~melodyInst = \handpan;
        ~melodyAttack = 0.001; ~melodyRelease = 1.0; ~melodyCutoff = 4500;
        ~melodyAmp = 0.20;
        ~melodyNotes = [60,0,67,0,72,0,67,0, 65,0,70,0,75,0,70,0,
                        63,0,70,0,75,0,79,0, 75,0,72,0,67,0,60,0];
        ~reload.value;
    },
    // [3:30] DROP FINAL chip arp + tom rolls...
    drop_final_chip_arp_tom_rolls: {
        Synth(\impact, [\freq, 45, \decay, 1.5, \amp, 0.4]);
        Synth(\crash, [\decay, 2, \amp, 0.3]);
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
        ~hatSteps = [1,1,1,0, 1,1,1,0, 1,1,1,0, 1,1,1,0]; ~hatAmp = 0.13;
        ~melodyInst = \squareLead;
        ~melodyAttack = 0.002; ~melodyRelease = 0.12; ~melodyCutoff = 7000;
        ~melodyAmp = 0.22;
        ~melodyNotes = [60,67,72,79, 75,72,67,72, 63,70,75,82, 79,75,70,75,
                        65,72,77,84, 79,77,72,77, 60,67,72,79, 75,72,67,60];
        ~percInst = \tom; ~tomFreq = 140;
        ~percSteps = [0,0,0,0, 0,0,0,0, 0,0,0,1, 0,1,0,1]; ~percAmp = 0.3;
        ~reload.value;
    },
    // [5:10] outro chip degrade...
    outro_chip_degrade: {
    },
);
"=== sections M chargees : ".post; ~sections['M'].keys.asArray.postln;
)

// --- Lancer une section TRACK M ---
( ~jumpTo.('M', 'chiptune_madness_150_bpm'); )  // [0:00] === CHIPTUNE MADNESS 150 BPM ===
( ~jumpTo.('M', 'intro_arp_seul'); )  // [0:00] intro arp seul...
( ~jumpTo.('M', 'kick_chip_hat_fast'); )  // [0:20] kick chip + hat fast...
( ~jumpTo.('M', 'arp_variations'); )  // [1:00] arp variations...
( ~jumpTo.('M', 'drop_square_sub_punchy'); )  // [1:50] DROP square + sub punchy...
( ~jumpTo.('M', 'breakdown_handpan_asiatique'); )  // [3:00] breakdown handpan asiatique...
( ~jumpTo.('M', 'drop_final_chip_arp_tom_rolls'); )  // [3:30] DROP FINAL chip arp + tom rolls...
( ~jumpTo.('M', 'outro_chip_degrade'); )  // [5:10] outro chip degrade...


// =====================================================================
//  TRACK N -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['N'] = (
    // [0:00] === PHONK 130 BPM ===
    phonk_130_bpm: {
        TempoClock.default.tempo = 130 / 60;
    },
    // [0:00] cowbell + dark pad...
    cowbell_dark_pad: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.5; ~melodyRelease = 1.5; ~melodyCutoff = 1200;
        ~melodyAmp = 0.16;
        ~melodyNotes = [48,0,0,0,0,0,0,0, 51,0,0,0,53,0,0,0,
                        48,0,0,0,0,0,0,0, 51,0,0,0,55,0,0,0];
        ~percInst = \cowbell; ~cowbellFreq = 800;
        ~percSteps = [0,0,1,0, 0,1,0,0, 1,0,0,1, 0,0,1,0]; ~percAmp = 0.3;
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\bassline);
    },
    // [0:20] kick + hi-hats triplets...
    kick_hi_hats_triplets: {
        ~kickSteps = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0]; ~kickAmp = 0.55;
        ~kickFreq = 45; ~kickPitchAmt = 2.5; ~kickDecay = 0.5; ~kickClick = 0.1;
        ~hatSteps = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.10;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
        ~reload.value;
    },
    // [0:50] sub 808 entre...
    sub_808_entre: {
        ~melodyInst = \subBoom;
        ~melodyAttack = 0.005; ~melodyRelease = 0.5; ~melodyAmp = 0.36;
        ~melodyNotes = [36,0,0,0, 0,0,0,36, 39,0,0,0, 0,41,0,0,
                        36,0,0,0, 0,0,0,38, 41,0,0,0, 0,39,0,0];
        ~reload.value;
    },
    // [1:50] section dark fmBass...
    section_dark_fmbass: {
        ~melodyInst = \fmBass;
        ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 1500;
        ~melodyAmp = 0.32;
        ~melodyNotes = [36,0,39,0, 36,0,0,41, 39,0,36,0, 41,0,43,0,
                        36,0,39,0, 41,0,43,0, 39,0,36,0, 41,39,36,0];
        ~reload.value;
    },
    // [2:50] breakdown atmosphere + cowbell solo...
    breakdown_atmosphere_cowbell_solo: {
        ~kickSteps=(0!16); ~hatAmp=0.05; ~clapSteps=(0!16);
        ~percAmp = 0.4;
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.5; ~melodyRelease = 1.8; ~melodyCutoff = 1500;
        ~melodyAmp = 0.18;
        ~reload.value;
    },
    // [3:15] DROP retour + sub massif...
    drop_retour_sub_massif: {
        Synth(\impact, [\freq, 30, \decay, 2.5, \amp, 0.6]);
        ~kickSteps = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0];
        ~hatSteps = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.11;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
        ~melodyInst = \subBoom;
        ~melodyAmp = 0.40;
        ~melodyNotes = [36,0,0,0, 39,0,0,0, 36,0,0,41, 39,0,0,0,
                        36,0,38,0, 39,0,0,41, 43,0,41,0, 39,0,36,0];
        ~reload.value;
    },
    // [4:30] outro fade...
    outro_fade: {
    },
);
"=== sections N chargees : ".post; ~sections['N'].keys.asArray.postln;
)

// --- Lancer une section TRACK N ---
( ~jumpTo.('N', 'phonk_130_bpm'); )  // [0:00] === PHONK 130 BPM ===
( ~jumpTo.('N', 'cowbell_dark_pad'); )  // [0:00] cowbell + dark pad...
( ~jumpTo.('N', 'kick_hi_hats_triplets'); )  // [0:20] kick + hi-hats triplets...
( ~jumpTo.('N', 'sub_808_entre'); )  // [0:50] sub 808 entre...
( ~jumpTo.('N', 'section_dark_fmbass'); )  // [1:50] section dark fmBass...
( ~jumpTo.('N', 'breakdown_atmosphere_cowbell_solo'); )  // [2:50] breakdown atmosphere + cowbell solo...
( ~jumpTo.('N', 'drop_retour_sub_massif'); )  // [3:15] DROP retour + sub massif...
( ~jumpTo.('N', 'outro_fade'); )  // [4:30] outro fade...


// =====================================================================
//  TRACK O -- 9 sections (auto-extraites des postln)
// =====================================================================
(
~sections['O'] = (
    // [0:00] === ASIAN CINEMATIC 92 BPM ===
    asian_cinematic_92_bpm: {
        TempoClock.default.tempo = 92 / 60;
    },
    // [0:00] gong puis koto solo...
    gong_puis_koto_solo: {
        Synth(\gong, [\freq, 60, \decay, 8, \amp, 0.6]);
        ~melodyInst = \koto;
        ~melodyAttack = 0.001; ~melodyRelease = 0.6; ~melodyCutoff = 6000;
        ~melodyAmp = 0.24;
        ~melodyNotes = [60,0,67,0,72,0,67,65, 63,0,60,0,0,67,70,72,
                        65,0,72,0,67,0,72,75, 70,0,67,0,65,0,60,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\counter);
    },
    // [1:00] erhu chante par-dessus...
    erhu_chante_par_dessus: {
        ~melodyInst = \erhu;
        ~melodyAttack = 0.05; ~melodyRelease = 0.5; ~melodyCutoff = 2500;
        ~melodyAmp = 0.22;
        ~melodyNotes = [60,0,0,65,67,0,69,0, 72,0,69,67,65,0,60,0,
                        65,0,0,69,72,0,74,0, 77,0,74,72,69,0,65,0];
        ~reload.value;
    },
    // [2:30] tom doux entre (rythme tres lent)...
    tom_doux_entre_rythme_tres_lent: {
        ~percInst = \tom; ~tomFreq = 80;
        ~percSteps = [1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.3;
        ~reload.value;
    },
    // [3:30] pipa solo expressif...
    pipa_solo_expressif: {
        Synth(\gong, [\freq, 70, \decay, 7, \amp, 0.4]);
        ~melodyInst = \pipa;
        ~melodyAttack = 0.001; ~melodyRelease = 0.6; ~melodyCutoff = 4500;
        ~melodyAmp = 0.24;
        ~melodyNotes = [72,0,75,77,79,0,77,75, 72,0,69,0,67,0,65,0,
                        77,0,79,82,84,0,82,79, 77,0,72,0,69,0,67,0];
        ~reload.value;
    },
    // [5:00] section ample : strings + flute layered...
    section_ample_strings_flute_layered: {
        ~melodyInst = \strings;
        ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 3500;
        ~melodyAmp = 0.20;
        ~melodyNotes = [60,0,0,0,67,0,0,0, 70,0,0,0,72,0,0,0,
                        72,0,0,0,70,0,0,0, 65,0,0,0,60,0,0,0];
        ~percSteps = [1,0,0,1, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~percAmp = 0.32;
        ~reload.value;
    },
    // [6:30] flute melodique aerienne...
    flute_melodique_aerienne: {
        ~melodyInst = \flute;
        ~melodyAttack = 0.1; ~melodyRelease = 0.6; ~melodyCutoff = 4000;
        ~melodyAmp = 0.22;
        ~melodyNotes = [72,0,77,0,79,77,72,0, 70,0,72,77,75,72,67,0,
                        77,0,82,0,84,82,79,0, 77,0,79,82,77,72,69,0];
        ~reload.value;
    },
    // [8:00] retour koto + erhu duo descente...
    retour_koto_erhu_duo_descente: {
        Synth(\gong, [\freq, 50, \decay, 10, \amp, 0.55]);
        ~percSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~percAmp = 0.2;
        ~melodyInst = \erhu;
        ~melodyAttack = 0.06; ~melodyRelease = 0.6; ~melodyCutoff = 2000;
        ~melodyAmp = 0.20;
        ~melodyNotes = [72,0,0,0,69,0,0,0, 67,0,0,0,65,0,0,0,
                        63,0,0,0,60,0,0,0, 65,0,0,0,60,0,0,0];
        ~reload.value;
    },
    // [9:00] outro long, gong final...
    outro_long_gong_final: {
        Synth(\gong, [\freq, 40, \decay, 15, \amp, 0.7]);
    },
);
"=== sections O chargees : ".post; ~sections['O'].keys.asArray.postln;
)

// --- Lancer une section TRACK O ---
( ~jumpTo.('O', 'asian_cinematic_92_bpm'); )  // [0:00] === ASIAN CINEMATIC 92 BPM ===
( ~jumpTo.('O', 'gong_puis_koto_solo'); )  // [0:00] gong puis koto solo...
( ~jumpTo.('O', 'erhu_chante_par_dessus'); )  // [1:00] erhu chante par-dessus...
( ~jumpTo.('O', 'tom_doux_entre_rythme_tres_lent'); )  // [2:30] tom doux entre (rythme tres lent)...
( ~jumpTo.('O', 'pipa_solo_expressif'); )  // [3:30] pipa solo expressif...
( ~jumpTo.('O', 'section_ample_strings_flute_layered'); )  // [5:00] section ample : strings + flute layered...
( ~jumpTo.('O', 'flute_melodique_aerienne'); )  // [6:30] flute melodique aerienne...
( ~jumpTo.('O', 'retour_koto_erhu_duo_descente'); )  // [8:00] retour koto + erhu duo descente...
( ~jumpTo.('O', 'outro_long_gong_final'); )  // [9:00] outro long, gong final...


// =====================================================================
//  TRACK P -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['P'] = (
    // [0:00] === INDUSTRIAL 130 BPM ===
    industrial_130_bpm: {
        TempoClock.default.tempo = 130 / 60;
    },
    // [0:00] drone tendu + metal hits...
    drone_tendu_metal_hits: {
        ~melodyInst = \drone;
        ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 1500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [36,0,0,0,0,0,0,0, 36,0,0,0,39,0,0,0,
                        36,0,0,0,0,0,0,0, 41,0,0,0,39,0,0,0];
        ~percInst = \rim;
        ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.35;
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\bassline);
    },
    // [0:25] kick distordu T4 + clap heavy...
    kick_distordu_t4_clap_heavy: {
        ~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.55;
        ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28;
        ~kickDrive = 3.5; ~kickClick = 0.3;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.4;
        ~hatSteps = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.10;
        ~reload.value;
    },
    // [1:00] reeseHard menacant entre...
    reesehard_menacant_entre: {
        ~melodyInst = \reeseHard;
        ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 700;
        ~melodyDrive = 4.0; ~melodyAmp = 0.25;
        ~melodyNotes = [36,0,0,0, 39,0,0,0, 36,0,0,0, 41,0,0,0,
                        36,0,0,0, 38,0,0,0, 41,0,0,0, 39,0,0,0];
        ~reload.value;
    },
    // [2:00] section growl + drum hard...
    section_growl_drum_hard: {
        Synth(\impact, [\freq, 35, \decay, 2, \amp, 0.55]);
        ~kickSteps  = [1,0,1,0, 0,0,0,0, 1,0,0,1, 0,0,0,0]; ~kickAmp = 0.55;
        ~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.5;
        ~snareFreq = 240; ~snareNoiseAmt = 0.75;
        ~melodyInst = \growl;
        ~melodyAttack = 0.005; ~melodyRelease = 0.3;
        ~melodyCutoff = 350; ~melodyDrive = 3.5;
        ~melodyWobbleRate = 4; ~melodyWobbleDepth = 2200; ~melodyWobbleShape = 0;
        ~melodySubAmt = 0.7; ~melodyAmp = 0.20;
        ~reload.value;
    },
    // [3:30] tension : drum cuts, drone seul...
    tension_drum_cuts_drone_seul: {
        ~kickSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~kickAmp = 0.5;
        ~snareSteps = (0!16); ~clapSteps = (0!16); ~hatAmp = 0.05;
        ~melodyInst = \drone;
        ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 1200;
        ~melodyAmp = 0.20;
        ~percSteps = [1,0,0,0, 0,0,1,0, 0,0,0,0, 0,1,0,0]; ~percAmp = 0.35;
        ~reload.value;
        Synth(\gong, [\freq, 80, \decay, 6, \amp, 0.5]);
    },
    // [4:15] DROP final hard growl + kick double...
    drop_final_hard_growl_kick_double: {
        Synth(\impact, [\freq, 30, \decay, 3, \amp, 0.65]);
        ~kickSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~kickAmp = 0.5;
        ~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.5;
        ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.4;
        ~melodyInst = \growl;
        ~melodyCutoff = 280; ~melodyDrive = 3.8;
        ~melodyWobbleRate = 8; ~melodyWobbleShape = 1; ~melodyAmp = 0.22;
        ~reload.value;
    },
    // [6:45] outro mecanique...
    outro_mecanique: {
        Synth(\sweep, [\dur, 8, \startCutoff, 6000, \endCutoff, 200, \amp, 0.3]);
    },
);
"=== sections P chargees : ".post; ~sections['P'].keys.asArray.postln;
)

// --- Lancer une section TRACK P ---
( ~jumpTo.('P', 'industrial_130_bpm'); )  // [0:00] === INDUSTRIAL 130 BPM ===
( ~jumpTo.('P', 'drone_tendu_metal_hits'); )  // [0:00] drone tendu + metal hits...
( ~jumpTo.('P', 'kick_distordu_t4_clap_heavy'); )  // [0:25] kick distordu T4 + clap heavy...
( ~jumpTo.('P', 'reesehard_menacant_entre'); )  // [1:00] reeseHard menacant entre...
( ~jumpTo.('P', 'section_growl_drum_hard'); )  // [2:00] section growl + drum hard...
( ~jumpTo.('P', 'tension_drum_cuts_drone_seul'); )  // [3:30] tension : drum cuts, drone seul...
( ~jumpTo.('P', 'drop_final_hard_growl_kick_double'); )  // [4:15] DROP final hard growl + kick double...
( ~jumpTo.('P', 'outro_mecanique'); )  // [6:45] outro mecanique...


// =====================================================================
//  TRACK Q -- 9 sections (auto-extraites des postln)
// =====================================================================
(
~sections['Q'] = (
    // [0:00] === NEUROFUNK DNB 174 BPM ===
    neurofunk_dnb_174_bpm: {
        TempoClock.default.tempo = 174 / 60;
    },
    // [0:00] intro pad sombre...
    intro_pad_sombre: {
        ~melodyInst = \drone;
        ~melodyAttack = 0.8; ~melodyRelease = 2.5; ~melodyCutoff = 1500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [36,0,0,0,0,0,0,0, 39,0,0,0,0,0,0,0,
                        36,0,0,0,0,0,0,0, 41,0,0,0,0,0,0,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\bassline);
    },
    // [0:20] amen syncope entre...
    amen_syncope_entre: {
        ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.55;
        ~kickFreq = 55; ~kickPitchAmt = 4.0; ~kickDecay = 0.18;
        ~kickDrive = 1.8; ~kickClick = 0.35;
        ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,1,0]; ~snareAmp = 0.55;
        ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
        ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.13;
        ~reload.value;
    },
    // [0:45] BUILD vers DROP reese...
    build_vers_drop_reese: {
        Synth(\riser, [\dur, 8, \startCutoff, 400, \endCutoff, 11000, \amp, 0.35]);
        Synth(\impact, [\freq, 40, \decay, 2, \amp, 0.6]);
    },
    // [0:53] === DROP reeseHard menacant ===
    drop_reesehard_menacant: {
        ~melodyInst = \reeseHard;
        ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 600;
        ~melodyDrive = 4.0; ~melodyAmp = 0.28;
        ~melodyNotes = [36,0,0,0, 39,0,41,0, 36,0,0,0, 41,0,0,43,
                        36,0,38,0, 39,0,41,0, 41,0,43,0, 39,0,36,0];
        ~reload.value;
    },
    // [2:33] section : variations bass + acid stabs...
    section_variations_bass_acid_stabs: {
        ~acidNotes = [36,0,48,0,36,0,43,0, 36,0,41,0,39,0,36,0];
        ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,0];
        ~acidSlides = [0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
        ~acidCutoff = 1500; ~acidRq = 0.10; ~acidDrive = 3.0; ~acidAmp = 0.25;
        ~reload.value;
    },
    // [3:53] breakdown atmospheric...
    breakdown_atmospheric: {
        ~kickSteps = (0!16); ~snareSteps = (0!16);
        ~hatAmp = 0.06; ~acidAmp = 0;
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.5; ~melodyRelease = 1.8; ~melodyCutoff = 2200;
        ~melodyAmp = 0.20;
        ~melodyNotes = [60,0,0,0,63,0,0,0, 67,0,0,0,70,0,0,0,
                        72,0,0,0,70,0,0,0, 65,0,0,0,60,0,0,0];
        ~reload.value;
    },
    // [4:28] DROP 2 hard reese + amen full...
    drop_2_hard_reese_amen_full: {
        Synth(\impact, [\freq, 32, \decay, 3, \amp, 0.7]);
        Synth(\crash, [\decay, 3, \amp, 0.4]);
        ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.55;
        ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,1,1]; ~snareAmp = 0.55;
        ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.14;
        ~melodyInst = \reeseHard;
        ~melodyCutoff = 700; ~melodyDrive = 4.5; ~melodyAmp = 0.30;
        ~acidAmp = 0.28; ~acidCutoff = 1800; ~acidDrive = 3.5;
        ~reload.value;
    },
    // [6:08] outro fade...
    outro_fade: {
        Synth(\sweep, [\dur, 6, \startCutoff, 8000, \endCutoff, 200, \amp, 0.3]);
    },
);
"=== sections Q chargees : ".post; ~sections['Q'].keys.asArray.postln;
)

// --- Lancer une section TRACK Q ---
( ~jumpTo.('Q', 'neurofunk_dnb_174_bpm'); )  // [0:00] === NEUROFUNK DNB 174 BPM ===
( ~jumpTo.('Q', 'intro_pad_sombre'); )  // [0:00] intro pad sombre...
( ~jumpTo.('Q', 'amen_syncope_entre'); )  // [0:20] amen syncope entre...
( ~jumpTo.('Q', 'build_vers_drop_reese'); )  // [0:45] BUILD vers DROP reese...
( ~jumpTo.('Q', 'drop_reesehard_menacant'); )  // [0:53] === DROP reeseHard menacant ===
( ~jumpTo.('Q', 'section_variations_bass_acid_stabs'); )  // [2:33] section : variations bass + acid stabs...
( ~jumpTo.('Q', 'breakdown_atmospheric'); )  // [3:53] breakdown atmospheric...
( ~jumpTo.('Q', 'drop_2_hard_reese_amen_full'); )  // [4:28] DROP 2 hard reese + amen full...
( ~jumpTo.('Q', 'outro_fade'); )  // [6:08] outro fade...


// =====================================================================
//  TRACK R -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['R'] = (
    // [0:00] === SYNTHWAVE 100 BPM ===
    synthwave_100_bpm: {
        TempoClock.default.tempo = 100 / 60;
    },
    // [0:00] intro warmPad atmospherique...
    intro_warmpad_atmospherique: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.6; ~melodyRelease = 2.5; ~melodyCutoff = 1800;
        ~melodyAmp = 0.18;
        ~melodyNotes = [60,0,0,0,63,0,0,0, 67,0,0,0,70,0,0,0,
                        72,0,0,0,70,0,0,0, 67,0,0,0,63,0,0,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\fifth);
    },
    // [0:25] beat 80s : kick + snare 1-2-3-4...
    beat_80s_kick_snare_1_2_3_4: {
        ~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
        ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.18;
        ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.4;
        ~snareFreq = 220; ~snareNoiseAmt = 0.5;
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
        ~reload.value;
    },
    // [1:00] saw3 lead retro entre...
    saw3_lead_retro_entre: {
        ~melodyInst = \saw3;
        ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 3000;
        ~melodyDrive = 1.6; ~melodyAmp = 0.16;
        ~melodyNotes = [60,0,67,0,70,0,72,0, 70,67,0,63,0,67,70,0,
                        72,0,75,0,77,0,75,72, 70,67,0,63,0,60,0,0];
        ~reload.value;
    },
    // [2:20] verse fmLead solo...
    verse_fmlead_solo: {
        ~melodyInst = \fmLead;
        ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [72,0,75,0,77,75,72,0, 70,0,72,75,72,70,67,0,
                        77,0,79,0,82,79,77,75, 72,0,70,67,65,0,60,0];
        ~reload.value;
    },
    // [3:40] breakdown choir + saw lead duo...
    breakdown_choir_saw_lead_duo: {
        ~kickSteps = (0!16); ~snareSteps = (0!16); ~hatAmp = 0.06;
        ~melodyInst = \choir;
        ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2500;
        ~melodyAmp = 0.20;
        ~reload.value;
    },
    // [4:15] DROP 2 chord stabs + lead duo...
    drop_2_chord_stabs_lead_duo: {
        Synth(\impact, [\freq, 45, \decay, 2, \amp, 0.45]);
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
        ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.3;
        ~melodyInst = \saw3;
        ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 3500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [60,0,67,72, 70,0,67,63, 65,0,72,75, 72,0,70,65,
                        60,0,67,72, 70,0,67,63, 65,0,72,77, 75,0,70,65];
        ~reload.value;
    },
    // [6:15] outro pad fade...
    outro_pad_fade: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.6; ~melodyRelease = 2.5;
        ~melodyAmp = 0.18;
        ~reload.value;
    },
);
"=== sections R chargees : ".post; ~sections['R'].keys.asArray.postln;
)

// --- Lancer une section TRACK R ---
( ~jumpTo.('R', 'synthwave_100_bpm'); )  // [0:00] === SYNTHWAVE 100 BPM ===
( ~jumpTo.('R', 'intro_warmpad_atmospherique'); )  // [0:00] intro warmPad atmospherique...
( ~jumpTo.('R', 'beat_80s_kick_snare_1_2_3_4'); )  // [0:25] beat 80s : kick + snare 1-2-3-4...
( ~jumpTo.('R', 'saw3_lead_retro_entre'); )  // [1:00] saw3 lead retro entre...
( ~jumpTo.('R', 'verse_fmlead_solo'); )  // [2:20] verse fmLead solo...
( ~jumpTo.('R', 'breakdown_choir_saw_lead_duo'); )  // [3:40] breakdown choir + saw lead duo...
( ~jumpTo.('R', 'drop_2_chord_stabs_lead_duo'); )  // [4:15] DROP 2 chord stabs + lead duo...
( ~jumpTo.('R', 'outro_pad_fade'); )  // [6:15] outro pad fade...


// =====================================================================
//  TRACK S -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['S'] = (
    // [0:00] === DRONE DOOM 60 BPM ===
    drone_doom_60_bpm: {
        TempoClock.default.tempo = 60 / 60;
    },
    // [0:00] gong + drone profond...
    gong_drone_profond: {
        Synth(\gong, [\freq, 35, \decay, 20, \amp, 0.7]);
        ~melodyInst = \drone;
        ~melodyAttack = 3.0; ~melodyRelease = 4.0; ~melodyCutoff = 1000;
        ~melodyAmp = 0.22;
        ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                        36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\fifth);
    },
    // [2:00] couches drone evolutives...
    couches_drone_evolutives: {
        ~melodyNotes = [36,0,0,0,39,0,0,0, 0,0,0,0,0,0,0,0,
                        36,0,0,0,41,0,0,0, 0,0,0,0,0,0,0,0];
        ~melodyCutoff = 1500;
        ~reload.value;
    },
    // [4:00] handpan emerge tres lent...
    handpan_emerge_tres_lent: {
        Synth(\gong, [\freq, 50, \decay, 15, \amp, 0.5]);
        ~melodyInst = \handpan;
        ~melodyAttack = 0.001; ~melodyRelease = 3.0; ~melodyCutoff = 4000;
        ~melodyAmp = 0.22;
        ~melodyNotes = [48,0,0,0,55,0,0,0, 0,0,0,0,0,0,0,0,
                        48,0,0,0,60,0,0,0, 0,0,0,0,0,0,0,0];
        ~reload.value;
    },
    // [6:30] flute solitaire...
    flute_solitaire: {
        ~melodyInst = \flute;
        ~melodyAttack = 0.2; ~melodyRelease = 1.0; ~melodyCutoff = 3500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [60,0,0,0,65,0,0,0, 0,67,0,0,0,0,0,0,
                        65,0,0,60,0,0,0,0, 67,0,0,0,72,0,0,0];
        ~reload.value;
    },
    // [8:30] retour drone + pulsation tres lente...
    retour_drone_pulsation_tres_lente: {
        Synth(\gong, [\freq, 30, \decay, 25, \amp, 0.8]);
        ~percInst = \tom; ~tomFreq = 60;
        ~percSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~percAmp = 0.35;
        ~melodyInst = \drone;
        ~melodyAttack = 2.5; ~melodyRelease = 4.0; ~melodyCutoff = 800;
        ~melodyAmp = 0.20;
        ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                        36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
        ~reload.value;
    },
    // [11:00] choir mystique...
    choir_mystique: {
        ~melodyInst = \choir;
        ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 2200;
        ~melodyAmp = 0.18;
        ~melodyNotes = [48,0,0,0,55,0,0,0, 60,0,0,0,55,0,0,0,
                        48,0,0,0,55,0,0,0, 63,0,0,0,55,0,0,0];
        ~reload.value;
    },
    // [13:00] outro tres lent fade...
    outro_tres_lent_fade: {
        Synth(\gong, [\freq, 25, \decay, 30, \amp, 0.9]);
        ~percSteps = (0!16);
    },
);
"=== sections S chargees : ".post; ~sections['S'].keys.asArray.postln;
)

// --- Lancer une section TRACK S ---
( ~jumpTo.('S', 'drone_doom_60_bpm'); )  // [0:00] === DRONE DOOM 60 BPM ===
( ~jumpTo.('S', 'gong_drone_profond'); )  // [0:00] gong + drone profond...
( ~jumpTo.('S', 'couches_drone_evolutives'); )  // [2:00] couches drone evolutives...
( ~jumpTo.('S', 'handpan_emerge_tres_lent'); )  // [4:00] handpan emerge tres lent...
( ~jumpTo.('S', 'flute_solitaire'); )  // [6:30] flute solitaire...
( ~jumpTo.('S', 'retour_drone_pulsation_tres_lente'); )  // [8:30] retour drone + pulsation tres lente...
( ~jumpTo.('S', 'choir_mystique'); )  // [11:00] choir mystique...
( ~jumpTo.('S', 'outro_tres_lent_fade'); )  // [13:00] outro tres lent fade...


// =====================================================================
//  TRACK T -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['T'] = (
    // [0:00] === HARDCORE GABBER 180 BPM ===
    hardcore_gabber_180_bpm: {
        TempoClock.default.tempo = 180 / 60;
    },
    // [0:00] intro pad menacant...
    intro_pad_menacant: {
        ~melodyInst = \drone;
        ~melodyAttack = 0.6; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [36,0,0,0,0,0,0,0, 39,0,0,0,0,0,0,0,
                        36,0,0,0,0,0,0,0, 41,0,0,0,0,0,0,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16);
        ~acidNotes = [36,39,48,36,41,39,43,36, 39,41,36,48,39,36,41,39];
        ~acidAccents = [1,0,1,0,0,1,0,1, 0,0,1,0,1,0,0,1];
        ~acidSlides = [1,0,0,1,0,0,1,0, 0,1,0,1,0,1,0,0];
        ~acidCutoff = 1200; ~acidRq = 0.10; ~acidDrive = 3.5; ~acidAmp = 0;
        ~reload.value;
        ~enableHarmony.(\dubBass);
    },
    // [0:15] kick double gabber + acid...
    kick_double_gabber_acid: {
        ~kickSteps  = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~kickAmp = 0.55;
        ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.18;
        ~kickDrive = 3.5; ~kickClick = 0.35;
        ~hatSteps = [0,1,1,1, 0,1,1,0, 0,1,1,1, 0,1,1,0]; ~hatAmp = 0.13;
        ~acidAmp = 0.30; ~acidCutoff = 1500;
        ~reload.value;
    },
    // [1:00] BUILD vers DROP hardcore...
    build_vers_drop_hardcore: {
        Synth(\riser, [\dur, 8, \startCutoff, 500, \endCutoff, 13000, \amp, 0.4]);
        Synth(\impact, [\freq, 35, \decay, 2, \amp, 0.6]);
        Synth(\crash, [\decay, 2, \amp, 0.4]);
    },
    // [1:08] === DROP gabber + acid push ===
    drop_gabber_acid_push: {
        ~acidCutoff = 2500; ~acidRq = 0.06; ~acidDrive = 4.0; ~acidAmp = 0.32;
        ~melodyInst = \growl;
        ~melodyAttack = 0.005; ~melodyRelease = 0.2;
        ~melodyCutoff = 300; ~melodyDrive = 3.5;
        ~melodyWobbleRate = 8; ~melodyWobbleDepth = 2800;
        ~melodyWobbleShape = 1; ~melodySubAmt = 0.7;
        ~melodyAmp = 0.18;
        ~melodyNotes = [36,0,0,0, 36,0,39,0, 36,0,0,0, 41,0,0,0,
                        36,0,38,0, 36,0,39,0, 41,0,43,0, 39,0,36,0];
        ~clapSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~clapAmp = 0.4;
        ~reload.value;
    },
    // [2:38] breakdown atmospheric...
    breakdown_atmospheric: {
        ~kickSteps = (0!16); ~clapSteps = (0!16); ~acidAmp = 0;
        ~hatAmp = 0.06;
        ~melodyInst = \drone;
        ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 1200;
        ~melodyAmp = 0.20;
        ~reload.value;
        Synth(\gong, [\freq, 65, \decay, 5, \amp, 0.5]);
    },
    // [3:03] DROP FINAL chaos kick double...
    drop_final_chaos_kick_double: {
        Synth(\impact, [\freq, 30, \decay, 3, \amp, 0.7]);
        Synth(\crash, [\decay, 3, \amp, 0.5]);
        ~kickSteps  = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
        ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.14;
        ~clapSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,1];
        ~acidAmp = 0.35; ~acidCutoff = 2800; ~acidRq = 0.05; ~acidDrive = 4.5;
        ~melodyInst = \growl;
        ~melodyCutoff = 250; ~melodyDrive = 4.0;
        ~melodyWobbleShape = 1; ~melodySubAmt = 0.8; ~melodyAmp = 0.20;
        ~reload.value;
    },
    // [4:43] outro accelerando descend...
    outro_accelerando_descend: {
        Synth(\sweep, [\dur, 10, \startCutoff, 12000, \endCutoff, 200, \amp, 0.4]);
    },
);
"=== sections T chargees : ".post; ~sections['T'].keys.asArray.postln;
)

// --- Lancer une section TRACK T ---
( ~jumpTo.('T', 'hardcore_gabber_180_bpm'); )  // [0:00] === HARDCORE GABBER 180 BPM ===
( ~jumpTo.('T', 'intro_pad_menacant'); )  // [0:00] intro pad menacant...
( ~jumpTo.('T', 'kick_double_gabber_acid'); )  // [0:15] kick double gabber + acid...
( ~jumpTo.('T', 'build_vers_drop_hardcore'); )  // [1:00] BUILD vers DROP hardcore...
( ~jumpTo.('T', 'drop_gabber_acid_push'); )  // [1:08] === DROP gabber + acid push ===
( ~jumpTo.('T', 'breakdown_atmospheric'); )  // [2:38] breakdown atmospheric...
( ~jumpTo.('T', 'drop_final_chaos_kick_double'); )  // [3:03] DROP FINAL chaos kick double...
( ~jumpTo.('T', 'outro_accelerando_descend'); )  // [4:43] outro accelerando descend...


// =====================================================================
//  TRACK U -- 9 sections (auto-extraites des postln)
// =====================================================================
(
~sections['U'] = (
    // [0:00] === VOCAL TRANCE 140 BPM ===
    vocal_trance_140_bpm: {
        TempoClock.default.tempo = 140 / 60;
    },
    // [0:00] choir intro etheree...
    choir_intro_etheree: {
        ~melodyInst = \choir;
        ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 2500;
        ~melodyAmp = 0.20;
        ~melodyNotes = [60,0,0,0,67,0,0,0, 70,0,0,0,72,0,0,0,
                        72,0,0,0,70,0,0,0, 67,0,0,0,63,0,0,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\third);
    },
    // [0:40] kick + clap trance...
    kick_clap_trance: {
        ~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
        ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.18;
        ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
        ~reload.value;
    },
    // [1:30] arp warmPad par-dessus choir...
    arp_warmpad_par_dessus_choir: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2500;
        ~melodyAmp = 0.18;
        ~melodyNotes = [60,67,70,67, 63,67,70,72, 65,67,72,75, 70,72,75,77,
                        63,67,70,75, 65,70,72,77, 67,72,75,79, 70,75,77,72];
        ~reload.value;
    },
    // [2:50] BUILD vers DROP epic...
    build_vers_drop_epic: {
        Synth(\riser, [\dur, 12, \startCutoff, 400, \endCutoff, 11000, \amp, 0.35]);
        Synth(\impact, [\freq, 40, \decay, 2.5, \amp, 0.6]);
    },
    // [3:02] === DROP fmLead epic ===
    drop_fmlead_epic: {
        ~melodyInst = \fmLead;
        ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 6000;
        ~melodyAmp = 0.20;
        ~melodyNotes = [60,67,72,75, 70,67,63,67, 65,72,77,79, 75,72,67,72,
                        63,70,75,82, 79,75,72,75, 65,72,77,84, 79,75,70,72];
        ~reload.value;
    },
    // [5:02] breakdown choir solo (vocal moment)...
    breakdown_choir_solo_vocal_moment: {
        ~kickSteps = (0!16); ~clapSteps = (0!16); ~hatAmp = 0.06;
        ~melodyInst = \choir;
        ~melodyAttack = 0.4; ~melodyRelease = 2.0; ~melodyCutoff = 2200;
        ~melodyAmp = 0.24;
        ~melodyNotes = [60,0,67,0,72,0,70,0, 67,0,63,0,60,0,0,0,
                        63,0,70,0,75,0,72,0, 70,0,65,0,63,0,0,0];
        ~reload.value;
        Synth(\gong, [\freq, 60, \decay, 8, \amp, 0.4]);
    },
    // [5:52] BUILD 2 + DROP FINAL...
    build_2_drop_final: {
        Synth(\riser, [\dur, 16, \startCutoff, 500, \endCutoff, 12500, \amp, 0.4]);
        ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
        Synth(\impact, [\freq, 35, \decay, 3, \amp, 0.7]);
        Synth(\crash, [\decay, 4, \amp, 0.45]);
    },
    // [8:38] outro pad fade...
    outro_pad_fade: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.6; ~melodyRelease = 2.5;
        ~reload.value;
    },
);
"=== sections U chargees : ".post; ~sections['U'].keys.asArray.postln;
)

// --- Lancer une section TRACK U ---
( ~jumpTo.('U', 'vocal_trance_140_bpm'); )  // [0:00] === VOCAL TRANCE 140 BPM ===
( ~jumpTo.('U', 'choir_intro_etheree'); )  // [0:00] choir intro etheree...
( ~jumpTo.('U', 'kick_clap_trance'); )  // [0:40] kick + clap trance...
( ~jumpTo.('U', 'arp_warmpad_par_dessus_choir'); )  // [1:30] arp warmPad par-dessus choir...
( ~jumpTo.('U', 'build_vers_drop_epic'); )  // [2:50] BUILD vers DROP epic...
( ~jumpTo.('U', 'drop_fmlead_epic'); )  // [3:02] === DROP fmLead epic ===
( ~jumpTo.('U', 'breakdown_choir_solo_vocal_moment'); )  // [5:02] breakdown choir solo (vocal moment)...
( ~jumpTo.('U', 'build_2_drop_final'); )  // [5:52] BUILD 2 + DROP FINAL...
( ~jumpTo.('U', 'outro_pad_fade'); )  // [8:38] outro pad fade...


// =====================================================================
//  TRACK V -- 8 sections (auto-extraites des postln)
// =====================================================================
(
~sections['V'] = (
    // [0:00] === GLITCH IDM 130 BPM ===
    glitch_idm_130_bpm: {
        TempoClock.default.tempo = 130 / 60;
    },
    // [0:00] intro pluck random + drone...
    intro_pluck_random_drone: {
        ~melodyInst = \pluck;
        ~melodyAttack = 0.001; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
        ~melodyAmp = 0.20;
        ~melodyNotes = ~genMelody.(0.7, ~scaleMinorPent);
        ~percInst = \rim;
        ~percSteps = ~genKickPattern.(0.4); ~percAmp = 0.25;
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\counter);
    },
    // [0:20] beat hache random...
    beat_hache_random: {
        ~kickSteps = ~genKickPattern.(0.35); ~kickAmp = 0.5;
        ~kickFreq = 55; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.3;
        ~snareSteps = [0,0,1,0, 1,0,0,0, 0,1,0,0, 0,0,0,1]; ~snareAmp = 0.35;
        ~snareFreq = 220; ~snareNoiseAmt = 0.65;
        ~hatSteps = [1,0,1,1, 0,1,1,0, 1,1,0,1, 1,0,1,0]; ~hatAmp = 0.10;
        ~reload.value;
    },
    // [0:40] section : mutations toutes les 4s...
    section_mutations_toutes_les_4s: {
        // 2:00
    },
    // [2:00] DROP -- chaos contraste avec acid drone...
    drop_chaos_contraste_avec_acid_drone: {
        Synth(\impact, [\freq, 40, \decay, 1.5, \amp, 0.5]);
        ~melodyInst = \handpan;
        ~melodyAttack = 0.001; ~melodyRelease = 1.5; ~melodyCutoff = 5500;
        ~melodyAmp = 0.22;
        ~kickSteps = [1,0,0,0, 0,0,1,1, 0,0,1,0, 1,0,0,1];
        ~snareSteps = [0,0,0,1, 1,0,0,0, 0,1,0,0, 0,0,1,1];
        ~hatSteps = [1,0,1,0, 1,1,0,1, 0,1,1,0, 1,0,1,1];
        ~melodyNotes = ~genMelody.(0.7, ~scaleMinorPent);
        ~reload.value;
        // Continue mutation
        // 3:15
    },
    // [3:15] breakdown atmospheric pluck...
    breakdown_atmospheric_pluck: {
        ~kickSteps = (0!16); ~snareSteps = (0!16); ~hatAmp = 0.05;
        ~melodyInst = \pluck;
        ~melodyAttack = 0.001; ~melodyRelease = 0.6; ~melodyCutoff = 4500;
        ~melodyAmp = 0.22;
        ~reload.value;
    },
    // [3:45] retour glitch + mutations frenetiques...
    retour_glitch_mutations_frenetiques: {
        Synth(\impact, [\freq, 35, \decay, 2, \amp, 0.55]);
        ~kickSteps = [1,0,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,0];
        ~snareSteps = [0,0,1,0, 1,0,0,1, 0,1,0,0, 1,0,1,0];
        ~hatSteps = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,0,1]; ~hatAmp = 0.13;
        ~reload.value;
        // Chaos final
        // 5:45
    },
    // [5:45] outro fade chaos progressif...
    outro_fade_chaos_progressif: {
    },
);
"=== sections V chargees : ".post; ~sections['V'].keys.asArray.postln;
)

// --- Lancer une section TRACK V ---
( ~jumpTo.('V', 'glitch_idm_130_bpm'); )  // [0:00] === GLITCH IDM 130 BPM ===
( ~jumpTo.('V', 'intro_pluck_random_drone'); )  // [0:00] intro pluck random + drone...
( ~jumpTo.('V', 'beat_hache_random'); )  // [0:20] beat hache random...
( ~jumpTo.('V', 'section_mutations_toutes_les_4s'); )  // [0:40] section : mutations toutes les 4s...
( ~jumpTo.('V', 'drop_chaos_contraste_avec_acid_drone'); )  // [2:00] DROP -- chaos contraste avec acid drone...
( ~jumpTo.('V', 'breakdown_atmospheric_pluck'); )  // [3:15] breakdown atmospheric pluck...
( ~jumpTo.('V', 'retour_glitch_mutations_frenetiques'); )  // [3:45] retour glitch + mutations frenetiques...
( ~jumpTo.('V', 'outro_fade_chaos_progressif'); )  // [5:45] outro fade chaos progressif...


// =====================================================================
//  TRACK W -- 9 sections (auto-extraites des postln)
// =====================================================================
(
~sections['W'] = (
    // [0:00] === DUB TECHNO 120 BPM ===
    dub_techno_120_bpm: {
        TempoClock.default.tempo = 120 / 60;
    },
    // [0:00] intro drone...
    intro_drone: {
        ~melodyInst = \drone;
        ~melodyAttack = 1.5; ~melodyRelease = 3.0; ~melodyCutoff = 1200;
        ~melodyAmp = 0.18;
        ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,39,0,0,0,
                        36,0,0,0,0,0,0,0, 0,0,0,0,41,0,0,0];
        ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
        ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
        ~reload.value;
        ~enableHarmony.(\dubBass);
    },
    // [0:45] kick minimal 4/4 + hat tres discret...
    kick_minimal_4_4_hat_tres_discret: {
        ~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
        ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.45; ~kickClick = 0.08;
        ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
        ~reload.value;
    },
    // [1:30] chord stabs warmPad avec long release...
    chord_stabs_warmpad_avec_long_release: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.05; ~melodyRelease = 1.8; ~melodyCutoff = 2000;
        ~melodyAmp = 0.18;
        ~melodyNotes = [60,0,0,0,0,0,0,0, 0,0,0,0,67,0,0,0,
                        63,0,0,0,0,0,0,0, 0,0,0,0,70,0,0,0];
        ~reload.value;
    },
    // [3:00] sub bass profond...
    sub_bass_profond: {
        Synth(\gong, [\freq, 50, \decay, 5, \amp, 0.4]);
        ~melodyInst = \subBoom;
        ~melodyAttack = 0.005; ~melodyRelease = 0.7; ~melodyAmp = 0.30;
        ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                        39,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
        ~reload.value;
    },
    // [4:30] section accord stabs evolutifs...
    section_accord_stabs_evolutifs: {
        ~melodyInst = \warmPad;
        ~melodyAttack = 0.05; ~melodyRelease = 2.0; ~melodyCutoff = 1800;
        ~melodyAmp = 0.20;
        ~melodyNotes = [60,0,0,67, 0,0,70,0, 0,0,72,0, 67,0,0,0,
                        63,0,0,70, 0,0,72,0, 0,0,75,0, 70,0,0,0];
        ~reload.value;
    },
    // [6:10] cutoff sweep tres lent (caracteristique dub)...
    cutoff_sweep_tres_lent_caracteristique_dub: {
        // 7:10
    },
    // [7:10] retour drone + gong...
    retour_drone_gong: {
        Synth(\gong, [\freq, 45, \decay, 8, \amp, 0.5]);
        ~melodyInst = \drone;
        ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 1500;
        ~melodyAmp = 0.20;
        ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,39,0,0,0,
                        36,0,0,0,0,0,0,0, 0,0,0,0,41,0,0,0];
        ~reload.value;
    },
    // [8:40] outro long fade tres dub...
    outro_long_fade_tres_dub: {
        Synth(\gong, [\freq, 35, \decay, 12, \amp, 0.6]);
        ~hatAmp = 0.04;
    },
);
"=== sections W chargees : ".post; ~sections['W'].keys.asArray.postln;
)

// --- Lancer une section TRACK W ---
( ~jumpTo.('W', 'dub_techno_120_bpm'); )  // [0:00] === DUB TECHNO 120 BPM ===
( ~jumpTo.('W', 'intro_drone'); )  // [0:00] intro drone...
( ~jumpTo.('W', 'kick_minimal_4_4_hat_tres_discret'); )  // [0:45] kick minimal 4/4 + hat tres discret...
( ~jumpTo.('W', 'chord_stabs_warmpad_avec_long_release'); )  // [1:30] chord stabs warmPad avec long release...
( ~jumpTo.('W', 'sub_bass_profond'); )  // [3:00] sub bass profond...
( ~jumpTo.('W', 'section_accord_stabs_evolutifs'); )  // [4:30] section accord stabs evolutifs...
( ~jumpTo.('W', 'cutoff_sweep_tres_lent_caracteristique_dub'); )  // [6:10] cutoff sweep tres lent (caracteristique dub)...
( ~jumpTo.('W', 'retour_drone_gong'); )  // [7:10] retour drone + gong...
( ~jumpTo.('W', 'outro_long_fade_tres_dub'); )  // [8:40] outro long fade tres dub...

