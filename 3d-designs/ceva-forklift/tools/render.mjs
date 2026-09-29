// Render PNG previews of the assembled model from the exported STLs.
// Usage: node tools/render.mjs <path-to-node_modules-with-three> [outdir]
// Needs Playwright (Chromium) and three.js.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';

const here = path.dirname(new URL(import.meta.url).pathname);
const root = path.resolve(here, '..');
const nm = path.resolve(process.argv[2] || 'node_modules');
const outDir = path.resolve(process.argv[3] || path.join(root, 'renders'));

const page_html = `<!doctype html><html><body style="margin:0;background:#fff">
<script type="importmap">{"imports":{"three":"/nm/three/build/three.module.js","three/addons/":"/nm/three/examples/jsm/"}}</script>
<script type="module">
import * as THREE from 'three';
import { STLLoader } from 'three/addons/loaders/STLLoader.js';
const W = 1600, H = 1100;
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setSize(W, H); renderer.setPixelRatio(1);
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene(); scene.background = new THREE.Color('#eef0f3');
scene.add(new THREE.HemisphereLight(0xffffff, 0x9aa3ad, 1.6));
const sun = new THREE.DirectionalLight(0xffffff, 2.2);
sun.position.set(-60, -120, 200); sun.castShadow = true;
sun.shadow.mapSize.set(4096, 4096);
Object.assign(sun.shadow.camera, { left: -150, right: 150, top: 150, bottom: -150, near: 1, far: 600 });
sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.3;
sun.target.position.set(55, 0, 20); scene.add(sun); scene.add(sun.target);
const fill = new THREE.DirectionalLight(0xffffff, 0.6); fill.position.set(200, 100, 80); scene.add(fill);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(2000, 2000), new THREE.ShadowMaterial({ opacity: 0.18 }));
ground.receiveShadow = true; scene.add(ground);
const grid = new THREE.Mesh(new THREE.PlaneGeometry(2000, 2000), new THREE.MeshBasicMaterial({ color: '#e6e9ee' }));
grid.position.z = -0.05; scene.add(grid);

const COL = { white:'#f2f2ef', black:'#26272a', red:'#d3262d', navy:'#1f2c63', kraft:'#c8a06a' };
const loader = new STLLoader();
const load = (f) => new Promise(r => loader.load('/stl/' + f + '.stl', g => { g.computeVertexNormals(); r(g); }));
const mat = (c) => new THREE.MeshStandardMaterial({ color: COL[c], roughness: c === 'black' ? 0.55 : 0.62, metalness: 0.0 });
function mesh(g, c, m) { const o = new THREE.Mesh(g, mat(c)); o.castShadow = o.receiveShadow = true; if (m) o.applyMatrix4(m); return o; }

const groups = { body: new THREE.Group(), mast: new THREE.Group(), load: new THREE.Group(), wheels: new THREE.Group() };
for (const [f, c] of [['body_white','white'],['body_black','black'],['body_red','red']])
  groups.body.add(mesh(await load(f), c, new THREE.Matrix4().makeTranslation(0, 0, 4)));
groups.mast.add(mesh(await load('mast_black'), 'black'));
for (const [f, c] of [['load_kraft','kraft'],['load_navy','navy'],['load_red','red']]) groups.load.add(mesh(await load(f), c));
const wheelDefs = [['wheelF', 45, 11], ['wheelR', 14, 9]];
for (const [n, x, r] of wheelDefs) {
  const gb = await load(n + '_black'), gw = await load(n + '_white');
  for (const s of [1, -1]) {
    const m = new THREE.Matrix4().makeTranslation(x, s * 24.5, r).multiply(new THREE.Matrix4().makeRotationX(s * Math.PI / 2));
    groups.wheels.add(mesh(gb, 'black', m)); groups.wheels.add(mesh(gw, 'white', m));
  }
}
for (const g of Object.values(groups)) scene.add(g);

const cam = new THREE.PerspectiveCamera(24, W / H, 1, 3000); cam.up.set(0, 0, 1);
window.shot = (view) => {
  const v = view;
  groups.body.position.set(...(v.explode ? [-25, 0, 18] : [0, 0, 0]));
  groups.mast.position.set(...(v.explode ? [8, 0, 10] : [0, 0, 0]));
  groups.load.position.set(...(v.explode ? [34, 0, 22] : [0, 0, 0]));
  groups.wheels.children.forEach((w, i) => { w.userData.base ??= w.position.clone();
    const s = Math.sign(w.userData.base.y); w.position.copy(w.userData.base); if (v.explode) { w.position.y += s * 22; w.position.x -= 25; } });
  cam.position.set(...v.pos); cam.lookAt(...v.target); cam.updateProjectionMatrix();
  renderer.render(scene, cam);
  return renderer.domElement.toDataURL('image/png');
};
window.ready = true;
</script></body></html>`;

const views = {
  '01_hero_front_left':  { pos: [235, 185, 150], target: [55, 0, 26] },
  '02_side':             { pos: [55, -320, 150], target: [55, 0, 30] },
  '03_rear_right':       { pos: [-170, -200, 135], target: [50, 0, 26] },
  '04_top_logo':         { pos: [230, -60, 250], target: [70, 0, 20] },
  '05_exploded':         { pos: [215, -290, 190], target: [45, 0, 30], explode: true },
};

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1600, height: 1100 } });
await page.route('http://local/**', async (route) => {
  const u = new URL(route.request().url());
  let file;
  if (u.pathname === '/') return route.fulfill({ body: page_html, contentType: 'text/html' });
  if (u.pathname.startsWith('/nm/')) file = path.join(nm, u.pathname.slice(4));
  else if (u.pathname.startsWith('/stl/')) file = path.join(root, 'stl', u.pathname.slice(5));
  if (!file || !fs.existsSync(file)) return route.fulfill({ status: 404, body: 'nf' });
  route.fulfill({ body: fs.readFileSync(file), contentType: file.endsWith('.js') ? 'text/javascript' : 'application/octet-stream' });
});
page.on('console', (m) => console.log('[page]', m.text()));
page.on('pageerror', (e) => console.log('[pageerror]', e.message));
await page.goto('http://local/');
await page.waitForFunction('window.ready === true', null, { timeout: 120000 });
fs.mkdirSync(outDir, { recursive: true });
for (const [name, v] of Object.entries(views)) {
  const data = await page.evaluate((v) => window.shot(v), v);
  fs.writeFileSync(path.join(outDir, name + '.png'), Buffer.from(data.split(',')[1], 'base64'));
  console.log('wrote', name);
}
await browser.close();
