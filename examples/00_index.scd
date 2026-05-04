// =====================================================================
//  examples/00_index.scd  --  Index des exemples de workflow
//
//  CONVENTION
//    Chaque fichier de ce dossier est un mini-tutoriel a executer
//    bloc par bloc dans l'IDE SuperCollider (Cmd+Entree sur chaque
//    parenthese top-level). Il N'EST PAS charge via .load -- on
//    avance manuellement, en lisant les commentaires.
//
//  PARCOURS RECOMMANDE pour decouvrir le projet
//    01_quickstart.scd            Premier "Hello world" sonore (debutant)
//    02_first_track.scd           Lancer une track autonome (debutant)
//    04_filter_lfo_vcf.scd        LFO + VCF -- la base du modular live
//    06_drum_kits_sequences.scd   Macros rapides pour kits + sequences
//    07_loops_manager.scd         Gestionnaire de boucles propre
//    09_scenes_recall.scd         Save / recall snapshots
//    11_playlist_auto.scd         Lancer une session sans rien faire
//
//  CATALOGUE COMPLET
//    01_quickstart.scd            (debutant) Premier demarrage
//    02_first_track.scd           (debutant) Track autonome A
//    03_multi_melody_tracks.scd   (intermediaire) Multi-pistes melodiques
//    04_filter_lfo_vcf.scd        (intermediaire) LFO + VCF master
//    05_drops_breakdowns_buildups (intermediaire) Tricks scéniques
//    06_drum_kits_sequences.scd   (debutant) Drum kits + sequences pretes
//    07_loops_manager.scd         (intermediaire) loops.scd workflow
//    08_jump_sections.scd         (intermediaire) Naviguer dans les tracks
//    09_scenes_recall.scd         (intermediaire) Snapshot / recall
//    10_midi_controller.scd      (avance) Setup controller MIDI
//    11_playlist_auto.scd         (debutant) Playlist auto + controles
//    12_chord_progressions.scd    (intermediaire) ~progXxx + chordsToMelody
//    13_world_ethno.scd           (intermediaire) Workflow oriental/asia
//    14_fx_chains_dynamic.scd     (avance) FX bus + LFO sur params FX
//    15_full_live_set.scd         (avance) Set live 30 minutes complet
// =====================================================================


// --- Ouvrir tous les exemples dans l'IDE -----------------------------
(
var root = if (thisProcess.nowExecutingPath.notNil) { thisProcess.nowExecutingPath.dirname } { "/Users/electron/Documents/Projets_Creatifs/sound_algo/examples" };
[
    "01_quickstart.scd",
    "02_first_track.scd",
    "03_multi_melody_tracks.scd",
    "04_filter_lfo_vcf.scd",
    "05_drops_breakdowns_buildups.scd",
    "06_drum_kits_sequences.scd",
    "07_loops_manager.scd",
    "08_jump_sections.scd",
    "09_scenes_recall.scd",
    "10_midi_controller.scd",
    "11_playlist_auto.scd",
    "12_chord_progressions.scd",
    "13_world_ethno.scd",
    "14_fx_chains_dynamic.scd",
    "15_full_live_set.scd",
].do { |path|
    Document.open(root +/+ path);
};
)
