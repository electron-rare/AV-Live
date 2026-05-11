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
    Fn, vec2, vec3, vec4, float, mix, smoothstep, length, sin, cos,
    uniform, time, attribute, uv, positionLocal, mx_fractal_noise_float,
    abs as tslAbs, clamp, pow as tslPow, varyingProperty,
} from "three/tsl";

// ---------------------------------------------------------------------
//  Renderer : WebGPU prefere, fallback WebGL2 transparent (three.js le
//  fait via WebGPURenderer{ forceWebGL: ! navigator.gpu }).
// ---------------------------------------------------------------------
const canvas = document.getElementById("c");
const backendEl = document.getElementById("backend");

const hasWebGPU = !!navigator.gpu;
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
// ---------------------------------------------------------------------
const MAX_PTS = 1024;
const ptPositions = new Float32Array(MAX_PTS * 3);
const ptKinds     = new Float32Array(MAX_PTS);
const ptT0s       = new Float32Array(MAX_PTS);
const ptMags      = new Float32Array(MAX_PTS);
let ptCount = 0;

function lonLatToVec3(lon, lat, r) {
    const lonR = lon * Math.PI / 180;
    const latR = lat * Math.PI / 180;
    return [
        r * Math.cos(latR) * Math.cos(lonR),
        r * Math.sin(latR),
        r * Math.cos(latR) * Math.sin(lonR),
    ];
}

function addPoint(lon, lat, kind, mag) {
    if (ptCount >= MAX_PTS) {
        ptPositions.copyWithin(0, 256 * 3, ptCount * 3);
        ptKinds    .copyWithin(0, 256,     ptCount);
        ptT0s      .copyWithin(0, 256,     ptCount);
        ptMags     .copyWithin(0, 256,     ptCount);
        ptCount -= 256;
    }
    const r = kind === 2 ? 1.05 + mag * 0.3 : 1.01;
    const [x, y, z] = lonLatToVec3(lon, lat, r);
    const i = ptCount;
    ptPositions[i*3+0] = x;
    ptPositions[i*3+1] = y;
    ptPositions[i*3+2] = z;
    ptKinds[i] = kind;
    ptT0s[i]   = performance.now();
    ptMags[i]  = mag;
    ptCount++;
    geomDirty = true;
}

window.onFeed("/data/usgs/event",        (a) => addPoint(a[1], a[2], 0, Math.max(0, a[0])));
window.onFeed("/data/blitzortung/strike", (a) => addPoint(a[1], a[0], 1, Math.min(10, a[3] || 1)));
window.onFeed("/data/opensky/plane",      (a) => addPoint(a[1], a[2], 2, (a[3] || 0) / 12000));

const ptGeo = new THREE.BufferGeometry();
ptGeo.setAttribute("position", new THREE.BufferAttribute(ptPositions, 3));
ptGeo.setAttribute("kind",     new THREE.BufferAttribute(ptKinds, 1));
ptGeo.setAttribute("t0",       new THREE.BufferAttribute(ptT0s, 1));
ptGeo.setAttribute("mag",      new THREE.BufferAttribute(ptMags, 1));
ptGeo.setDrawRange(0, 0);

const ptMat = new THREE.PointsNodeMaterial({
    transparent: true,
    blending:    THREE.AdditiveBlending,
    depthWrite:  false,
});

const aKind = attribute("kind");
const aT0   = attribute("t0");
const aMag  = attribute("mag");

const lifeNode = aKind.lessThan(0.5).select(float(8.0),
                  aKind.lessThan(1.5).select(float(2.5), float(6.0)));
const ageNode  = uNow.sub(aT0).div(1000.0);
const age01    = clamp(ageNode.div(lifeNode), 0.0, 1.0);

ptMat.sizeNode = Fn(() => {
    const base = aKind.lessThan(0.5).select(aMag.mul(6.0).add(8.0),
                  aKind.lessThan(1.5).select(aMag.mul(0.6).add(4.0), float(3.0)));
    return base.mul(age01.mul(-0.5).add(1.0));
})();

ptMat.colorNode = Fn(() => {
    const quakeCol  = mix(vec3(1.0, 0.4, 0.0), vec3(1.0, 0.1, 0.0),
                          clamp(aMag.div(8.0), 0.0, 1.0));
    const strikeCol = vec3(0.7, 0.9, 1.0).add(age01.mul(-0.4).add(0.4));
    const planeCol  = vec3(0.3, 0.9, 0.7);
    const col = aKind.lessThan(0.5).select(quakeCol,
                 aKind.lessThan(1.5).select(strikeCol, planeCol));
    const alpha = age01.mul(-1.0).add(1.0);
    return vec4(col, alpha);
})();

const points = new THREE.Points(ptGeo, ptMat);
scene.add(points);
let geomDirty = false;

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

    // GC particules age > 12 s
    if (ptCount > 0) {
        let writeI = 0;
        for (let i = 0; i < ptCount; i++) {
            if (now - ptT0s[i] < 12000) {
                if (writeI !== i) {
                    ptPositions.copyWithin(writeI*3, i*3, i*3 + 3);
                    ptKinds[writeI] = ptKinds[i];
                    ptT0s[writeI]   = ptT0s[i];
                    ptMags[writeI]  = ptMags[i];
                }
                writeI++;
            }
        }
        if (writeI !== ptCount) { ptCount = writeI; geomDirty = true; }
    }
    if (geomDirty) {
        ptGeo.setDrawRange(0, ptCount);
        ptGeo.attributes.position.needsUpdate = true;
        ptGeo.attributes.kind    .needsUpdate = true;
        ptGeo.attributes.t0      .needsUpdate = true;
        ptGeo.attributes.mag     .needsUpdate = true;
        geomDirty = false;
    }

    renderer.autoClear = false;
    renderer.clear();
    renderer.render(bgScene, bgCam);
    renderer.render(scene, camera);

    requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
