// =====================================================================
//  _album.scd  --  Album C "Hypnotic Loop" : 15 tracks
// =====================================================================

(  // --- SETUP ALBUM C ---
~albums = ~albums ? ();
~albums[\C] = (
    title: "Hypnotic Loop",
    folder: "tracks/C_hypnotic_loop/",
    tracks: [
        \C01_hypno_intro,
        \C02_repeat_one,
        \C03_minimal_pulse,
        \C04_phase_shift,
        \C05_loop_evolve,
        \C06_resonance_walk,
        \C07_acid_drift,
        \C08_modular_groove,
        \C09_repetition_zen,
        \C10_dubby_loop,
        \C11_filter_walk,
        \C12_subtle_chaos,
        \C13_pulse_minimal,
        \C14_morning_loop,
        \C15_loop_dissolve,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album C] setup OK".postln;
)
