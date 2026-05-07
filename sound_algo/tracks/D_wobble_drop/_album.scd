// =====================================================================
//  _album.scd  --  Album D "Wobble Drop" : 15 tracks
// =====================================================================

(  // --- SETUP ALBUM D ---
~albums = ~albums ? ();
~albums[\D] = (
    title: "Wobble Drop",
    folder: "tracks/D_wobble_drop/",
    tracks: [
        \D01_wobble_intro,
        \D02_first_drop,
        \D03_chop_dubstep,
        \D04_riddim_groove,
        \D05_brostep_lead,
        \D06_neuro_wobble,
        \D07_deep_dub,
        \D08_glitch_drop,
        \D09_half_step,
        \D10_tear_out,
        \D11_drumstep,
        \D12_dub_breakdown,
        \D13_chop_glitch,
        \D14_final_drop,
        \D15_wobble_outro,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album D] setup OK".postln;
)
