// =====================================================================
//  data_feeds.scd  --  Reception OSC des flux temps reel externes.
//
//  Lance le pont :  cd data_feeds && uv run python bridge.py
//
//  Architecture :
//    Python (USGS, SWPC, Netzfrequenz, Blitzortung, OpenSky, Bluesky, ...)
//        \--OSC--> 57121 (sclang)  ET 57123 (oF)
//
//  Toutes les valeurs sont stockees dans ~feeds (IdentityDictionary).
//  Lire :  ~feeds[\netz_freq] ?? 50.0
//  Mapper:~feeds[\netz_dev].linlin(-0.2, 0.2, -100, 100)
//
//  Les definitions sont idempotentes : on peut relire le fichier sans
//  accumuler des OSCdef fantomes.
// =====================================================================
(
~feeds = ~feeds ? IdentityDictionary.new;
~feeds[\__t0] = SystemClock.seconds;

// ---- helper de pose : ferme + recree -----------------------------
~feedDefPriv = { |key, path, fn|
    OSCdef(key).free;
    OSCdef(key, fn, path);
};

// ---- bus de notification : permet aux abonnes (synths, patterns,
//      visus) de reagir a un changement specifique.
//      ~feedSub.(\netz_freq, { |val| ... }) renvoie une cle de retrait.
~feedListeners = ~feedListeners ? IdentityDictionary.new;
~feedSub = { |key, action|
    var arr = ~feedListeners[key] ? Array.new;
    ~feedListeners[key] = arr.add(action);
    action;
};
~feedUnsub = { |key, action|
    var arr = ~feedListeners[key];
    if(arr.notNil) { ~feedListeners[key] = arr.reject(_ == action) };
};
~feedNotifyPriv = { |key, val|
    (~feedListeners[key] ? #[]).do { |fn| fn.value(val) };
};
~feedSet = { |key, val| ~feeds[key] = val; ~feedNotifyPriv.(key, val) };

// =====================================================================
//  USGS  -- seismicite
// =====================================================================
// /data/usgs/event <mag> <lon> <lat> <depth> <age_sec>
~feedDefPriv.(\d_usgs_event, '/data/usgs/event', { |msg|
    var mag = msg[1], lon = msg[2], lat = msg[3], depth = msg[4], age = msg[5];
    ~feedSet.(\usgs_last_mag, mag);
    ~feedSet.(\usgs_last_pos, [lon, lat]);
    ~feedSet.(\usgs_last_age, age);
    ~feedSet.(\usgs_last_depth, depth);
});
~feedDefPriv.(\d_usgs_rate, '/data/usgs/rate', { |msg|
    ~feedSet.(\usgs_rate_h, msg[1]);
});

// =====================================================================
//  SWPC  -- vent solaire, IMF, Kp, X-ray
// =====================================================================
// /data/swpc/wind  <speed_kms> <density_pcm3> <temp_K>
~feedDefPriv.(\d_swpc_wind, '/data/swpc/wind', { |msg|
    ~feedSet.(\swpc_wind_speed, msg[1]);
    ~feedSet.(\swpc_wind_dens,  msg[2]);
    ~feedSet.(\swpc_wind_temp,  msg[3]);
});
~feedDefPriv.(\d_swpc_bz, '/data/swpc/bz', { |msg|
    ~feedSet.(\swpc_bz, msg[1]);
    ~feedSet.(\swpc_bt, msg[2]);
});
~feedDefPriv.(\d_swpc_kp, '/data/swpc/kp', { |msg|
    ~feedSet.(\swpc_kp, msg[1]);
    ~feedSet.(\swpc_a,  msg[2]);
});
~feedDefPriv.(\d_swpc_xray, '/data/swpc/xray', { |msg|
    ~feedSet.(\swpc_xray_short, msg[1]);
    ~feedSet.(\swpc_xray_long,  msg[2]);
    ~feedSet.(\swpc_flare_norm, msg[3]);  // 0..1 (A->X)
});

// =====================================================================
//  GRID  -- frequence du reseau 50 Hz
// =====================================================================
// /data/netzfrequenz/freq <hz>
~feedDefPriv.(\d_grid_freq, '/data/netzfrequenz/freq', { |msg|
    ~feedSet.(\netz_freq, msg[1]);
});
~feedDefPriv.(\d_grid_dev, '/data/netzfrequenz/dev', { |msg|
    ~feedSet.(\netz_dev, msg[1]);
});
~feedDefPriv.(\d_grid_tdev, '/data/netzfrequenz/time_dev', { |msg|
    ~feedSet.(\netz_time_dev, msg[1]);
});

// =====================================================================
//  RTE eCO2mix  -- mix electrique France (MW par filiere)
// =====================================================================
~feedDefPriv.(\d_rte_mix, '/data/rte_eco2mix/mix', { |msg|
    var keys = [\nuclear, \gas, \coal, \oil, \hydro, \wind, \solar, \bio];
    var total = 0.0;
    keys.do { |k, i| var v = msg[i+1] ? 0.0; ~feeds[(\rte_ ++ k).asSymbol] = v; total = total + v };
    ~feedSet.(\rte_total, total);
    // parts renouvelables et carbone tres simple
    ~feedSet.(\rte_renew_pct,
        if(total > 0) {
            (~feeds[\rte_hydro] + ~feeds[\rte_wind] + ~feeds[\rte_solar] + ~feeds[\rte_bio]) / total
        } { 0.0 }
    );
});

// =====================================================================
//  BLITZORTUNG  -- impacts de foudre
// =====================================================================
~feedDefPriv.(\d_lightning_strike, '/data/blitzortung/strike', { |msg|
    var lat = msg[1], lon = msg[2], age = msg[3], mult = msg[4];
    ~feedSet.(\lightning_last, [lat, lon, age, mult]);
});
~feedDefPriv.(\d_lightning_rate, '/data/blitzortung/rate', { |msg|
    ~feedSet.(\lightning_rate_min, msg[1]);
});

// =====================================================================
//  OPENSKY  -- ADS-B
// =====================================================================
~feedDefPriv.(\d_aviation_count, '/data/opensky/count', { |msg|
    ~feedSet.(\aviation_count, msg[1]);
});
~feedDefPriv.(\d_aviation_plane, '/data/opensky/plane', { |msg|
    var icao = msg[1], lon = msg[2], lat = msg[3], alt = msg[4], vel = msg[5], head = msg[6];
    ~feedSet.(\aviation_last, [icao, lon, lat, alt, vel, head]);
});

// =====================================================================
//  BLUESKY JETSTREAM  -- pouls social
// =====================================================================
~feedDefPriv.(\d_social_post, '/data/bluesky/post', { |msg|
    ~feedSet.(\social_last_len, msg[1]);
    ~feedSet.(\social_last_lang, msg[2]);
});
~feedDefPriv.(\d_social_rate, '/data/bluesky/rate', { |msg|
    ~feedSet.(\social_rate_s, msg[1]);
});

// =====================================================================
//  MEMPOOL  -- Bitcoin
// =====================================================================
~feedDefPriv.(\d_btc_tx, '/data/mempool/tx', { |msg|
    ~feedSet.(\btc_last_val, msg[1]);
    ~feedSet.(\btc_last_fee, msg[2]);
});
~feedDefPriv.(\d_btc_block, '/data/mempool/block', { |msg|
    ~feedSet.(\btc_height, msg[1]);
    ~feedSet.(\btc_block_tx, msg[2]);
    ~feedSet.(\btc_block_reward, msg[3]);
});

// =====================================================================
//  GITHUB
// =====================================================================
~feedDefPriv.(\d_gh_event, '/data/github/event', { |msg|
    ~feedSet.(\gh_last_type, msg[1]);
    ~feedSet.(\gh_last_repo, msg[2]);
});

// =====================================================================
//  GCN  -- alertes astrophysiques (rares)
// =====================================================================
~feedDefPriv.(\d_gcn_alert, '/data/gcn/alert', { |msg|
    ~feedSet.(\gcn_last,
        [msg[1], msg[2], msg[3], msg[4]]  // [mission_hash, ra, dec, err_arcmin]
    );
    "*** GCN alert ***".postln; msg.postln;
});

// =====================================================================
//  POSE  -- webcam + YOLOv8-pose (17 keypoints COCO)
// =====================================================================
// Layout COCO :
//   0 nose, 1/2 eyes L/R, 3/4 ears L/R,
//   5/6 shoulders L/R, 7/8 elbows L/R, 9/10 wrists L/R,
//   11/12 hips L/R, 13/14 knees L/R, 15/16 ankles L/R
~poseKpNames = [\nose, \eye_l, \eye_r, \ear_l, \ear_r,
    \sho_l, \sho_r, \elb_l, \elb_r, \wri_l, \wri_r,
    \hip_l, \hip_r, \kne_l, \kne_r, \ank_l, \ank_r];

// NOTE: /data/pose/count and /data/pose/skel are ALSO consumed by
// data_only_viz/osc_listener.py for Metal rendering. This is intentional —
// both subsystems update their own state. Do NOT consolidate; they live
// in different processes.
~feedDefPriv.(\d_pose_count, '/data/pose/count', { |msg|
    ~feedSet.(\pose_count, msg[1]);
});
~feedDefPriv.(\d_pose_person, '/data/pose/person', { |msg|
    var idx = msg[1].asInteger;
    var persons = ~feeds[\pose_persons] ? IdentityDictionary.new;
    persons[idx] = (cx: msg[2], cy: msg[3], w: msg[4], h: msg[5], conf: msg[6]);
    ~feedSet.(\pose_persons, persons);
});
~feedDefPriv.(\d_pose_skel, '/data/pose/skel', { |msg|
    // SC : toutes les `var` doivent etre en debut de block, AVANT
    // tout statement (ici, avant le 17.do qui suivait).
    var idx = msg[1].asInteger;
    var avg = msg[2];
    var flat = msg.copyRange(3, msg.size - 1);  // [x0,y0,c0, ..., x16,y16,c16]
    var skel = Array.new(17);
    var all = ~feeds[\pose_skels] ? IdentityDictionary.new;
    17.do { |k|
        var off = k * 3;
        skel = skel.add((
            x: flat[off],
            y: flat[off + 1],
            c: flat[off + 2],
            name: ~poseKpNames[k]
        ));
    };
    all[idx] = (avg: avg, kp: skel);
    ~feedSet.(\pose_skels, all);
    // raccourci : premier sujet
    if(idx == 0) { ~feedSet.(\pose_skel0, skel) };
});
~feedDefPriv.(\d_pose_bone, '/data/pose/bone', { |msg|
    // Annonce du squelette a la connexion. On stocke la liste des paires.
    var bones = ~feeds[\pose_bones] ? Array.new;
    var pair = [msg[1].asInteger, msg[2].asInteger];
    if(bones.indexOfEqual(pair).isNil) {
        ~feedSet.(\pose_bones, bones.add(pair));
    };
});

// =====================================================================
//  POSE LIVE (pont sonore depuis data_only_viz, route /pose/*)
//  Distinct des /data/pose/* (bridge data_feeds) — ce sont des messages
//  HAUTE FREQUENCE (30 Hz) emis directement par le worker pose IA.
// =====================================================================
~feedDefPriv.(\d_pose_live_count, '/pose/count', { |msg|
    ~feedSet.(\pose_count, msg[1]);
});
~feedDefPriv.(\d_pose_live_center, '/pose/center', { |msg|
    ~feedSet.(\pose_center, [msg[1].asInteger, msg[2], msg[3]]);
});
~feedDefPriv.(\d_pose_live_head, '/pose/head', { |msg|
    // pid, x, y, conf
    ~feedSet.(\pose_head, [msg[1].asInteger, msg[2], msg[3], msg[4]]);
});
~feedDefPriv.(\d_pose_live_wrist, '/pose/wrist', { |msg|
    // pid, side(\l|\r), x, y
    var pid = msg[1].asInteger;
    var side = msg[2].asString;
    var key = if(side == "l") { \pose_wrist_l } { \pose_wrist_r };
    ~feedSet.(key, [pid, msg[3], msg[4]]);
});
~feedDefPriv.(\d_pose_live_sho, '/pose/sho_span', { |msg|
    ~feedSet.(\pose_sho_span, [msg[1].asInteger, msg[2]]);
});
~feedDefPriv.(\d_pose_live_span, '/pose/limb_span', { |msg|
    ~feedSet.(\pose_limb_span, [msg[1].asInteger, msg[2]]);
});

// Helper : lit le keypoint `name` du sujet 0. Renvoie (x:, y:, c:).
~poseKp = { |name|
    var skel = ~feeds[\pose_skel0];
    var i = ~poseKpNames.indexOf(name);
    if(skel.notNil and: { i.notNil }) { skel[i] } { nil }
};

// =====================================================================
//  VELIB Paris  -- flux velos partages
// =====================================================================
~feedDefPriv.(\d_velib_total, '/data/velib/total', { |msg|
    ~feedSet.(\velib_bikes,   msg[1]);
    ~feedSet.(\velib_docks,   msg[2]);
    ~feedSet.(\velib_stations,msg[3]);
});
~feedDefPriv.(\d_velib_flow, '/data/velib/flow', { |msg|
    ~feedSet.(\velib_flow_min, msg[1]);  // bikes/min, signe
});
~feedDefPriv.(\d_velib_density, '/data/velib/density', { |msg|
    ~feedSet.(\velib_density, msg[1]);   // 0..1
});
~feedDefPriv.(\d_velib_hot, '/data/velib/hotspot', { |msg|
    ~feedSet.(\velib_hotspot, [msg[1], msg[2], msg[3], msg[4]]);
});

// =====================================================================
//  SYTADIN  -- trafic perimetre Ile-de-France
// =====================================================================
~feedDefPriv.(\d_syt_flow, '/data/sytadin/flow', { |msg|
    ~feedSet.(\syt_flow_avg, msg[1]);
    ~feedSet.(\syt_flow_max, msg[2]);
});
~feedDefPriv.(\d_syt_speed, '/data/sytadin/speed', { |msg|
    ~feedSet.(\syt_speed_avg, msg[1]);
    ~feedSet.(\syt_speed_min, msg[2]);  // capteur le plus lent
});
~feedDefPriv.(\d_syt_occ, '/data/sytadin/occupancy', { |msg|
    ~feedSet.(\syt_occ_avg, msg[1]);
    ~feedSet.(\syt_occ_max, msg[2]);
});
~feedDefPriv.(\d_syt_jam, '/data/sytadin/jam', { |msg|
    ~feedSet.(\syt_jam_count, msg[1]);
});

// =====================================================================
//  HUB'EAU  -- rivieres france (hydrometrie)
// =====================================================================
~feedDefPriv.(\d_river_lvl, '/data/rivers/level', { |msg|
    var sid = msg[1], h = msg[2], q = msg[3];
    var all = ~feeds[\river_stations] ? IdentityDictionary.new;
    all[sid.asSymbol] = (h: h, q: q);
    ~feedSet.(\river_stations, all);
});
~feedDefPriv.(\d_river_avg, '/data/rivers/avg', { |msg|
    ~feedSet.(\river_avg_h, msg[1]);
    ~feedSet.(\river_avg_q, msg[2]);
});
~feedDefPriv.(\d_river_alert, '/data/rivers/alert', { |msg|
    ~feedSet.(\river_alert, [msg[1], msg[2]]);
    ("*** RIVER ALERT " ++ msg[1] ++ " severity " ++ msg[2] ++ " ***").postln;
});

// =====================================================================
//  IDFM / PRIM  -- disruptions metro/RER
// =====================================================================
~feedDefPriv.(\d_idfm_disrn, '/data/idfm/disruption_n', { |msg|
    ~feedSet.(\idfm_disruption_n, msg[1]);
});
~feedDefPriv.(\d_idfm_disr, '/data/idfm/disruption', { |msg|
    ~feedSet.(\idfm_last_disruption, [msg[1], msg[2]]);
    if(msg[2] >= 2) {
        ("[idfm] disruption line=" ++ msg[1] ++ " sev=" ++ msg[2]).postln;
    };
});

// =====================================================================
//  AIS  -- bateaux temps reel monde
// =====================================================================
~feedDefPriv.(\d_ais_ship, '/data/ais/ship', { |msg|
    var mmsi = msg[1], lat = msg[2], lon = msg[3], sog = msg[4], cog = msg[5];
    ~feedSet.(\ais_last_ship, [mmsi, lat, lon, sog, cog]);
});
~feedDefPriv.(\d_ais_cargo, '/data/ais/cargo', { |msg|
    ~feedSet.(\ais_last_cargo, [msg[1], msg[2], msg[3], msg[4]]);
});
~feedDefPriv.(\d_ais_count, '/data/ais/count', { |msg|
    ~feedSet.(\ais_count, msg[1]);
});
~feedDefPriv.(\d_ais_rate, '/data/ais/rate', { |msg|
    ~feedSet.(\ais_rate, msg[1]);
});

// =====================================================================
//  GBFS multi-villes  -- velos partages FR + BE
// =====================================================================
~feedDefPriv.(\d_gbfs_sum_fr, '/data/gbfs/sum/bikes_fr', { |msg|
    ~feedSet.(\gbfs_sum_fr, msg[1]);
});
~feedDefPriv.(\d_gbfs_sum_be, '/data/gbfs/sum/bikes_be', { |msg|
    ~feedSet.(\gbfs_sum_be, msg[1]);
});
~feedDefPriv.(\d_gbfs_sum_cities, '/data/gbfs/sum/cities', { |msg|
    ~feedSet.(\gbfs_cities_ok, msg[1]);
});
// Per-ville : 10 OSCdef explicites (SC ne supporte pas wildcard natif).
~gbfsCities = [\lyon, \bordeaux, \lille, \toulouse, \nantes,
    \strasbourg, \rennes, \nancy, \bruxelles, \anvers];
~gbfsCities.do { |city|
    [\bikes, \docks, \density].do { |sub|
        var path = "/data/gbfs/" ++ city.asString ++ "/" ++ sub.asString;
        var key  = (\gbfs_ ++ city ++ "_" ++ sub).asSymbol;
        var defKey = (\d_gbfs_ ++ city ++ "_" ++ sub).asSymbol;
        ~feedDefPriv.(defKey, path, { |msg|
            ~feeds[key] = msg[1];
        });
    };
};

// =====================================================================
//  ECO2MIX  -- mix electrique FR temps reel (via ODRE keyless)
// =====================================================================
~feedDefPriv.(\d_eco_mix, '/data/eco2mix/mix', { |msg|
    var keys = [\nuclear, \gas, \coal, \oil, \hydro, \wind, \solar, \bio];
    keys.do { |k, i| ~feeds[(\eco_ ++ k).asSymbol] = msg[i+1] ? 0.0 };
});
~feedDefPriv.(\d_eco_co2, '/data/eco2mix/co2', { |msg|
    ~feedSet.(\eco_co2, msg[1]);
});
~feedDefPriv.(\d_eco_load, '/data/eco2mix/load', { |msg|
    ~feedSet.(\eco_load, msg[1]);
});
~feedDefPriv.(\d_eco_renew, '/data/eco2mix/renew', { |msg|
    ~feedSet.(\eco_renew, msg[1]);
});

// =====================================================================
//  TELERAY IRSN  -- radioactivite gamma temps reel
// =====================================================================
~feedDefPriv.(\d_rad_avg, '/data/radioactivity/avg', { |msg|
    ~feedSet.(\rad_avg, msg[1]);
});
~feedDefPriv.(\d_rad_max, '/data/radioactivity/max', { |msg|
    ~feedSet.(\rad_max, [msg[1], msg[2]]);
});
~feedDefPriv.(\d_rad_min, '/data/radioactivity/min', { |msg|
    ~feedSet.(\rad_min, msg[1]);
});
~feedDefPriv.(\d_rad_n, '/data/radioactivity/n', { |msg|
    ~feedSet.(\rad_n, msg[1]);
});
~feedDefPriv.(\d_rad_anom, '/data/radioactivity/anomaly', { |msg|
    ~feedSet.(\rad_anomaly, [msg[1], msg[2]]);
    ("*** RAD ANOMALY " ++ msg[1] ++ " = " ++ msg[2] ++ " nSv/h ***").postln;
});

// =====================================================================
//  CARBURANTS  -- prix temps reel FR
// =====================================================================
~feedDefPriv.(\d_fuel_avg, '/data/fuel/avg', { |msg|
    var keys = [\sp95, \sp98, \e10, \e85, \gazole, \gplc];
    keys.do { |k, i| ~feeds[(\fuel_ ++ k).asSymbol] = msg[i+1] ? 0.0 };
});
~feedDefPriv.(\d_fuel_cheap, '/data/fuel/cheapest', { |msg|
    ~feedSet.(\fuel_sp95_min, msg[1]);
    ~feedSet.(\fuel_gazole_min, msg[2]);
});
~feedDefPriv.(\d_fuel_spread, '/data/fuel/spread', { |msg|
    ~feedSet.(\fuel_spread, msg[1]);
});
~feedDefPriv.(\d_fuel_n, '/data/fuel/n', { |msg|
    ~feedSet.(\fuel_n_stations, msg[1]);
});

// =====================================================================
//  Heartbeat -- detection de pont down
// =====================================================================
~feedDefPriv.(\d_heartbeat, '/data/heartbeat', { |msg|
    ~feeds[\__last_heartbeat] = SystemClock.seconds;
});

// =====================================================================
//  Helpers de lecture
// =====================================================================
~feedGet = { |key, fallback = 0.0|
    var v = ~feeds[key];
    if(v.isNil) { fallback } { v }
};

~feedAlive = {
    var hb = ~feeds[\__last_heartbeat];
    hb.notNil and: { (SystemClock.seconds - hb) < 15 }
};

~feedDump = {
    ~feeds.keysValuesDo { |k, v|
        if(k.asString.beginsWith("__").not) {
            ("  " ++ k.asString.padRight(22) ++ " = " ++ v).postln
        }
    };
    ("[feeds] heartbeat: " ++ if(~feedAlive.value) { "ALIVE" } { "DOWN" }).postln;
};

// =====================================================================
//  ACTION-HEAD  OSC handlers  (/pose/action, /pose/kin, /pose/enter, /pose/leave)
// =====================================================================
~poseState = ~poseState ? Dictionary.new;
~poseKin   = ~poseKin   ? Dictionary.new;

OSCdef(\poseAction, { |msg|
    var pid = msg[1];
    ~poseState[pid] = (
        labelIdx: msg[2],
        probs:    [msg[3], msg[4], msg[5]],
    );
}, '/pose/action');

OSCdef(\poseKin, { |msg|
    var pid = msg[1];
    ~poseKin[pid] = (
        speed:    msg[2],
        accel:    msg[3],
        symmetry: msg[4],
    );
}, '/pose/kin');

OSCdef(\poseEnter, { |msg|
    var pid = msg[1];
    ~poseState[pid] = (labelIdx: 0, probs: [1.0, 0.0, 0.0]);
    ~poseKin[pid]   = (speed: 0, accel: 0, symmetry: 0);
}, '/pose/enter');

OSCdef(\poseLeave, { |msg|
    var pid = msg[1];
    ~poseState.removeAt(pid);
    ~poseKin.removeAt(pid);
}, '/pose/leave');

"[OK] action-head OSC handlers".postln;

"[data_feeds] OSCdef installes (USGS, SWPC, NETZ, RTE, BLITZ, OPENSKY, BSKY, MEMPOOL, GCN).".postln;
"[data_feeds] usage : ~feeds[\\swpc_kp], ~feedGet.(\\netz_dev, 0), ~feedDump.()".postln;
)
