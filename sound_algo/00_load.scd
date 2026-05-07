// =====================================================================
//  00_load.scd  --  Loader / index du projet
//
//  STRUCTURE
//
//    setup.scd                Verification + init complete
//                             (~check / ~setupAll / ~setupLive /
//                              ~ensureLive / ~teardown)
//    engine.scd               Moteur (SynthDef base + Pdef + sidechain bus)
//    synth/                   SynthDef instruments (auto-loader _index.scd)
//                             drums/, bass/, lead/, pad/, world/, master/
//    fx/                      SynthDef effets (auto-loader _index.scd)
//                             bus/, insert/, trick/
//    palette/
//      scales.scd             Scales (mineur/dorian/.../hijaz/vietnam) +
//                             helpers genMelody/mutate/octavate/transpose/
//                             retrograde/densify/sparsify/jitter/
//                             genAcidNotes/Accents/Slides/genKickPattern/
//                             randomTweak (SOURCE UNIQUE)
//      melodies/              MODULE melodies (loader = melodies/index.scd)
//        helpers.scd            stretch/chain/mirror/sequenceUp/callResponse/...
//        short.scd              ~m1..~m78    (32 pas)
//        long.scd               ~ml1..~ml30  (64 pas)
//        xlong.scd              ~mxl1..~mxl15(96 pas)
//        epic.scd               ~mepic1..~mepic10 (128 pas)
//        bank.scd               ~melodyBank par genre + selecteurs
//        tracks.scd             multi-pistes melodiques (~melTrackAdd/On/...)
//      harmonics/             MODULE harmonie (loader = harmonics/index.scd)
//        helpers.scd            genThirdHarmony / genFifthHarmony / genCounter / ...
//        presets.scd            ~enableHarmony.(\preset) -- 10 presets (SOURCE UNIQUE)
//      rhythm/                MODULE rythmes / kicks / percussions
//        _index.scd             Auto-loader (charge fills/ + sequences/)
//        kicks/                 25 patterns + 12 timbres kick (1 fichier/preset)
//        percussions/           ~25 patterns clap/perc (1 fichier/preset)
//        drum_kits/             21 kits complets (1 fichier/kit)
//        patterns_genre/        40 patterns signature par genre (1 fichier/preset)
//        sequences/             Macros de sequences (~seqIntro/Buildup/Drop...)
//        fills/                 Snare fill / tom fill
//      timbres.scd            26 timbres melodie (L1-L26)
//      styles.scd             5 styles complets (Acid Rave, Dub, Hard...)
//      chords_progressions.scd ~35 progressions d'accords (auto + ~progXxx)
//      fx.scd                 Riser/sweep/impact/crash/vinyl
//      fx_genre.scd           Combos FX prets a l'emploi par genre
//      tweaks_template.scd    Templates de tweaks par genre
//    live/
//      _load.scd              Mini-loader API live (charge les 5 wrappers)
//      kicks.scd              WRAPPER ~k / ~kk -- combos kick (pattern+timbre)
//      melodies.scd           WRAPPER ~m / ~mm -- short/long/xlong/epic + harmonie
//      fx.scd                 WRAPPER ~fx / ~ff -- presets / drop / VCF / LFO
//      chains.scd             WRAPPER ~ch / ~cc -- intro/drop/breakdown/loops
//      patterns.scd           WRAPPER ~p -- kits + presets de genre rythmiques
//      live.scd               Boite a outils live (LFO, VCF, drops, tricks)
//      mixer.scd              Faders / mute / solo par voie + master
//      loops.scd              Gestionnaire de boucles / pistes (live)
//      fx_bus.scd             9 bus FX reverb/delay/chorus/... + presets
//      live_fx_panel.scd      PANNEAU FX LIVE tout-en-un (Cmd+Entree par bloc)
//      scenes.scd             Save / recall etat global (snapshot)
//      tweaks.scd             Tweaks live (cutoff, drive, mute, sidechain...)
//    control/
//      midi.scd               Mapping controller MIDI (CC + notes)
//      playlist.scd           11 playlists prefefinies + auto-fade
//      jump.scd               Lance n'importe quelle section de track directement
//    tracks/
//      A_acid_journey.scd ... W_dub_techno.scd  (23 tracks A->W)
//    examples/                Mini-tutoriels Cmd+Entree pas-a-pas (16 fichiers)
//      00_index.scd           Catalogue + parcours recommande
//      01_quickstart.scd      Premier "Hello, sound_algo"
//      02_first_track.scd     Lancer une track autonome
//      ...                    voir examples/00_index.scd
//
//  WORKFLOW
//    1. Cmd+Entree sur "CHARGER TOUT" -> tout est charge automatiquement
//       (engine + synthdefs + scales + melodies + harmonics + setup
//        helpers + boot serveur + live/* + rhythm/fills + sequences +
//        jump). Le bloc affiche un ~check.() final pour voir l'etat.
//    2. Lance une track (tracks/*.scd) ou les Pdef (PLAY VIDE / PLAY KICK
//       / PLAY DEFAULT plus bas dans ce fichier).
//    3. Cmd+Entree sur ( ~check.() ) a tout moment pour voir l'etat.
//    4. ( ~teardown.() ) pour stopper et liberer proprement.
//
//  Pour decouvrir le projet : ouvre examples/00_index.scd et suis le
//  parcours pas-a-pas.
// =====================================================================



