// =====================================================================
//  boot.data-only.scd  --  Entry point auto-executable pour le mode
//  "Data-only" du launcher : SC + oF + data_feeds, pas de web UI.
//
//  Sequence :
//    1. Boot du moteur via live/_load.scd (SynthDefs, FX, wrappers)
//    2. Chargement de control/data_feeds.scd (OSCdef /data/*)
//    3. Chargement de live/data_only_program.scd
//    4. Demarrage automatique de la scene \all (cavity + geo + body)
//
//  Usage :
//    sclang /path/to/AV-Live/sound_algo/boot.data-only.scd
//    Le launcher fait ca automatiquement quand mode = .dataOnly.
//
//  Pilotage en cours de jeu (OSC depuis n'importe ou) :
//    /control/dataScene <\\all|\\cavity|\\geo|\\body|\\stop>
// =====================================================================
(
~base = (thisProcess.nowExecutingPath !? { |p| p.dirname ++ "/" })
        ?? { File.getcwd ++ "/" };

("[boot.data-only] ~base = " ++ ~base).postln;

// 1) Engine + palette + setupAll
(~base ++ "live/_load.scd").load;

// 2/3/4) Une fois le bootstrap pret (~setupAll_done == true), on charge
//        data_feeds + le programme et on bascule sur la scene \all.
//        liveSetup est asynchrone (charge palette/scales) donc on poll.
Routine({
    var maxWait = 60, waited = 0;
    while({ (~setupAll_done != true) and: { waited < maxWait } }) {
        0.5.wait; waited = waited + 0.5;
    };
    if(~setupAll_done != true) {
        "[boot.data-only] WARN : setupAll pas pret apres 60s, on tente quand meme".postln;
    };

    "[boot.data-only] loading data_feeds OSCdef...".postln;
    (~base ++ "control/data_feeds.scd").load;
    1.0.wait;

    "[boot.data-only] loading web_bridge OSCdef + sync push...".postln;
    (~base ++ "control/web_bridge.scd").load;
    0.5.wait;

    "[boot.data-only] loading data-only program...".postln;
    (~base ++ "live/data_only_program.scd").load;
    1.5.wait;

    if(~dataScene.isNil) {
        "[boot.data-only] ERREUR : ~dataScene non defini, le programme n'a pas charge.".postln;
    } {
        "[boot.data-only] starting scene \\all".postln;
        ~dataScene.(\all);
    };

    "=== DATA-ONLY READY ===".postln;
    ("    Bridge alive : " ++ ~feedAlive.value).postln;
    "    Scenes : ~dataScene.(\\cavity|\\geo|\\body|\\all|\\stop)".postln;
    "    Remote  : /control/dataScene <name>".postln;
}).play(AppClock);
)
