import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { createHash } from 'node:crypto';
const origin=process.env.GODOT_HOSTING_URL||'http://127.0.0.1:8132/';
const files=[];
for(const file of ['index.html','index.js','index.wasm','index.pck']) {
 const response=await fetch(new URL(file,origin),{headers:{'Accept-Encoding':'gzip'}});
 assert.equal(response.status,200);assert.equal(response.headers.get('content-encoding'),'gzip');
 const body=Buffer.from(await response.arrayBuffer()),local=await fs.readFile(new URL('../build/web/'+file,import.meta.url));
 assert.equal(createHash('sha256').update(body).digest('hex'),createHash('sha256').update(local).digest('hex'),`${file} matches export after decompression`);
 if(file.endsWith('.wasm'))assert.match(response.headers.get('content-type'),/application\/wasm/);
 files.push({file,content_type:response.headers.get('content-type'),encoding:response.headers.get('content-encoding'),compressed_bytes:Number(response.headers.get('content-length')),decoded_bytes:body.length});
}
assert.equal(await (await fetch(new URL('healthz',origin))).text(),'ok\n');
assert.equal((await fetch(new URL('missing-file',origin))).status,404);
await fs.writeFile(new URL('../reports/full-hosting.json',import.meta.url),JSON.stringify({recorded_at:new Date().toISOString(),checks:'PASS: container, health, 404, MIME, gzip and byte-for-byte decoded export',files},null,2)+'\n');
console.log('PASS: compressed Godot container delivery, MIME types, health, 404 and file integrity');
