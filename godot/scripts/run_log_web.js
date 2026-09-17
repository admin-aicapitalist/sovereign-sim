(() => {
  if (window.sovereignRunLogs) return;
  let db, opening, queue=[], saving=false, error='', runs=[], lastExport='', databaseName='';
  const request = r => new Promise((resolve,reject) => {r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
  const complete = tx => {const done=new Promise((resolve,reject) => {tx.oncomplete=resolve;tx.onabort=tx.onerror=()=>reject(tx.error||Error('Log transaction failed'));});done.catch(()=>{});return done;};
  async function refresh(){runs=await request(db.transaction('runs').objectStore('runs').getAll());runs.sort((a,b)=>b.updated-a.updated);}
  async function drain(){
    if(saving) return; saving=true;
    try {
      await opening;
      while(queue.length){
        const batch=queue[0],tx=db.transaction(['runs','chunks'],'readwrite'),done=complete(tx),store=tx.objectStore('runs');
        const old=await request(store.get(batch.run_id));
        // A segment + first sequence is stable across retries after an uncertain commit.
        const key=batch.run_id+':'+batch.events[0].segment+':'+batch.events[0].seq;
        const chunks=tx.objectStore('chunks');const exists=await request(chunks.get(key));
        if(!exists){
          chunks.add({key,run_id:batch.run_id,order:old?.batches||0,events:batch.events});
          const {events,...meta}=batch;
          store.put({...meta,updated:Date.now(),batches:(old?.batches||0)+1,events:(old?.events||0)+events.length});
        }
        await done;queue.shift();error='';
      }
      await refresh();
    }catch(e){error='Run log storage failed: '+e.message+'. Unwritten events remain in memory; export before closing this tab.';}
    finally{saving=false;if(queue.length&&!error)queueMicrotask(drain);}
  }
  window.sovereignRunLogs={
    init(name){
      databaseName=name;if(db){db.close();db=null;}
      opening=new Promise((resolve,reject)=>{
        const r=indexedDB.open(name,1);
        r.onupgradeneeded=()=>{const d=r.result;d.createObjectStore('runs',{keyPath:'run_id'});d.createObjectStore('chunks',{keyPath:'key'}).createIndex('run_id','run_id');};
        r.onsuccess=()=>{db=r.result;db.onversionchange=()=>db.close();resolve(db);};r.onerror=()=>reject(r.error);r.onblocked=()=>reject(Error('Local log database is blocked by another tab'));
      });
      opening.then(refresh).catch(e=>{error='Run log storage unavailable: '+e.message;});
    },
    append(text){try{queue.push(JSON.parse(text));drain();return true;}catch(e){error=e.message;return false;}},
    status(){return {error,runs,pending:queue.reduce((n,b)=>n+b.events.length,0),last_export:lastExport};},
    retry(){if(!saving&&error)this.init(databaseName);drain();},
    async download(id){
      try{
        // Export also includes queued events, even if persistence failed.
        const pending=queue.filter(b=>b.run_id===id);
        let chunks=[],meta=runs.find(r=>r.run_id===id)||{run_id:id};
        try{await opening;const tx=db.transaction(['runs','chunks']);const values=await Promise.all([request(tx.objectStore('chunks').index('run_id').getAll(id)),request(tx.objectStore('runs').get(id))]);chunks=values[0];meta=values[1]||meta;}catch(e){if(!pending.length)throw e;}
        chunks.sort((a,b)=>a.order-b.order);
        const events=chunks.flatMap(c=>c.events),seen=new Set(events.map(e=>e.segment+':'+e.seq));
        for(const b of pending)for(const e of b.events){const key=e.segment+':'+e.seq;if(!seen.has(key)){events.push(e);seen.add(key);}}
        if(pending.length){const {events:ignored,...latest}=pending.at(-1);meta={...meta,...latest};}
        const blob=new Blob([JSON.stringify({format:1,game:'Sovereign',run:meta,events})],{type:'application/json'});
        const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='sovereign-run-'+id+'.json';document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),30000);lastExport=a.download;
      }catch(e){error='Run log export failed: '+e.message;}
    }
  };
  addEventListener('pagehide',()=>{drain();});
})();
