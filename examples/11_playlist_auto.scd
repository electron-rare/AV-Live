// =====================================================================
//  examples/11_playlist_auto.scd  --  Session auto playlist
//
//  TITRE       : Lancer plusieurs tracks d'affilee sans rien faire
//  DUREE       : variable (selon la playlist choisie)
//  NIVEAU      : debutant
//  PREREQUIS   : CHARGER TOUT (00_load.scd)
//                + ouvrir playlist.scd, evaluer son SETUP (1er bloc)
//
//  CONCEPTS
//    ~playPlaylist.([[file, dur], ...]) joue chaque track pendant
//    "dur" secondes, puis crossfade vers la suivante.
//    Pendant que ca tourne, tu peux SKIP, PAUSE, RESUME.
// =====================================================================


// --- [etape 0] Verification ----------------------------------------
(
if (~playPlaylist.isNil) {
    "!!! playlist.scd pas charge -- ouvre playlist.scd et evalue son SETUP".postln;
} {
    "playlist.scd OK".postln;
};
)


// --- [etape 1] PLAYLIST DEMO -- 4 tracks de 90s chacune (6 min) ----
//   Custom playlist courte pour tester. Pour les playlists 1h+ voir
//   playlist.scd (PLAYLIST INTEGRALE, DANCE FLOOR, CHILL, ...).
(
~playPlaylist.([
    ["A_acid_journey.scd",     90],
    ["F_trance_uplifter.scd",  90],
    ["G_detroit_soulful.scd",  90],
    ["W_dub_techno.scd",       90],
]);
)
//  -- la 1ere track demarre. Toutes les 90s, on enchaine la suivante
//  avec un crossfade.


// --- [etape 2] INFO -- combien de synths actifs / CPU --------------
//   A relancer ponctuellement pendant la playlist.
( ("synths actifs: " ++ s.numSynths ++ " | CPU: " ++ s.avgCPU.round(0.1) ++ "%").postln; )


// --- [etape 3] PAUSE -- mute le master limiter ---------------------
//   Pratique pour repondre a un appel sans tout couper.
( ~masterLim !? { ~masterLim.run(false) }; "[PAUSE]".postln; )


// --- [etape 4] RESUME ---------------------------------------------
( ~masterLim !? { ~masterLim.run(true)  }; "[RESUME]".postln; )


// --- [etape 5] SKIP TRACK -- passe a la suivante immediatement -----
//   Stop la track + tous les Pdef ; la playlist reprend le controle
//   et lance la track suivante au prochain tick.
(
~track !? { ~track.stop };
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"[SKIP] passage a la track suivante".postln;
)


// --- [etape 6] STOP PLAYLIST ---------------------------------------
//   Stoppe la playlist, la track en cours, et les Pdef.
(
~playlist !? { ~playlist.stop; ~playlist = nil };
~track !? { ~track.stop; ~track = nil };
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== PLAYLIST STOPPED ===".postln;
)


// --- [etape 7] (variantes) Lancer une playlist deja definie -------
//   Ouvre playlist.scd et evalue le bloc qui te plait :
//     - PLAYLIST INTEGRALE (~1h30 de tout)
//     - PLAYLIST DANCE FLOOR (~1h30 dansant)
//     - PLAYLIST CHILL (~1h ambient)
//     - PLAYLIST BASS MUSIC (~1h dubstep + dnb)
//     - PLAYLIST HARD (~50 min hardcore)
//     - PLAYLIST WORLD (~50 min asia + tribal)
//     - PLAYLIST RETRO (~30 min synthwave)
//     - PLAYLIST EXPERIMENTAL (~38 min glitch + drone)