// --- BASE PATH (set ~base sans rien charger -- optionnel) ------------
//   Utile si tu veux juste set le chemin avant de Cmd+Entree sur un
//   autre bloc. CHARGER TOUT et CHARGER MINIMAL le font deja.
(
// Auto-detect ~base from this file's location so the project is portable
// across machines (GrosMac dev path vs MBP /Users/electron/AV-Live/sound_algo/
// vs anywhere else). Falls back to the legacy hard-coded path only if the
// file isn't being executed from disk (rare — Cmd+Enter on a buffer).
~base = (thisProcess.nowExecutingPath !? { |p| p.dirname ++ "/" })
        ?? "/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/";
"~base = ".post; ~base.postln;
)


// --- CHARGER TOUT (charge TOUT en un seul Cmd+Entree) ----------------
//   engine + synthdefs + scales + melodies + harmonics + setup helpers,
//   puis ~setupAll.() qui charge fx_bus + live + mixer + scenes + loops
//   + fills + sequences + jump apres boot serveur, puis ~check.() final.
//
//   Ce bloc est AUTONOME : pas besoin d'evaluer BASE PATH avant.
(
// Auto-detect ~base from this file's location so the project is portable
// across machines (GrosMac dev path vs MBP /Users/electron/AV-Live/sound_algo/
// vs anywhere else). Falls back to the legacy hard-coded path only if the
// file isn't being executed from disk (rare — Cmd+Enter on a buffer).
~base = (thisProcess.nowExecutingPath !? { |p| p.dirname ++ "/" })
        ?? "/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/";
(~base ++ "engine.scd").load;
(~base ++ "synth/_index.scd").load;
(~base ++ "fx/_index.scd").load;
(~base ++ "palette/scales.scd").load;
(~base ++ "palette/melodies/index.scd").load;
(~base ++ "palette/harmonics/index.scd").load;
(~base ++ "setup.scd").load;       // ~check / ~setupAll / ~setupLive / ~teardown
// NOTE : ~setupAll.() est appele par live/_load.scd ci-dessous (qui gere
// l'idempotence via ~setupAll_done). L'appeler ici en plus declenchait
// un DOUBLE BOOT : 1er ~setupAll lance s.waitForBoot async, puis le
// .load de live/_load.scd voit ~setupAll_done = nil et relance ~setupAll
// -> "address in use" + zombie scsynth. Fix : un seul appel via _load.
(~base ++ "live/_load.scd").load;   // boot + tous modules + wrappers API live
)


// --- CHARGER MINIMAL (engine + synthdefs + scales seulement) ---------
//   Pour debugger ou demarrer sans live/mixer/fx. Pas de boot serveur
//   automatique, pas de helpers ~check / ~setupAll.
(
// Auto-detect ~base from this file's location so the project is portable
// across machines (GrosMac dev path vs MBP /Users/electron/AV-Live/sound_algo/
// vs anywhere else). Falls back to the legacy hard-coded path only if the
// file isn't being executed from disk (rare — Cmd+Enter on a buffer).
~base = (thisProcess.nowExecutingPath !? { |p| p.dirname ++ "/" })
        ?? "/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/";
(~base ++ "engine.scd").load;
(~base ++ "synth/_index.scd").load;
(~base ++ "fx/_index.scd").load;
(~base ++ "palette/scales.scd").load;
)


