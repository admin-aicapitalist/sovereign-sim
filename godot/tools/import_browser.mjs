// Run from any directory: node godot/tools/import_browser.mjs
// Imports original sprite metadata. Run before prepare_art.py; never modifies source art.
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const out=path.join(root,'godot');
const source=process.argv.includes('--current-source')?path.join(root,'js'):fileURLToPath(new URL('./reference/',import.meta.url));
const c={console,URL,document:{currentScript:{src:''}}};c.window=c;vm.createContext(c);
for(const name of ['util','data']) vm.runInContext(fs.readFileSync(path.join(source,name+'.js'),'utf8'),c);
const G=c.G;
for(const rel of ['palace/palace-sprite','buildings/buildings-sprites','units/units-sprites','environment/environment-sprites']){
  const file=path.join(root,'assets/art',rel+'.js');c.document.currentScript.src=pathToFileURL(file).href;
  vm.runInContext(fs.readFileSync(file,'utf8'),c);
}
const assets={};
for(const [key,a] of [...Object.entries(G.spriteAssets),...Object.entries(G.unitAssets).map(([key,a])=>['unit_'+key,a])]){
  const src=fileURLToPath(new URL(a.src));
  const relative=path.relative(root,src);
  assets[key]={...a,source:relative,src:'res://assets/'+key+'.png'};
  delete assets[key].hitRows;
}
// Keep the native directional character release when refreshing the legacy map art.
const characters=path.join(root,'assets/art/units/directional/manifest.json');
if(fs.existsSync(characters)) Object.assign(assets,JSON.parse(fs.readFileSync(characters,'utf8')));
fs.writeFileSync(path.join(out,'data/assets.json'),JSON.stringify(assets));
console.log(`Imported metadata for ${Object.keys(assets).length} original art assets. Run prepare_art.py next.`);
