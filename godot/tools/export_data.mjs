// Capture balance and reference maps from the frozen migration reference. No runtime JS dependency.
import fs from 'node:fs';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../../', import.meta.url));
const source = process.argv.includes('--current-source') ? root+'js/' : fileURLToPath(new URL('./reference/',import.meta.url));
const c = { console }; c.window = c; vm.createContext(c);
for (const name of ['util','data','mapgen','world','entities','alchemy','magic','loot','ai','sanitation','game']) {
  const file = source + name + '.js';
  if (name === 'magic' && !fs.existsSync(file)) continue;
  vm.runInContext(fs.readFileSync(file, 'utf8'), c);
}
const G = c.G;
fs.writeFileSync(root+'godot/data/balance.json', JSON.stringify({
  buildings:G.BUILDINGS,units:G.UNITS,spells:G.SPELLS,potions:G.POTIONS,loot:G.LOOT,
  campaign:G.CAMPAIGN,sanitation:G.SANITATION,names:G.NAMES,tips:G.TIPS
},null,2)+'\n');
G.headless = true;
const maps = [];
for (const seed of [0,1,4,41972,4294967295,'Alderwick']) {
  G.reset(seed);
  maps.push({seed:G.seed,name:G.LEVEL.name,start:G.LEVEL.start,lairs:G.LEVEL.lairs,
    kinds:G.tiles.map(t=>t.kind),trees:G.trees.length,
    rolls:Array.from({length:8},G.rng(G.seed))});
}
fs.writeFileSync(root+'godot/tests/reference_maps.json',JSON.stringify(maps)+'\n');
console.log('Exported all balance tables and six browser reference maps.');