// --- CHARGER ENGINE SEUL (minimum vital) -----------------------------
(
(~base ++ "engine.scd").load;
)


// --- CHARGER SYNTH (tous les SynthDef instruments) -------------------
(
(~base ++ "synth/_index.scd").load;
)


// --- CHARGER FX (tous les SynthDef effets) ---------------------------
(
(~base ++ "fx/_index.scd").load;
)


// --- OUVRIR FICHIERS dans l'IDE -------------------------------------
//   Plusieurs blocs cibles : choisis celui dont tu as besoin (Cmd+Entree).
//   NB : les fichiers charges via CHARGER TOUT (engine, synthdefs, scales,
//        melodies/, harmonics/, rhythm/fills) ne sont PAS proposes ici --
//        leur contenu est interne et tu n'as pas a les editer en live.
// --------------------------------------------------------------------

// --- OUVRIR ESSENTIEL LIVE (outils performance + entree examples) ----
(
var root = if (thisProcess.nowExecutingPath.notNil) { thisProcess.nowExecutingPath.dirname } { "/Users/electron/Documents/Projets_Creatifs/sound_algo" };
[
    "setup.scd",                       // ~check / ~setupAll / ~teardown
    "live/tweaks.scd",                 // tweaks live (cutoff/drive/mute/SC)
    "live/live_fx_panel.scd",          // PANNEAU FX tout-en-un
    "live/mixer.scd",                  // faders / mute / solo / master
    "live/scenes.scd",                 // save / recall snapshots
    "palette/rhythm/_index.scd",       // ~snareFill / ~tomFill / ~seqPlay (auto)
    "control/jump.scd",                // sauter dans une section
    "examples/00_index.scd",           // catalogue tutoriels
].do { |p| Document.open(root +/+ p) };
)


// --- OUVRIR OUTILS LIVE AVANCES (LFO/VCF/loops/FX bus/MIDI) ----------
(
var root = if (thisProcess.nowExecutingPath.notNil) { thisProcess.nowExecutingPath.dirname } { "/Users/electron/Documents/Projets_Creatifs/sound_algo" };
[
    "live/live.scd",                   // LFO / VCF / drops / tricks
    "live/loops.scd",                  // gestionnaire de boucles
    "live/fx_bus.scd",                 // 9 bus FX + presets + tap tempo
    "control/midi.scd",                // mapping MIDI controller
    "control/playlist.scd",            // playlists auto-fade
].do { |p| Document.open(root +/+ p) };
)


// --- OUVRIR PALETTES PRESETS (Cmd+Entree sur un preset) --------------
(
var root = if (thisProcess.nowExecutingPath.notNil) { thisProcess.nowExecutingPath.dirname } { "/Users/electron/Documents/Projets_Creatifs/sound_algo" };
[
    "palette/styles.scd",
    "palette/timbres.scd",
    "palette/chords_progressions.scd",
    "palette/fx_genre.scd",
    "palette/tweaks_template.scd",
    "palette/rhythm/_index.scd",       // loader recursif fills+sequences
    // NB : les presets rythmiques sont eclates en sous-dossiers
    //   palette/rhythm/{drum_kits,patterns_genre,kicks,percussions,sequences,fills}/
    //   1 fichier = 1 preset Cmd+Entree. Ouvre-les a la demande dans l'IDE.
].do { |p| Document.open(root +/+ p) };
)


// --- OUVRIR TRACKS (23 tracks A->W) ----------------------------------
(
var root = if (thisProcess.nowExecutingPath.notNil) { thisProcess.nowExecutingPath.dirname } { "/Users/electron/Documents/Projets_Creatifs/sound_algo" };
PathName(root +/+ "tracks").files
    .select { |f| f.extension == "scd" }
    .sort   { |a, b| a.fileName < b.fileName }
    .do     { |f| Document.open(f.fullPath) };
)


