// =====================================================================
//  _album.scd  --  Album G "Detroit Soulful" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM G
//    3. ~playTrack.(\G, n) pour une track / ~playAlbum.(\G) pour l'album
//       ~stopAlbum.() pour interrompre.
// =====================================================================

(  // --- SETUP ALBUM G ---
~albums = ~albums ? ();
~albums[\G] = (
    title: "Detroit Soulful",
    folder: "tracks/G_detroit_soulful/",
    tracks: [
        \G01_motor_city,
        \G02_rhodes_dreams,
        \G03_strings_of_life,
        \G04_jazz_machine,
        \G05_warehouse_groove,
        \G06_belleville_nights,
        \G07_soul_stomp,
        \G08_organ_chapel,
        \G09_underground_resistance,
        \G10_deep_funk,
        \G11_galactic_soul,
        \G12_midnight_drive,
        \G13_paradise_garage,
        \G14_choir_breakdown,
        \G15_detroit_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album G] setup OK -- ~playTrack.(\\G, n) | ~playAlbum.(\\G) | ~stopAlbum.()".postln;
)


// =====================================================================
//  RACCOURCIS LIVE -- Cmd+Entree sur la ligne souhaitee
// =====================================================================

( ~playTrack.(\G,  1); )    // G01 motor_city            (4 min)
( ~playTrack.(\G,  2); )    // G02 rhodes_dreams         (5 min)
( ~playTrack.(\G,  3); )    // G03 strings_of_life       (6 min)
( ~playTrack.(\G,  4); )    // G04 jazz_machine          (7 min)
( ~playTrack.(\G,  5); )    // G05 warehouse_groove      (8 min)
( ~playTrack.(\G,  6); )    // G06 belleville_nights     (6 min)
( ~playTrack.(\G,  7); )    // G07 soul_stomp            (5 min)
( ~playTrack.(\G,  8); )    // G08 organ_chapel          (6 min)
( ~playTrack.(\G,  9); )    // G09 underground_resistance(7 min)
( ~playTrack.(\G, 10); )    // G10 deep_funk             (8 min)
( ~playTrack.(\G, 11); )    // G11 galactic_soul         (7 min)
( ~playTrack.(\G, 12); )    // G12 midnight_drive        (5 min)
( ~playTrack.(\G, 13); )    // G13 paradise_garage       (4 min)
( ~playTrack.(\G, 14); )    // G14 choir_breakdown       (5 min)
( ~playTrack.(\G, 15); )    // G15 detroit_finale        (6 min)

( ~playAlbum.(\G); )        // album entier 01 -> 15
( ~stopAlbum.(); )          // arret immediat
