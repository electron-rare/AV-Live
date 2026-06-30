// Headless validator: load all generated .matrix presets via the engine.
// Run: /Applications/SuperCollider.app/Contents/MacOS/sclang \
//        sound_algo/data_only/matrix_presets/validate_presets.scd
// Expected output: VALIDATE PASS  (no ERROR lines, 84 presets loaded OK)
// Also asserts techno_drive carries non-empty voiceMods + voicePoses.
(
var featureFile = PathName(thisProcess.nowExecutingPath).pathOnly ++ "../matrix.scd";
var pass  = true;
var nOK   = 0;
var nFail = 0;
var names;

// Minimal stub environment (mirrors test_matrix.scd setup)
~lp       = (clock: TempoClock.default);
~toscSend  = { |path ...args| };
~toscTouch = { |addr| };

// Dummy Pdefs so matrix.scd initialises without missing references
["kick","hats","clap","perc","sub","acid","arp","lead",
 "stab","pad","ride","rim","tom","reese","bells","sweep",
 "melody","chord","fx","snare","crash","shaker"].do { |v|
    Pdef(("lp_" ++ v).asSymbol, Pbind(\instrument, v.asSymbol, \dur, 1))
};

featureFile.load;

// -- 1. Load every preset, assert each returns true --
names = ~matNames.(~matPresetDir);
("found " ++ names.size ++ " presets in " ++ ~matPresetDir).postln;

names.do { |name|
    var path = ~matPresetDir +/+ (name.asString ++ ".matrix");
    var ok;
    try {
        ok = ~matLoadFile.(path)
    } { |e|
        ok = false;
        ("EXCEPTION loading " ++ name ++ ": " ++ e.class.name).postln
    };
    ok.if(
        { nOK = nOK + 1 },
        {
            nFail = nFail + 1;
            pass = false;
            ("FAIL load: " ++ name).postln
        }
    )
};

(nOK == 84).not.if({
    pass = false;
    ("FAIL count: expected 84, got " ++ nOK ++ " OK, " ++ nFail ++ " failed").postln
}, {
    ("OK: " ++ nOK ++ "/84 presets loaded").postln
});

// -- 2. Load peak_drop and assert new role-adapted default mappings --
//    acid (lead role) → 4 hand bindings incl. \pitch
//    kick (drums role) → 2 body bindings, first source = \bodyVitesse
//    fx   (fx role)   → danse→gate pose binding
{
    var path = ~matPresetDir +/+ "peak_drop_live.matrix";
    var vpass;
    ~matVoices.do { |v| ~matVoiceMods[v] = []; ~matVoicePoses[v] = [] };
    try {
        ~matLoadFile.(path)
    } { |e|
        pass = false;
        ("EXCEPTION reloading peak_drop: " ++ e.class.name).postln
    };
    // acid (vi=5, lead role): 4 hand bindings, one targets \pitch
    vpass = (~matVoiceMods[\acid].notNil and: { ~matVoiceMods[\acid].size == 4 })
        and: { ~matVoiceMods[\acid].any({ |b| b[\target] == \pitch }) };
    vpass.not.if({
        pass = false;
        ("FAIL peak_drop acid voiceMods (expected 4 w/ pitch): "
            ++ ~matVoiceMods[\acid]).postln
    });
    // kick (vi=0, drums role): 2 body bindings, first source = \bodyVitesse
    vpass = vpass
        and: { (~matVoiceMods[\kick].notNil and: { ~matVoiceMods[\kick].size == 2 })
            and: { ~matVoiceMods[\kick][0][\source] == \bodyVitesse } };
    vpass.not.if({
        pass = false;
        ("FAIL peak_drop kick voiceMods (expected 2, src=bodyVitesse): "
            ++ ~matVoiceMods[\kick]).postln
    });
    // fx (vi=18): pose->voice triggers are opt-in now -> no default binding
    vpass = vpass and: { (~matVoicePoses[\fx] ? []).size == 0 };
    vpass.not.if({
        pass = false;
        ("FAIL peak_drop fx voicePoses (expected empty): "
            ++ ~matVoicePoses[\fx]).postln
    });
    vpass.if({ "DEFAULTS PASS".postln }, { "DEFAULTS FAIL".postln })
}.value;

pass.if(
    { "VALIDATE PASS".postln },
    { "VALIDATE FAIL".postln }
);
0.exit;
)