// --- OUVRIR EXAMPLES (16 tutoriels Cmd+Entree pas-a-pas) -------------
(
var root = if (thisProcess.nowExecutingPath.notNil) { thisProcess.nowExecutingPath.dirname } { "/Users/electron/Documents/Projets_Creatifs/sound_algo" };
PathName(root +/+ "examples").files
    .select { |f| f.extension == "scd" }
    .sort   { |a, b| a.fileName < b.fileName }
    .do     { |f| Document.open(f.fullPath) };
)


// --- OUVRIR TOUT (ancien comportement -- ~60 onglets, lourd) ---------
//   A eviter au quotidien -- prefere les blocs cibles ci-dessus.
(
var root = if (thisProcess.nowExecutingPath.notNil) { thisProcess.nowExecutingPath.dirname } { "/Users/electron/Documents/Projets_Creatifs/sound_algo" };
[
    "engine.scd",
    "synth/_index.scd", "fx/_index.scd",
    "palette/scales.scd",
    "palette/melodies/helpers.scd", "palette/melodies/short.scd",
    "palette/melodies/long.scd",    "palette/melodies/xlong.scd",
    "palette/melodies/epic.scd",    "palette/melodies/bank.scd",
    "palette/melodies/tracks.scd",
    "palette/harmonics/helpers.scd","palette/harmonics/presets.scd",
    "palette/rhythm/_index.scd",    "palette/fx.scd",
].do { |p| Document.open(root +/+ p) };
)


// --- PLAY VIDE -- demarre les sequencers en silence ------------------
//   Tous les patterns sont vides : tu construis au fur et a mesure.
//   Ex : ( ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~reload.value; )
(
TempoClock.default.tempo = ~bpm / 60;
~kickSteps    = (0 ! 16);
~hatSteps     = (0 ! 16);
~snareSteps   = (0 ! 16);
~clapSteps    = (0 ! 16);
~percSteps    = (0 ! 16);
~acidNotes    = (0 ! 16);
~acidAccents  = (0 ! 16);
~acidSlides   = (0 ! 16);
~melodyNotes  = (0 ! 32);
~harmonyNotes = (0 ! 32);
~reload.value;
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
    .do { |k| Pdef(k).play };
"=== PLAY VIDE -- ajoute des steps puis ~reload.value ===".postln;
)


// --- PLAY KICK -- demarre avec juste un kick 4/4 ---------------------
//   Ajoute hat/snare/melody en tweakant les ~xxxSteps puis ~reload.value
(
TempoClock.default.tempo = ~bpm / 60;
~kickSteps    = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
~hatSteps     = (0 ! 16);
~snareSteps   = (0 ! 16);
~clapSteps    = (0 ! 16);
~percSteps    = (0 ! 16);
~acidNotes    = (0 ! 16);
~acidAccents  = (0 ! 16);
~acidSlides   = (0 ! 16);
~melodyNotes  = (0 ! 32);
~harmonyNotes = (0 ! 32);
~reload.value;
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
    .do { |k| Pdef(k).play };
"=== PLAY KICK 4/4 ===".postln;
)


// --- PLAY DEFAULT -- ancien comportement (kick + hat + snare + acid) -
//   Lance avec les patterns par defaut definis dans engine.scd
(
TempoClock.default.tempo = ~bpm / 60;
~reload.value;
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
    .do { |k| Pdef(k).play };
"=== PLAY DEFAULT ===".postln;
)


// --- STOP -- coupe les sequencers (garde le master limiter) ----------
(
~track !? { ~track.stop };
~filterSweep !? { ~filterSweep.stop };
~randomLoop !? { ~randomLoop.stop };
~melodyEvolve !? { ~melodyEvolve.stop };
~lRotate !? { ~lRotate.stop };
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
    .do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)


// --- ARRET TOTAL (libere bus + master) -------------------------------
(
~track !? { ~track.stop };
~filterSweep !? { ~filterSweep.stop };
~randomLoop !? { ~randomLoop.stop };
~melodyEvolve !? { ~melodyEvolve.stop };
~lRotate !? { ~lRotate.stop };
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
    .do { |k| Pdef(k).stop };
~masterLim !? { ~masterLim.free; ~masterLim = nil };
~scBus !? { ~scBus.free; ~scBus = nil };
"=== ARRET TOTAL ===".postln;
)
