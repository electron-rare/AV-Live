// =====================================================================
//  pd/bridge.scd  --  Bridge SuperCollider <-> Pure Data via OSC
//
//  Echange OSC bidirectionnel :
//    PD  -> SC : envoie sur localhost:57120 (port standard sclang)
//    SC  -> PD : envoie sur localhost:57121 (port netreceive de bridge.pd)
//
//  PD addresses ecoutees par SC :
//    /play /stop /choke
//    /drop /breakdown /buildup /freeze /glitch
//    /vol/<voie> <0..1>            -- voie : kick hat snare clap perc acid melody harmony
//    /vol/master <0..2>            -- multiplicateur master
//    /tweak/<param> <val>          -- param : melodyCutoff acidCutoff bpm melodyRq acidRq
//    /fx/preset <name>             -- name : dub space trance industrial cosmic dry
//    /fx/send <voie> <fx> <amount> -- ex: /fx/send acid rev 0.4
//    /fx/freeze <0|1>              -- freeze reverb
//    /vcf/on <type> <freq> <q>     -- vcf master
//    /vcf/off
//    /lfo/to <param> <rate> <depth> <shape> <center>
//    /lfo/stop <param>
//    /scene/save <name>
//    /scene/load <name>
//    /jump <track> <slug>          -- ex: /jump A acid_rave_kick_t1_melody_lead_variations
//    /melody <name>                -- ex: /melody m50
//    /melody/genre <genre>         -- ex: /melody/genre acid
//    /preset <mix>                 -- ex: /preset drumsHeavy
//    /kit <name>                   -- ex: /kit kitTechno
//
//  USAGE :
//    1. Lance PD : ouvre pd/bridge.pd
//    2. Cote SC : Cmd+Entree sur le bloc SETUP ci-dessous
//    3. Test : clique sur PLAY dans le patch PD -- tu dois entendre le beat
//    4. Pour stopper le bridge : ~pdDisconnect.()
// =====================================================================


