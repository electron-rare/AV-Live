// =====================================================================
//  data_only/boot.scd  --  Entry point COMPLET du patch data-only.
//
//  Tout-en-un, autonome, AUCUNE dependance vers live/_load.scd ni vers
//  la palette de SynthDefs du systeme live principal :
//
//    1. Demarre oscope-of si pas deja en cours d'execution (best-effort)
//    2. Boot scsynth (Server.local)
//    3. Charge engine.scd          (FX rack : reverb + comp + limiter)
//    4. Charge synthdefs.scd       (10 SynthDefs \\do_*)
//    5. Charge control/data_feeds.scd  (OSCdef /data/* + ~feeds)
//    6. Charge scenes.scd          (9 scenes + selecteur ~doScene)
//    7. Lance la scene \\play (body-play ; \\all et data-web via /control/doScene)
//
//  Usage standalone :
//    sclang /chemin/AV-Live/sound_algo/data_only/boot.scd
//
//  Le launcher en mode Data-only utilise ce fichier automatiquement
//  (cf. ProcessManager.swift, branche mode == .dataOnly).
// =====================================================================
(
~base = (thisProcess.nowExecutingPath !? { |p| p.dirname ++ "/" })
        ?? { File.getcwd ++ "/" };
~repoRoot = ~base ++ "../";   // sound_algo/

("[data-only/boot] ~base = " ++ ~base).postln;
("[data-only/boot] ~repoRoot = " ++ ~repoRoot).postln;

// -- 1a) Demarre le visualizer Python+Metal (data_only_viz) si absent.
//        Remplace oscope-of dans le patch data-only.
{
    var pgrep = "pgrep -f 'data_only_viz' >/dev/null 2>&1".systemCmd;
    if(pgrep != 0) {
        var vizDir = ~repoRoot ++ "../data_only_viz";
        var uvCandidates = [
            "/opt/homebrew/bin/uv", "/usr/local/bin/uv",
            "~/.local/bin/uv".standardizePath,
        ];
        var uv = uvCandidates.detect { |p| File.exists(p) };
        if(uv.notNil and: { File.exists(vizDir ++ "/main.py") }) {
            // --project pointe uv sur le pyproject.toml de data_only_viz/,
            // cwd reste au parent pour resoudre `-m data_only_viz.main`.
            var cmd = "cd '" ++ vizDir ++ "/..' && '" ++ uv ++ "' --project '"
                    ++ vizDir ++ "' run python -m data_only_viz.main"
                    ++ " >/tmp/avlive-metal_viz.log 2>&1 &";
            ("[data-only/boot] launching Python+Metal visualizer").postln;
            ("                 logs: tail -f /tmp/avlive-metal_viz.log").postln;
            cmd.unixCmd;
        } {
            "[data-only/boot] data_only_viz/main.py NOT launched (uv ou main.py manquant)".warn;
            ("                 expected: " ++ vizDir).warn;
        };
    } {
        "[data-only/boot] metal viz already running".postln;
    };
}.value;

// -- 1b) Demarre le pont Python data_feeds (scraping opendata) si
//        absent. Sans ce pont, ~feeds reste vide et les scenes sont
//        muettes/statiques. Le launcher fait deja ca quand il pilote
//        l'app, mais on couvre le cas standalone (sclang boot.scd).
{
    var pgrep = "pgrep -f 'data_feeds/bridge.py' >/dev/null 2>&1".systemCmd;
    if(pgrep != 0) {
        var dfDir = ~repoRoot ++ "../data_feeds";
        // Detecte uv (apple silicon brew prioritaire)
        var uvCandidates = [
            "/opt/homebrew/bin/uv", "/usr/local/bin/uv",
            "~/.local/bin/uv".standardizePath,
        ];
        var uv = uvCandidates.detect { |p| File.exists(p) };
        if(uv.notNil and: { File.exists(dfDir ++ "/bridge.py") }) {
            // Selectionne config.data-only.toml si present
            var cfg = if(File.exists(dfDir ++ "/config.data-only.toml")) {
                " -c config.data-only.toml"
            } { "" };
            var cmd = "cd '" ++ dfDir ++ "' && '" ++ uv ++ "' run python bridge.py"
                    ++ cfg ++ " >/tmp/avlive-data_feeds.log 2>&1 &";
            ("[data-only/boot] launching data_feeds bridge...").postln;
            ("                 logs: tail -f /tmp/avlive-data_feeds.log").postln;
            cmd.unixCmd;
        } {
            "[data-only/boot] data_feeds bridge NOT launched (uv ou bridge.py manquant)".warn;
            ("                 expected dir: " ++ dfDir).warn;
        };
    } {
        "[data-only/boot] data_feeds bridge already running".postln;
    };
}.value;

// -- 2) Boot scsynth + chargement asynchrone -------------------------
Routine({
    var maxWait, waited;

    // Ouvre le port 57121 pour recevoir /control/* (launcher), /pose/* et
    // /data/* (data_only_viz + data_feeds bridge). Si le port est pris,
    // c'est presque toujours un holder zombie : un scsynth/bridge orphelin
    // d'un sclang precedent qui a herite le socket 57121 via unixCmd et a
    // survecu a son parent. On le libere et on reessaie, plutot que de
    // fallback silencieusement (les /pose/data n'arriveraient jamais sur le
    // langPort de repli).
    if(thisProcess.openUDPPort(57121).not) {
        "[data-only/boot] 57121 occupe — liberation du holder zombie...".postln;
        "lsof -ti UDP:57121 | xargs kill -9 2>/dev/null".unixCmd;
        0.5.wait;
        if(thisProcess.openUDPPort(57121).not) {
            ("[data-only/boot] WARN: 57121 toujours occupe, fallback sur langPort = "
             ++ NetAddr.langPort).postln;
        } {
            ("[data-only/boot] 57121 recupere — sclang listening on "
             ++ NetAddr.langPort ++ " + 57121").postln;
        };
    } {
        ("[data-only/boot] sclang listening on " ++ NetAddr.langPort ++ " + 57121").postln;
    };

    // Boot le serveur (idempotent : si deja boot, retourne immediatement)
    Server.local.options.numOutputBusChannels = 2;
    // Output-only patch: don't open an input device. Avoids the mic TCC
    // prompt and "AudioDeviceStart failed" when the default input is
    // unavailable (e.g. an iPhone Continuity mic in the device list).
    Server.local.options.numInputBusChannels = 0;
    Server.local.options.memSize = 65536;

    "[data-only/boot] booting scsynth...".postln;
    s.bootSync;

    // -- 3) Engine (FX rack) -----
    (~base ++ "engine.scd").load;
    maxWait = 10; waited = 0;
    while({ ~doEngineReady != true and: { waited < maxWait } }) {
        0.2.wait; waited = waited + 0.2;
    };
    if(~doEngineReady != true) {
        "[data-only/boot] WARN: engine pas pret apres 10s".warn;
    };

    // -- 4) SynthDefs -----
    (~base ++ "synthdefs.scd").load;
    s.sync;
    0.5.wait;

    // -- 4b. Body-play SynthDefs -----
    (~base ++ "synthdefs_play.scd").load;
    s.sync;

    // -- 5) OSCdef des flux data_feeds -----
    (~repoRoot ++ "control/data_feeds.scd").load;
    0.5.wait;

    // -- 6) Bibliotheque de scenes -----
    (~base ++ "scenes.scd").load;
    0.5.wait;

    // -- 6b. Pose/mains -> mapping FX -----
    (~base ++ "scene_pose_action.scd").load;
    0.5.wait;

    // -- 6c. Body-play engine -----
    (~base ++ "scene_pose_play.scd").load;
    0.5.wait;

    // -- 6d. Concert engine + morceaux -----
    (~base ++ "scene_concert.scd").load;
    0.3.wait;
    [
        "morceaux/01_hypno_drift.scd",
        "morceaux/02_hypno_roll.scd",
        "morceaux/03_acid_line.scd",
        "morceaux/04_acid_storm.scd",
        "morceaux/05_hard_pump.scd",
        "morceaux/06_hard_rave.scd",
    ].do { |f| (~base ++ f).load; 0.1.wait; };
    s.sync;

    // -- 7) Demarre la scene par defaut -----
    if(~doScene.isNil) {
        "[data-only/boot] ERREUR : ~doScene non defini".warn;
    } {
        "[data-only/boot] starting scene \\play (body-play)".postln;
        ~doScene.(\play);
    };

    "".postln;
    "===========================================".postln;
    "      AV-Live DATA-ONLY PATCH READY".postln;
    "===========================================".postln;
    ("  bridge alive : " ++ ~feedAlive.value).postln;
    "  scenes       : ~doScene.(\\name)".postln;
    "  available    : \\cavity \\geo \\body \\weather".postln;
    "                 \\flight \\pulse \\quiet \\all \\full \\stop".postln;
    "  OSC remote   : /control/doScene <\\name>".postln;
    "  master gain  : /control/doMaster <0..2>".postln;
    "===========================================".postln;
}).play(AppClock);
)
