// =====================================================================
//  webgl/app.js  --  Portage WebGL des visualizers oF data-driven.
//
//  Stack : three.js r171 + WebGPURenderer (auto-fallback WebGL2)
//          Materiaux ecrits en TSL (Three Shading Language) pour beneficier
//          de la generation automatique GLSL/WGSL et des nodes builtin
//          (mx_noise pour fbm, etc).
//
//  Architecture inspiree directement de oscope-of/src/visualizers :
//    BG     : ShaderVis-like fullscreen (aurore, flares)
//    GLOBE  : MeshVis-like wireframe sphere
//    POINTS : ParticleVis-like quake/strike/plane (instances)
// =====================================================================
import * as THREE from "three";
import {
    Fn, vec2, vec3, vec4, float, mix, smoothstep, length, sin,
    uniform, time, uv, positionLocal, mx_fractal_noise_float,
    abs as tslAbs, pow as tslPow,
} from "three/tsl";

// ---------------------------------------------------------------------
//  Renderer : WebGPU prefere, fallback WebGL2 transparent (three.js le
//  fait via WebGPURenderer{ forceWebGL: ! navigator.gpu }).
// ---------------------------------------------------------------------
const canvas = document.getElementById("c");
const backendEl = document.getElementById("backend");

// debug : ?webgl=1 pour forcer le fallback WebGL2 (verifier si bug WebGPU Points)
const forceWebGL = new URLSearchParams(location.search).has("webgl");
const hasWebGPU = !!navigator.gpu && !forceWebGL;
const renderer = new THREE.WebGPURenderer({
    canvas,
    antialias: true,
    forceWebGL: !hasWebGPU,
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.setClearColor(0x000000, 1);
await renderer.init();
backendEl.textContent = hasWebGPU ? "WebGPU" : "WebGL2 (fallback)";

const scene  = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(60, 1, 0.1, 100);
camera.position.set(0, 1.0, 3.6);
camera.lookAt(0, 0, 0);

function resize() {
    const w = canvas.clientWidth, h = canvas.clientHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
}
window.addEventListener("resize", resize);
resize();

// ---------------------------------------------------------------------
//  Uniforms partages -- pilotes par window.feeds a chaque frame
// ---------------------------------------------------------------------
const uKp     = uniform(0.2);
const uWind   = uniform(0.3);
const uBz     = uniform(0.0);
const uFlare  = uniform(0.0);
const uRenew  = uniform(0.25);
const uDev    = uniform(0.0);
const uAlive  = uniform(1.0);
const uNow    = uniform(0.0);

// ---------------------------------------------------------------------
//  Background : aurore TSL (fbm via mx_fractal_noise + bandes verticales)
//  Equivalent shader des PRESET D Aurora (cote son).
// ---------------------------------------------------------------------
const bgGeo = new THREE.PlaneGeometry(2, 2);
const bgMat = new THREE.NodeMaterial();

bgMat.colorNode = Fn(() => {
    const p   = uv().sub(0.5).mul(vec2(2.4, 1.4));
    const t   = time.mul(uWind.mul(0.2).add(0.05));
    const np  = vec2(p.x.mul(3.0).add(t), p.y.mul(1.5).add(t.mul(0.3)));
    const aurora = tslPow(
        mx_fractal_noise_float(np, 5, 2.03, 0.5, 1.0).add(0.5),
        uBz.mul(0.8).add(1.6),
    );
    const maskY  = smoothstep(uBz.mul(0.3).sub(0.6), float(0.6), p.y);
    const aLit   = aurora.mul(maskY).mul(uKp.add(0.4));

    const colA = mix(vec3(0.05, 0.4, 0.2), vec3(0.1, 0.9, 0.6), uKp);
    const colB = mix(vec3(0.4, 0.1, 0.6), vec3(0.9, 0.3, 0.8), uRenew);
    let col    = aLit.mul(colA).add(aLit.mul(aLit).mul(colB));
    col        = col.add(vec3(1.0, 0.6, 0.2).mul(uFlare).mul(0.5));

    const r    = length(p);
    col        = col.mul(smoothstep(float(1.4), float(0.2), r));
    return vec4(col, 1.0);
})();

bgMat.depthWrite = false;
bgMat.depthTest  = false;
const bgMesh = new THREE.Mesh(bgGeo, bgMat);
bgMesh.frustumCulled = false;
// rendre en background : on ajoute a une scene bg
const bgScene = new THREE.Scene();
const bgCam   = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
bgScene.add(bgMesh);

// ---------------------------------------------------------------------
//  Globe wireframe : SphereGeometry -> WireframeGeometry -> LineSegments
// ---------------------------------------------------------------------
const sphereGeo = new THREE.SphereGeometry(1.0, 36, 18);
const wireGeo   = new THREE.WireframeGeometry(sphereGeo);
const wireMat   = new THREE.LineBasicNodeMaterial({ transparent: true });

wireMat.colorNode = Fn(() => {
    const y = positionLocal.y;
    const base = mix(vec3(0.3, 0.5, 1.0), vec3(0.4, 1.0, 0.7), uRenew);
    return vec4(base.mul(y.mul(0.5).add(0.5)).mul(uAlive.mul(0.6).add(0.4)), 0.7);
})();

// micro-tremblement via positionNode pilote par dev (Netzfrequenz)
wireMat.positionNode = Fn(() => {
    const p = positionLocal;
    const wob = sin(p.y.mul(30.0).add(uDev)).mul(tslAbs(uDev)).mul(0.5);
    return p.add(p.mul(wob));
})();

const globe = new THREE.LineSegments(wireGeo, wireMat);
scene.add(globe);

// ---------------------------------------------------------------------
//  Particules : quake/strike/plane projetees sur la sphere
//  Implementation via InstancedMesh (3 meshs, un par kind) : plus fiable
//  que Points + TSL en three.js r171 (le pipeline Points est instable).
// ---------------------------------------------------------------------
const MAX_PTS_KIND = 256;
const KIND_COLORS = [
    new THREE.Color(1.0, 0.25, 0.05),   // quake = rouge orange
    new THREE.Color(0.7, 0.95, 1.0),    // strike = cyan
    new THREE.Color(0.3, 0.95, 0.7),    // plane = turquoise
];
const KIND_LIFE = [10000, 2500, 8000];   // ms
const KIND_BASE_SIZE = [0.012, 0.015, 0.008];   // base, multiplie par (1 + mag*K) par kind

function lonLatToVec3(lon, lat, r) {
    const lonR = lon * Math.PI / 180;
    const latR = lat * Math.PI / 180;
    return new THREE.Vector3(
        r * Math.cos(latR) * Math.cos(lonR),
        r * Math.sin(latR),
        r * Math.cos(latR) * Math.sin(lonR),
    );
}

// Pool de plain Meshes par kind. InstancedMesh + MeshBasicNodeMaterial est
// instable en three.js r171 + WebGPU TSL (matrice instance ignoree).
const sphereInstGeo = new THREE.IcosahedronGeometry(1.0, 1);
const ptGroups = KIND_COLORS.map((col, kind) => {
    const mat = new THREE.MeshBasicNodeMaterial({
        color: col,
        transparent: true,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
    });
    const group = new THREE.Group();
    const pool = [];
    for (let i = 0; i < MAX_PTS_KIND; i++) {
        const m = new THREE.Mesh(sphereInstGeo, mat);
        m.scale.set(0, 0, 0);
        m.visible = false;
        m.frustumCulled = false;
        m.userData.t0 = 0;
        m.userData.baseScale = 0;
        group.add(m);
        pool.push(m);
    }
    group.userData = { pool, head: 0 };
    scene.add(group);
    return group;
});

function addPoint(lon, lat, kind, mag) {
    const group = ptGroups[kind];
    if (!group) return;
    const i = group.userData.head;
    group.userData.head = (i + 1) % MAX_PTS_KIND;
    const r = kind === 2 ? 1.05 + mag * 0.25 : 1.015;
    const base = KIND_BASE_SIZE[kind];
    // mag scaling : quake (0..8) -> *1+mag*0.5 ; strike (1..10) -> *1+mag*0.2 ; plane (0..1) -> *1+mag*0.5
    const magK = kind === 0 ? 0.5 : kind === 1 ? 0.2 : 0.5;
    const s = base * (1.0 + mag * magK);
    const pos = lonLatToVec3(lon, lat, r);
    const m = group.userData.pool[i];
    m.position.copy(pos);
    m.userData.baseScale = s;
    m.userData.t0 = performance.now();
    m.scale.set(s, s, s);
    m.visible = true;
}

window.onFeed("/data/usgs/event",         (a) => addPoint(a[1], a[2], 0, Math.max(0, a[0])));
window.onFeed("/data/blitzortung/strike", (a) => addPoint(a[1], a[0], 1, Math.min(10, a[3] || 1)));
window.onFeed("/data/opensky/plane",      (a) => addPoint(a[1], a[2], 2, (a[3] || 0) / 12000));

// Pre-seed visuel : 6 points repartis tant que les vrais feeds n'ont pas
// encore push (OpenSky peut etre rate-limited 429, quake/strike sporadiques).
function seedDemo() {
    const demos = [
        [-122, 37, 0, 5.5], [139, 35, 0, 5.2], [-74, -12, 0, 4.8],
        [2.35, 48.85, 1, 4], [13.4, 52.5, 1, 3], [20, -1, 1, 5],
        [-40, 50, 2, 0.8], [-30, 45, 2, 0.7], [-50, 55, 2, 0.9],
    ];
    for (const [lon, lat, kind, mag] of demos) addPoint(lon, lat, kind, mag);
}
seedDemo();
// re-seed periodique pour qu'il y ait toujours qq chose si feeds vides
setInterval(seedDemo, 7000);

// expose pour debug
window.__realart = { ptGroups, scene, camera, addPoint, seedDemo };

// ---------------------------------------------------------------------
//  HUD update
// ---------------------------------------------------------------------
const aliveEl = document.getElementById("alive");
const evtEl   = document.getElementById("evt");
const kpEl    = document.getElementById("kp");
const windEl  = document.getElementById("wind");
setInterval(() => {
    const a = window.feeds?.alive;
    aliveEl.textContent = a ? "ALIVE" : "DOWN";
    aliveEl.className   = a ? "alive" : "dead";
    evtEl.textContent   = window.feeds?.tick ?? 0;
    kpEl.textContent    = (window.feeds?.swpc.kp ?? 0).toFixed(1);
    windEl.textContent  = (window.feeds?.swpc.wind_speed ?? 0).toFixed(0);
}, 250);

// ---------------------------------------------------------------------
//  Render loop
// ---------------------------------------------------------------------
let t0Start = performance.now();
function frame() {
    const now = performance.now();

    // Sync uniforms <- feeds
    uKp.value    = window.f.kp01();
    uWind.value  = window.f.wind01();
    uBz.value    = Math.max(-1, Math.min(1, (window.feeds?.swpc.bz ?? 0) / 20));
    uFlare.value = window.f.flarePulse();
    uRenew.value = window.f.renew();
    uDev.value   = (window.feeds?.netz.dev ?? 0) * 50;
    uAlive.value = window.feeds?.alive ? 1.0 : 0.4;
    uNow.value   = now;

    // Auto-rotation pilotee par Kp (orages magnetiques accelerent)
    const t = (now - t0Start) / 1000;
    globe.rotation.y = t * 0.05 * (1 + window.f.kp01());
    globe.rotation.x = -0.3;
    // particules : meme rotation que le globe (group transforme tous les meshes enfants)
    for (const g of ptGroups) { g.rotation.copy(globe.rotation); }

    // Animation : scale decroit avec age, expiration -> invisible
    for (let k = 0; k < ptGroups.length; k++) {
        const pool = ptGroups[k].userData.pool;
        const life = KIND_LIFE[k];
        for (let i = 0; i < MAX_PTS_KIND; i++) {
            const m = pool[i];
            if (!m.visible) continue;
            const age = now - m.userData.t0;
            if (age >= life) {
                m.visible = false;
                m.userData.t0 = 0;
                continue;
            }
            const sFactor = 1.0 - (age / life) * 0.5;
            const s = m.userData.baseScale * sFactor;
            m.scale.set(s, s, s);
        }
    }

    renderer.autoClear = false;
    renderer.clear();
    renderer.render(bgScene, bgCam);
    renderer.render(scene, camera);

    requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