// --- SETUP -- enregistre les OSCdef cote SC -------------------------
(
~pd = ~pd ?? { () };
~pd[\target] = NetAddr("127.0.0.1", 57121);   // port netreceive du patch PD
~pd[\defs] = ~pd[\defs] ?? { List.new };

// Helpers d'envoi vers PD
~pdSend = { |addr ...args| ~pd[\target].sendMsg(addr, *args) };

// Liberer les anciennes OSCdef
~pd[\defs].do { |d| d.free }; ~pd[\defs] = List.new;

// --- transport -----------------------------------------------------
~pd[\defs].add(OSCdef(\pdPlay, {
    TempoClock.default.tempo = (~bpm ? 128) / 60;
    ~reload !? { ~reload.value };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    "[PD] PLAY".postln;
}, '/play'));

~pd[\defs].add(OSCdef(\pdStop, {
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[PD] STOP".postln;
}, '/stop'));

~pd[\defs].add(OSCdef(\pdChoke, {
    ~track !? { ~track.stop; ~track = nil };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[PD] CHOKE".postln;
}, '/choke'));

// --- tricks live ---------------------------------------------------
~pd[\defs].add(OSCdef(\pdDrop,      { ~drop      !? { ~drop.()      } }, '/drop'));
~pd[\defs].add(OSCdef(\pdBreakdown, { ~breakdown !? { ~breakdown.(8) } }, '/breakdown'));
~pd[\defs].add(OSCdef(\pdBuildup,   { ~buildup   !? { ~buildup.(8)   } }, '/buildup'));
~pd[\defs].add(OSCdef(\pdFreeze,    { ~freeze    !? { ~freeze.(4)    } }, '/freeze'));
~pd[\defs].add(OSCdef(\pdGlitch,    { ~glitch    !? { ~glitch.(2)    } }, '/glitch'));
~pd[\defs].add(OSCdef(\pdStutter,   { |msg| ~stutter !? { ~stutter.(msg[1] ? 8, msg[2] ? 1) } }, '/stutter'));
~pd[\defs].add(OSCdef(\pdTapeStop,  { ~tapeStop    !? { ~tapeStop.(2)    } }, '/tapeStop'));
~pd[\defs].add(OSCdef(\pdHandsUp,   { ~handsUp     !? { ~handsUp.()      } }, '/handsUp'));
~pd[\defs].add(OSCdef(\pdJumpCut,   { |msg| ~jumpCut !? { ~jumpCut.(msg[1] ? 0.5) } }, '/jumpCut'));
~pd[\defs].add(OSCdef(\pdTapeRev,   { ~tapeReverse !? { ~tapeReverse.(4) } }, '/tapeReverse'));
~pd[\defs].add(OSCdef(\pdPanic,     {
    ~track !? { ~track.stop; ~track = nil };
    ~teardown !? { ~teardown.() };
    "[PD] PANIC -- teardown lance".postln;
}, '/panic'));

// --- volumes (mixer) -----------------------------------------------
~pd[\defs].add(OSCdef(\pdVolKick,    { |msg| ~setVol !? { ~setVol.(\kick,    msg[1]) } }, '/vol/kick'));
~pd[\defs].add(OSCdef(\pdVolHat,     { |msg| ~setVol !? { ~setVol.(\hat,     msg[1]) } }, '/vol/hat'));
~pd[\defs].add(OSCdef(\pdVolSnare,   { |msg| ~setVol !? { ~setVol.(\snare,   msg[1]) } }, '/vol/snare'));
~pd[\defs].add(OSCdef(\pdVolClap,    { |msg| ~setVol !? { ~setVol.(\clap,    msg[1]) } }, '/vol/clap'));
~pd[\defs].add(OSCdef(\pdVolPerc,    { |msg| ~setVol !? { ~setVol.(\perc,    msg[1]) } }, '/vol/perc'));
~pd[\defs].add(OSCdef(\pdVolAcid,    { |msg| ~setVol !? { ~setVol.(\acid,    msg[1]) } }, '/vol/acid'));
~pd[\defs].add(OSCdef(\pdVolMelody,  { |msg| ~setVol !? { ~setVol.(\melody,  msg[1]) } }, '/vol/melody'));
~pd[\defs].add(OSCdef(\pdVolHarmony, { |msg| ~setVol !? { ~setVol.(\harmony, msg[1]) } }, '/vol/harmony'));
~pd[\defs].add(OSCdef(\pdVolMaster,  { |msg| ~masterVol !? { ~masterVol.(msg[1]) } }, '/vol/master'));

// --- tweaks parametriques ------------------------------------------
~pd[\defs].add(OSCdef(\pdTweakMelCut, { |msg| ~melodyCutoff = msg[1].asFloat; ~reload.value }, '/tweak/melodyCutoff'));
~pd[\defs].add(OSCdef(\pdTweakAcidCut,{ |msg| ~acidCutoff   = msg[1].asFloat; ~reload.value }, '/tweak/acidCutoff'));
~pd[\defs].add(OSCdef(\pdTweakBpm,    { |msg| ~bpm = msg[1].asFloat; TempoClock.default.tempo = ~bpm/60 }, '/tweak/bpm'));
~pd[\defs].add(OSCdef(\pdTweakMelRq,  { |msg| ~melodyRq = msg[1].asFloat; ~reload.value }, '/tweak/melodyRq'));
~pd[\defs].add(OSCdef(\pdTweakAcidRq, { |msg| ~acidRq   = msg[1].asFloat; ~reload.value }, '/tweak/acidRq'));
~pd[\defs].add(OSCdef(\pdTweakDrive,  { |msg| ~melodyDrive = msg[1].asFloat; ~reload.value }, '/tweak/melodyDrive'));

// --- FX bus --------------------------------------------------------
~pd[\defs].add(OSCdef(\pdFxPreset, { |msg|
    ~fxPreset !? { ~fxPreset.(msg[1].asSymbol) };
    ("[PD] fxPreset " ++ msg[1]).postln;
}, '/fx/preset'));

~pd[\defs].add(OSCdef(\pdFxSend, { |msg|
    ~send !? { ~send.(msg[1].asSymbol, msg[2].asSymbol, msg[3].asFloat) };
}, '/fx/send'));

~pd[\defs].add(OSCdef(\pdFxFreeze, { |msg|
    ~setFx !? { ~setFx.(\rev, \freeze, msg[1].asInteger) };
}, '/fx/freeze'));

// /fx/setMix <fxname:reverb|delay|chorus|shimmer|...> <0..1>
~pd[\defs].add(OSCdef(\pdFxSetMix, { |msg|
    var name = msg[1].asSymbol;
    var key = (name: \rev, reverb: \rev, delay: \dly, dly: \dly,
               chorus: \chr, chr: \chr, phaser: \phs, phs: \phs,
               flanger: \flg, flg: \flg, bitcrush: \crsh, crsh: \crsh,
               tape: \tape, shimmer: \shim, shim: \shim, dist: \dist)[name] ? name;
    ~setFx !? { ~setFx.(key, \mix, msg[2].asFloat) };
}, '/fx/setMix'));

// --- VCF master ----------------------------------------------------
~pd[\defs].add(OSCdef(\pdVcfOn, { |msg|
    ~vcfOn !? { ~vcfOn.(msg[1].asSymbol, msg[2].asFloat, msg[3].asFloat) };
}, '/vcf/on'));

~pd[\defs].add(OSCdef(\pdVcfOff, { ~vcfOff !? { ~vcfOff.() } }, '/vcf/off'));
~pd[\defs].add(OSCdef(\pdVcfFreq, { |msg| ~vcfSet !? { ~vcfSet.(\freq, msg[1].asFloat) } }, '/vcf/setFreq'));
~pd[\defs].add(OSCdef(\pdVcfQ,    { |msg| ~vcfSet !? { ~vcfSet.(\q,    msg[1].asFloat) } }, '/vcf/setQ'));

// --- LFO -----------------------------------------------------------
~pd[\defs].add(OSCdef(\pdLfoTo, { |msg|
    ~lfoTo !? { ~lfoTo.(msg[1].asSymbol, msg[2].asFloat, msg[3].asFloat,
                        msg[4].asSymbol, msg[5].asFloat) };
}, '/lfo/to'));

~pd[\defs].add(OSCdef(\pdLfoStop, { |msg|
    ~lfoStopVar !? { ~lfoStopVar.(msg[1].asSymbol) };
}, '/lfo/stop'));

// --- Scenes / jump / mélodies / kits / presets ---------------------
~pd[\defs].add(OSCdef(\pdSceneSave, { |msg|
    ~saveScene !? { ~saveScene.(msg[1].asSymbol) };
}, '/scene/save'));

~pd[\defs].add(OSCdef(\pdSceneLoad, { |msg|
    ~loadScene !? { ~loadScene.(msg[1].asSymbol) };
}, '/scene/load'));

~pd[\defs].add(OSCdef(\pdJump, { |msg|
    ~jumpTo !? { ~jumpTo.(msg[1].asSymbol, msg[2].asSymbol) };
}, '/jump'));

~pd[\defs].add(OSCdef(\pdMelody, { |msg|
    ~useMelody !? { ~useMelody.(msg[1].asSymbol) };
}, '/melody'));

~pd[\defs].add(OSCdef(\pdMelodyGenre, { |msg|
    ~melodyByGenre !? { ~melodyByGenre.(msg[1].asSymbol) };
}, '/melody/genre'));

~pd[\defs].add(OSCdef(\pdMixPreset, { |msg|
    ~mixPreset !? { ~mixPreset.(msg[1].asSymbol) };
}, '/preset'));

// --- Boucle de status (envoi periodique vers PD) -------------------
~pd[\statusLoop] !? { ~pd[\statusLoop].stop };
~pd[\statusLoop] = Routine({
    loop {
        ~pdSend.('/sc/status', 1);
        ~pdSend.('/sc/cpu',     s.avgCPU.round(0.1));
        ~pdSend.('/sc/synths',  s.numSynths);
        1.wait;
    };
}).play;

"=== PD bridge ACTIF (SC<-OSC->PD) ===".postln;
"   PD -> SC : 57120 (sclang OSC default)".postln;
"   SC -> PD : 57121 (bridge.pd udpreceive)".postln;
"   stoppe avec  ~pdDisconnect.()".postln;
)


// --- DECONNECT (libere tous les OSCdef + status loop) ---------------
(
~pdDisconnect = {
    ~pd !? {
        ~pd[\statusLoop] !? { ~pd[\statusLoop].stop; ~pd[\statusLoop] = nil };
        ~pd[\defs] !? { ~pd[\defs].do { |d| d.free }; ~pd[\defs] = List.new };
    };
    "=== PD bridge STOP ===".postln;
};
~pdDisconnect.();
)


// =====================================================================
//  Tests rapides (Cmd+Entree pour envoyer un message vers PD)
// =====================================================================

// --- Test : envoyer un message a PD --------------------------------
( ~pdSend.('/sc/hello', "ping"); )

// --- Test : envoi du tempo courant a PD ----------------------------
( ~pdSend.('/sc/bpm', ~bpm ? 128); )
