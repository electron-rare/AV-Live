// =====================================================================
//  playlist.scd  --  Lance les tracks les unes apres les autres
//
//  PREREQUIS : engine + synthdefs (charger d'abord 00_load.scd)
//  USAGE     : Cmd+Entree sur une playlist (au choix), elle s'enchaine
//              automatiquement.
//              Pour stopper : evaluer le bloc STOP PLAYLIST
// =====================================================================


// --- HELPER ~playPlaylist -------------------------------------------
//   trackList = [[ "filename.scd", duration_seconds ], ...]
(
~playPlaylist = { |trackList, fadeOut = 4|
    ~playlist !? { ~playlist.stop };
    ~playlist = Routine({
        var total = trackList.collect { |item| item[1] }.sum;
        ("=== PLAYLIST -- " ++ trackList.size ++ " tracks, " ++
            (total / 60).round(0.1) ++ " min total ===").postln;
        trackList.do { |item, idx|
            var path = item[0]; var dur = item[1];
            ("[" ++ (idx + 1) ++ "/" ++ trackList.size ++ "] " ++ path ++
                " (" ++ (dur/60).round(0.1) ++ " min)").postln;
            ~fading = false;
            (~base ++ "tracks/" ++ path).load;
            (dur - fadeOut).wait;
            // FIX RACE : stopper la Routine track AVANT le fade pour qu'elle
            // n'ecrase pas les amps qu'on baisse
            ~track !? { ~track.stop };
            ~fading = true;
            ("[fade out " ++ fadeOut ++ "s]").postln;
            (fadeOut * 4).do { |k|
                ~melodyAmp  = ~melodyAmp  * 0.92;
                ~harmonyAmp = ~harmonyAmp * 0.92;
                ~kickAmp    = ~kickAmp    * 0.92;
                ~hatAmp     = ~hatAmp     * 0.92;
                ~snareAmp   = ~snareAmp   * 0.92;
                ~clapAmp    = ~clapAmp    * 0.92;
                ~percAmp    = ~percAmp    * 0.92;
                ~acidAmp    = ~acidAmp    * 0.92;     // FIX : acid line absente du fade
                ~reload.value;
                0.25.wait;
            };
            ~fading = false;
            [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
             \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
            2.wait;
        };
        "=== PLAYLIST TERMINEE ===".postln;
    }).play;
};
"=== ~playPlaylist pret ===".postln;
)


// --- STOP PLAYLIST ---------------------------------------------------
(
~playlist !? { ~playlist.stop; ~playlist = nil };
~track !? { ~track.stop; ~track = nil };
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== PLAYLIST ARRETEE ===".postln;
)



// =====================================================================
//  PLAYLISTS PREDEFINIES (Cmd+Entree sur celle qu'on veut)
// =====================================================================


// --- PLAYLIST FULL : toutes les 23 tracks (~3h12) ---------------------
(
~playPlaylist.([
    ["A_acid_journey.scd",     420],   // 7 min
    ["B_deep_to_hard.scd",     480],   // 8 min
    ["C_hypnotic_loop.scd",    600],   // 10 min
    ["D_wobble_drop.scd",      420],   // 7 min
    ["E_vietnam_hard.scd",     480],   // 8 min
    ["F_trance_uplifter.scd",  600],   // 10 min
    ["G_detroit_soulful.scd",  480],   // 8 min
    ["H_acid_trance.scd",      480],   // 8 min
    ["I_liquid_dnb.scd",       420],   // 7 min
    ["J_ambient_cinematic.scd",720],   // 12 min
    ["K_tribal_ethno.scd",     480],   // 8 min
    ["L_future_garage.scd",    420],   // 7 min
    ["M_chiptune_madness.scd", 360],   // 6 min
    ["N_phonk.scd",            300],   // 5 min
    ["O_asian_cinematic.scd",  600],   // 10 min
    ["P_industrial.scd",       480],   // 8 min
    ["Q_neurofunk_dnb.scd",    420],   // 7 min
    ["R_synthwave.scd",        480],   // 8 min
    ["S_drone_doom.scd",       900],   // 15 min
    ["T_hardcore_gabber.scd",  360],   // 6 min
    ["U_vocal_trance.scd",     600],   // 10 min
    ["V_glitch_idm.scd",       480],   // 8 min
    ["W_dub_techno.scd",       600],   // 10 min
]);
)


// --- PLAYLIST DANCE FLOOR : tracks dansantes (~1h30) ------------------
(
~playPlaylist.([
    ["A_acid_journey.scd",     420],
    ["F_trance_uplifter.scd",  600],
    ["G_detroit_soulful.scd",  480],
    ["H_acid_trance.scd",      480],
    ["I_liquid_dnb.scd",       420],
    ["L_future_garage.scd",    420],
    ["U_vocal_trance.scd",     600],
    ["W_dub_techno.scd",       600],
]);
)


// --- PLAYLIST CHILL / AMBIENT : tracks calmes (~1h) ------------------
(
~playPlaylist.([
    ["J_ambient_cinematic.scd",720],
    ["O_asian_cinematic.scd",  600],
    ["K_tribal_ethno.scd",     480],
    ["S_drone_doom.scd",       900],
    ["W_dub_techno.scd",       600],
]);
)


// --- PLAYLIST BASS MUSIC : dubstep + dnb + bass-heavy (~1h) ----------
(
~playPlaylist.([
    ["D_wobble_drop.scd",      420],
    ["E_vietnam_hard.scd",     480],
    ["L_future_garage.scd",    420],
    ["I_liquid_dnb.scd",       420],
    ["Q_neurofunk_dnb.scd",    420],
    ["N_phonk.scd",            300],
    ["P_industrial.scd",       480],
]);
)


// --- PLAYLIST HARD : techno hard / hardcore / industrial (~50 min) ---
(
~playPlaylist.([
    ["B_deep_to_hard.scd",     480],
    ["P_industrial.scd",       480],
    ["T_hardcore_gabber.scd",  360],
    ["E_vietnam_hard.scd",     480],
    ["Q_neurofunk_dnb.scd",    420],
]);
)


// --- PLAYLIST WORLD MUSIC : asia + tribal + cinematic (~50 min) ------
(
~playPlaylist.([
    ["O_asian_cinematic.scd",  600],
    ["K_tribal_ethno.scd",     480],
    ["E_vietnam_hard.scd",     480],
    ["J_ambient_cinematic.scd",720],
]);
)


// --- PLAYLIST RETRO : synthwave + chiptune + house (~30 min) ---------
(
~playPlaylist.([
    ["R_synthwave.scd",        480],
    ["M_chiptune_madness.scd", 360],
    ["G_detroit_soulful.scd",  480],
]);
)


// --- PLAYLIST EXPERIMENTAL : glitch + drone + ambient (~38 min) ------
(
~playPlaylist.([
    ["V_glitch_idm.scd",       480],
    ["S_drone_doom.scd",       900],
    ["C_hypnotic_loop.scd",    600],
]);
)


// --- PLAYLIST SHORT (5 tracks, ~35 min) -------------------------------
(
~playPlaylist.([
    ["A_acid_journey.scd",     420],
    ["F_trance_uplifter.scd",  600],
    ["I_liquid_dnb.scd",       420],
    ["E_vietnam_hard.scd",     480],
    ["W_dub_techno.scd",       600],
]);
)


// --- PLAYLIST DEMO (durees reduites a 90s par track, ~35 min) --------
//   Pour tester rapidement la palette sans attendre 3h
(
~playPlaylist.([
    ["A_acid_journey.scd", 90], ["B_deep_to_hard.scd", 90],
    ["C_hypnotic_loop.scd",90], ["D_wobble_drop.scd", 90],
    ["E_vietnam_hard.scd", 90], ["F_trance_uplifter.scd",90],
    ["G_detroit_soulful.scd",90],["H_acid_trance.scd",90],
    ["I_liquid_dnb.scd", 90],   ["J_ambient_cinematic.scd",90],
    ["K_tribal_ethno.scd",90],  ["L_future_garage.scd",90],
    ["M_chiptune_madness.scd",90],["N_phonk.scd",90],
    ["O_asian_cinematic.scd",90],["P_industrial.scd",90],
    ["Q_neurofunk_dnb.scd",90], ["R_synthwave.scd",90],
    ["S_drone_doom.scd", 90],   ["T_hardcore_gabber.scd",90],
    ["U_vocal_trance.scd",90],  ["V_glitch_idm.scd",90],
    ["W_dub_techno.scd", 90],
]);
)


// --- PLAYLIST RANDOM (toutes les tracks dans un ordre aleatoire) -----
(
~playPlaylist.(
    [
        "A_acid_journey.scd", "B_deep_to_hard.scd", "C_hypnotic_loop.scd",
        "D_wobble_drop.scd", "E_vietnam_hard.scd", "F_trance_uplifter.scd",
        "G_detroit_soulful.scd", "H_acid_trance.scd", "I_liquid_dnb.scd",
        "J_ambient_cinematic.scd", "K_tribal_ethno.scd", "L_future_garage.scd",
        "M_chiptune_madness.scd", "N_phonk.scd", "O_asian_cinematic.scd",
        "P_industrial.scd", "Q_neurofunk_dnb.scd", "R_synthwave.scd",
        "S_drone_doom.scd", "T_hardcore_gabber.scd", "U_vocal_trance.scd",
        "V_glitch_idm.scd", "W_dub_techno.scd"
    ].scramble.collect { |fn|
        var dur = (
            "A_acid_journey": 420, "B_deep_to_hard": 480, "C_hypnotic_loop": 600,
            "D_wobble_drop": 420, "E_vietnam_hard": 480, "F_trance_uplifter": 600,
            "G_detroit_soulful": 480, "H_acid_trance": 480, "I_liquid_dnb": 420,
            "J_ambient_cinematic": 720, "K_tribal_ethno": 480, "L_future_garage": 420,
            "M_chiptune_madness": 360, "N_phonk": 300, "O_asian_cinematic": 600,
            "P_industrial": 480, "Q_neurofunk_dnb": 420, "R_synthwave": 480,
            "S_drone_doom": 900, "T_hardcore_gabber": 360, "U_vocal_trance": 600,
            "V_glitch_idm": 480, "W_dub_techno": 600
        )[fn.replace(".scd","").asSymbol] ?? 420;
        [fn, dur];
    }
);
)



// =====================================================================
//  PLAYLIST CUSTOM -- copier ce template et editer la liste
// =====================================================================
(
~playPlaylist.([
    // [filename, duree_secondes],
    ["F_trance_uplifter.scd",  300],   // 5 min seulement
    ["U_vocal_trance.scd",     300],
    ["H_acid_trance.scd",      300],
]);
)



// =====================================================================
//  CONTROLES PENDANT LA PLAYLIST
// =====================================================================

// --- SKIP TRACK (passe a la suivante immediatement) ------------------
(
~track !? { ~track.stop };
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"[SKIP] passage a la track suivante".postln;
)

// --- PAUSE / RESUME (toggle mute global via master limiter) ---------
( ~masterLim !? { ~masterLim.run(false) }; "[PAUSE]".postln; )
( ~masterLim !? { ~masterLim.run(true)  }; "[RESUME]".postln; )

// --- INFO -- track en cours ------------------------------------------
( ("synths actifs: " ++ s.numSynths ++ " | CPU: " ++ s.avgCPU.round(0.1) ++ "%").postln; )
