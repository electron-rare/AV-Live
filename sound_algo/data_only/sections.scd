// sections.scd — Ableton-scene-style section slots
// 8 snapshot slots: armed clips + seq presets + harmony. Save, quantized recall,
// next/prev chaining. Loaded after touchosc_feedback.scd (boot step 6h).
// Additive, nil-guarded, idempotent on reload. Single top-level block.
// Feedback: /scene/state <cur:int> <fill0:int> ... <fill7:int>
(

// -- Env init (nil-guarded; idempotent reload) --
~lp = ~lp ? ();
~lp[\sceneN]   = ~lp[\sceneN]   ? 8;
~lp[\scenes]   = ~lp[\scenes]   ? Array.fill(~lp[\sceneN], nil);
~lp[\sceneCur] = ~lp[\sceneCur] ? -1;
~lp[\armed]    = ~lp[\armed]    ? Set.new;  // guard isolated reload (launchpad sets it too)

// 16 clip symbols (same order as ~toscPatterns) ++ the two sequencers
~scenePatterns = ~scenePatterns ? [
    \kick, \hats,  \clap,  \perc,
    \sub,  \acid,  \arp,   \lead,
    \stab, \pad,   \ride,  \rim,
    \tom,  \reese, \bells, \sweep,
    \melseq, \rhythmseq
];

// -- ~scenePush : push /scene/state to all TouchOSC clients --
~scenePush = ~scenePush ? {
    var fills = ~lp[\scenes].collect({ |s| s.notNil.binaryValue });
    ~toscSend !? { ~toscSend.valueArray(["/scene/state", ~lp[\sceneCur]] ++ fills) };
};

// -- ~sceneSave : snapshot current engine state into slot i --
~sceneSave = ~sceneSave ? { |i|
    (~lp.notNil and: { i >= 0 and: { i < (~lp[\sceneN] ? 8) } }).if({
        ~lp[\scenes][i] = (
            armed:   ~lp[\armed].copy,
            melSel:  ~lp[\melSel],
            rhySel:  ~lp[\rhySel],
            harmony: (~ccHarmony.notNil).if({
                (root:   ~ccHarmony[\root],
                 scale:  ~ccHarmony[\scale],
                 octave: ~ccHarmony[\octave],
                 phrase: ~ccHarmony[\phrase])
            }, { nil })
        );
        ~scenePush.();
    });
};

// -- ~sceneLaunch : diff target armed-set vs current, fire ~lpArm per clip --
// ~lpArm is already quantized: whole section transitions at next bar boundary.
~sceneLaunch = ~sceneLaunch ? { |i|
    var sc = ~lp[\scenes][i];
    sc.notNil.if({
        var target = sc[\armed];
        ~lpArm !? {
            ~scenePatterns.do { |nm|
                var want = target.includes(nm);
                var have = ~lp[\armed].includes(nm);
                (want and: { have.not }).if({ ~lpArm.(nm.asString, true) });
                (want.not and: { have }).if({ ~lpArm.(nm.asString, false) });
            };
        };
        ~lp[\melSel] = sc[\melSel] ? ~lp[\melSel];
        ~lp[\rhySel] = sc[\rhySel] ? ~lp[\rhySel];
        (sc[\harmony].notNil and: { ~ccHarmony.notNil }).if({
            [\root, \scale, \octave, \phrase].do { |k|
                sc[\harmony][k] !? { |v| ~ccHarmony[k] = v };
            };
        });
        ~lp[\sceneCur] = i;
        ~scenePush.();
    });
};

// -- ~sceneFilledIndices : list of non-nil slot indices --
~sceneFilledIndices = ~sceneFilledIndices ? {
    var idxs = [];
    ~lp[\scenes].doWithIndex { |s, i| s.notNil.if({ idxs = idxs.add(i) }) };
    idxs
};

// -- ~sceneNext : advance to next filled slot (wrap-around) --
~sceneNext = ~sceneNext ? {
    var cur   = ~lp[\sceneCur] ? -1;
    var n     = ~lp[\sceneN]   ? 8;
    var found = nil;
    n.do { |offset|
        var idx = (cur + 1 + offset) % n;
        found.isNil.if({
            ~lp[\scenes][idx].notNil.if({ found = idx });
        });
    };
    found.notNil.if({ ~sceneLaunch.(found) });
};

// -- ~scenePrev : retreat to previous filled slot (wrap-around) --
~scenePrev = ~scenePrev ? {
    var cur   = ~lp[\sceneCur] ? -1;
    var n     = ~lp[\sceneN]   ? 8;
    var found = nil;
    n.do { |offset|
        var idx = ((cur - 1 - offset) % n + n) % n;
        found.isNil.if({
            ~lp[\scenes][idx].notNil.if({ found = idx });
        });
    };
    found.notNil.if({ ~sceneLaunch.(found) });
};

// -- ~sceneClear : clear slot i; reset ~sceneCur if it was the active scene --
~sceneClear = ~sceneClear ? { |i|
    (i >= 0 and: { i < (~lp[\sceneN] ? 8) }).if({
        ~lp[\scenes][i] = nil;
        (~lp[\sceneCur] == i).if({ ~lp[\sceneCur] = -1 });
        ~scenePush.();
    });
};

// -- OSCdefs (unique keys with \scene_ prefix; call ~toscTouch for feedback) --
OSCdef(\scene_save, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~sceneSave.(msg[1].asInteger);
}, '/scene/save');

OSCdef(\scene_launch, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~sceneLaunch.(msg[1].asInteger);
}, '/scene/launch');

OSCdef(\scene_next, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~sceneNext.();
}, '/scene/next');

OSCdef(\scene_prev, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~scenePrev.();
}, '/scene/prev');

OSCdef(\scene_clear, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~sceneClear.(msg[1].asInteger);
}, '/scene/clear');

"[sections] ready".postln;
)
