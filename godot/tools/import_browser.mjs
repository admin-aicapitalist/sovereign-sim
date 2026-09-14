// Run from any directory: node godot/tools/import_browser.mjs [seed]
// Captures the existing generator and balance tables, never modifies the browser game.
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const out=path.join(root,'godot');
const c={console,URL,document:{currentScript:{src:''}}};c.window=c;vm.createContext(c);
for(const name of ['util','data','mapgen','world','entities','alchemy','magic','loot','ai','sanitation','game']){
  const file=path.join(root,'js',name+'.js');
  // Magic is optional for revisions predating that system; this importer only resets the map.
  if(name==='magic'&&!fs.existsSync(file))continue;
  vm.runInContext(fs.readFileSync(file,'utf8'),c);
}
const G=c.G;G.headless=true;G.reset(process.argv[2]??41972);
const lair=G.buildings.filter(b=>b.hostile).sort((a,b)=>G.dist(a,G.palace)-G.dist(b,G.palace))[0];
for(const b of G.buildings.filter(b=>b.hostile&&b!==lair))
  for(let y=b.ty;y<b.ty+b.data.size;y++)for(let x=b.tx;x<b.tx+b.data.size;x++)G.tile(x,y).blocked=false;
const initial=G.buildings.filter(b=>!b.hostile||b===lair);
const fixture={seed:G.seed,size:G.MAP,name:G.LEVEL.name,
  tiles:G.tiles.map(t=>({kind:t.kind,blocked:t.blocked,noise:t.noise})),trees:G.trees,decor:G.decor,
  buildings:initial.map(b=>({type:b.type,x:b.tx,y:b.ty})),
  units:G.units.filter(u=>!u.hostile||u.home===lair).map(u=>({type:u.type,x:u.x,y:u.y})),
  definitions:{buildings:G.BUILDINGS,units:G.UNITS}};
fs.writeFileSync(path.join(out,'data/world.json'),JSON.stringify(fixture));
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
fs.writeFileSync(path.join(out,'data/assets.json'),JSON.stringify(assets));
console.log(`Imported seed ${G.seed}: ${G.MAP}×${G.MAP}, ${G.trees.length} trees, one lair.`);
