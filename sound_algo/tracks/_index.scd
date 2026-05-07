// =====================================================================
//  tracks/_index.scd  --  Index global des 23 albums (A-W, 15 tracks/album)
//
//  Charge tous les _album.scd pour declarer ~albums[\A..\W] + helpers
//  ~playTrack / ~playAlbum / ~stopAlbum.
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live + memory_guard)
//    2. Cmd+Entree sur SETUP INDEX (1 fois) -- charge les 23 _album.scd
//    3. ~playTrack.(\A, 7)         joue track 7 de l'album A
//       ~playAlbum.(\A)            enchaine A01 -> A15
//       ~stopAlbum.()              stop immediat
//       ~listAlbums.()             liste tous les albums + titres
//
//  Total : 23 albums × 15 tracks = 345 tracks autonomes
//          (+ 23 standalones X_<slug>.scd a la racine, anciens)
// =====================================================================

(  // --- SETUP INDEX ---
~base = ~base ?? { "/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/" };

// Charge chaque _album.scd (declare ~albums[\X])
[
    \A_acid_journey,
    \B_deep_to_hard,
    \C_hypnotic_loop,
    \D_wobble_drop,
    \E_vietnam_hard,
    \F_trance_uplifter,
    \G_detroit_soulful,
    \H_acid_trance,
    \I_liquid_dnb,
    \J_ambient_cinematic,
    \K_tribal_ethno,
    \L_future_garage,
    \M_chiptune_madness,
    \N_phonk,
    \O_asian_cinematic,
    \P_industrial,
    \Q_neurofunk_dnb,
    \R_synthwave,
    \S_drone_doom,
    \T_hardcore_gabber,
    \U_vocal_trance,
    \V_glitch_idm,
    \W_dub_techno,
].do { |dir|
    var path = ~base ++ "tracks/" ++ dir ++ "/_album.scd";
    if (File.exists(path)) {
        // Les _album.scd ont un SETUP (1er bloc) + des raccourcis Cmd+Entree
        // (blocs suivants). On ne charge QUE le 1er bloc via ~loadFirstBlock
        // (sinon parser SC echoue sur "unexpected '(' expecting end of file").
        if (~loadFirstBlock.notNil) {
            ~loadFirstBlock.(path);
        } {
            // Fallback : .load full file (echoue si multi-bloc)
            path.load;
        };
    } {
        ("[index] !! manquant : " ++ path).postln;
    };
};

// Helper : liste tous les albums + leur titre + nombre de tracks
~listAlbums = {
    "".postln;
    "=== 23 ALBUMS DISPONIBLES ===".postln;
    ~albums.keys.asArray.sort.do { |key|
        var info = ~albums[key];
        var dur = info[\durations].sum;
        var minTotal = (dur / 60).round(0.1);
        ("  " ++ key ++ "  " ++ info[\title]
         ++ "  (" ++ info[\tracks].size ++ " tracks, ~" ++ minTotal ++ " min)").postln;
    };
    "".postln;
    "  ~playTrack.(\\A, 7)   ~playAlbum.(\\A)   ~stopAlbum.()".postln;
    "  ~listTracks.(\\A)     liste les 15 tracks d'un album".postln;
};

// Helper : liste les 15 tracks d'un album avec durees
~listTracks = { |album = \A|
    var info = ~albums[album.asSymbol];
    if (info.isNil) {
        ("!! album " ++ album ++ " inconnu").postln;
    } {
        ("=== " ++ album ++ " : " ++ info[\title] ++ " ===").postln;
        info[\tracks].do { |slug, i|
            var dur = info[\durations][i];
            var min = (dur / 60).round(0.1);
            ("  " ++ (i + 1).asString.padLeft(2) ++ "  "
             ++ slug ++ "  (" ++ dur ++ "s = " ++ min ++ " min)").postln;
        };
    };
};

("[index] " ++ ~albums.size ++ " albums charges -- ~listAlbums.()").postln;
)


// =====================================================================
//  RACCOURCIS LIVE -- Cmd+Entree sur la ligne souhaitee dans l'IDE.
//  Commentes pour permettre `.load` de ce fichier sans erreur de parse :
//  sclang refuse plusieurs blocs `(...)` top-level dans un meme load.
//  Decommenter au besoin dans l'IDE.
// =====================================================================

/*
( ~listAlbums.(); )                      // liste les 23 albums
( ~listTracks.(\A); )                    // liste les 15 tracks de A
( ~listTracks.(\Q); )                    // liste les 15 tracks de Q

( ~playTrack.(\A, 1); )                  // joue A01
( ~playTrack.(\Q, 5); )                  // joue Q05
( ~playTrack.(\W, 10); )                 // joue W10

( ~playAlbum.(\A); )                     // album A en entier
( ~playAlbum.(\J); )                     // album J ambient
( ~stopAlbum.(); )                       // stop immediat
*/
