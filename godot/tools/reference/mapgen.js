(function(){
  // Build geography first, choose dry sites, then connect them before planting trees.
  G.generateLayout=function(){
    const n=G.MAP,r=G.rng(G.seed^0xa511e9b3),range=(a,b)=>G.lerp(a,b,r()),integer=(a,b)=>Math.floor(range(a,b+1));
    const kind=integer(0,2),rotation=integer(0,3),phase=range(0,Math.PI*2);
    const center=range(35,53),bend=range(7,13),frequency=range(.045,.085),riverWidth=range(2.4,4.2);
    const lake={x:range(33,55),y:range(33,55),rx:range(15,23),ry:range(12,20)};
    const coast=range(19,30),bay=range(5,12);
    const ponds=Array.from({length:integer(2,4)},()=>({x:range(12,76),y:range(12,76),rx:range(3,7),ry:range(3,6)}));
    const rotated=(x,y)=>rotation===0?[x,y]:rotation===1?[y,n-1-x]:rotation===2?[n-1-x,n-1-y]:[n-1-y,x];
    const water=new Uint8Array(n*n),clearance=new Uint8Array(n*n);clearance.fill(255);
    const queue=[];
    for(let y=0;y<n;y++)for(let x=0;x<n;x++){
      const [u,v]=rotated(x,y),wave=Math.sin(v*frequency+phase)*bend+Math.sin(v*.17+phase)*2;
      let wet=kind===0?Math.abs(u-center-wave)<riverWidth:kind===1?((u-lake.x)/lake.rx)**2+((v-lake.y)/lake.ry)**2<1+.16*Math.sin(u*.22+v*.19+phase):u<coast+Math.sin(v*.075+phase)*bay+Math.sin(v*.19)*2.5;
      // An outlet changes the great lake's shoreline and creates a crossing route.
      if(kind===1&&v>lake.y)wet=wet||Math.abs(u-lake.x-Math.sin(v*.075+phase)*4)<2.1;
      if(ponds.some(p=>((u-p.x)/p.rx)**2+((v-p.y)/p.ry)**2<1+.12*Math.sin(u*.4+v*.3+phase)))wet=true;
      if(wet){water[y*n+x]=1;clearance[y*n+x]=0;queue.push(y*n+x);}
    }
    // Chebyshev distance supplies a conservative dry square around every site.
    for(let i=0;i<queue.length;i++){
      const key=queue[i],x=key%n,y=Math.floor(key/n);
      for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){
        const xx=x+dx,yy=y+dy,k=yy*n+xx;if(xx<0||yy<0||xx>=n||yy>=n||clearance[k]<=clearance[key]+1)continue;
        clearance[k]=clearance[key]+1;queue.push(k);
      }
    }
    const candidates=[];
    for(let y=8;y<n-8;y+=2)for(let x=8;x<n-8;x+=2)if(clearance[y*n+x]>=6)candidates.push({x:x+.5,y:y+.5,clearance:clearance[y*n+x],roll:r()});
    const starts=candidates.filter(p=>p.x>=15&&p.y>=15&&p.x<=n-15&&p.y<=n-15&&p.clearance>=9);
    // Prefer a visible shore, while leaving enough ground for the first town.
    starts.sort((a,b)=>(Math.abs(a.clearance-11)+a.roll*8)-(Math.abs(b.clearance-11)+b.roll*8));
    const home=starts[0]||candidates.slice().sort((a,b)=>b.clearance-a.clearance)[0];
    if(!home)throw Error('No dry kingdom site for seed '+G.seed);
    const start={x:Math.floor(home.x)-1,y:Math.floor(home.y)-1};
    const occupied=[{...home,radius:8.5}],lairs=[],clearings=[];
    function site(min,max,separation,target){
      const choices=candidates.filter(p=>Math.hypot(p.x-home.x,p.y-home.y)>=min&&Math.hypot(p.x-home.x,p.y-home.y)<=max&&occupied.every(q=>Math.hypot(p.x-q.x,p.y-q.y)>separation));
      choices.sort((a,b)=>{
        const score=p=>Math.abs(Math.hypot(p.x-home.x,p.y-home.y)-target)*.22-p.roll*6-Math.min(...occupied.map(q=>Math.hypot(p.x-q.x,p.y-q.y)))*.25;
        return score(a)-score(b);
      });
      return choices[0];
    }
    for(const definition of G.CAMPAIGN){
      const frontier=!!definition.frontier,target=frontier?range(38,65):range(17,26);
      const p=site(frontier?32:16,frontier?120:30,frontier?13:10,target)||site(16,120,8,target);
      if(!p)throw Error('No lair site for seed '+G.seed);
      const entry={...definition,x:Math.floor(p.x)-1,y:Math.floor(p.y)-1};
      lairs.push(entry);occupied.push({...p,radius:6});
    }
    for(let i=0;i<4;i++){
      const p=site(16,120,10,range(25,65))||site(14,120,7,35);
      if(p){clearings.push([Math.floor(p.x),Math.floor(p.y),6]);occupied.push({...p,radius:6});}
    }
    const troll=site(18,30,7,22)||candidates.filter(p=>Math.hypot(p.x-home.x,p.y-home.y)>16).sort((a,b)=>a.roll-b.roll)[0];
    const trollEntry={x:troll.x,y:troll.y};occupied.push({...troll,radius:6});
    const cottages=[],angle=range(0,Math.PI*2);
    for(let i=0;i<3;i++){
      const a=angle+i*Math.PI*2/3+range(-.2,.2),radius=range(4.4,5.5);
      cottages.push({x:Math.floor(home.x+Math.cos(a)*radius),y:Math.floor(home.y+Math.sin(a)*radius)});
    }
    const level=G.LEVEL={name:['River Marches','Great Lake','Coastal Realm'][kind],kind,rotation,start,cottages,lairs,clearings,trollEntry,roads:[],bridges:[]};
    G.tiles=[];G.trees=[];G.decor=[];G.vision=[];
    const details=G.rng(G.seed^0x68bc21eb);
    for(let y=0;y<n;y++)for(let x=0;x<n;x++)G.tiles.push({x,y,kind:water[y*n+x]?'water':'grass',noise:details(),blocked:false,explored:false,visible:false,clearing:false});
    // Connect a spanning network. Expensive water encourages short crossings.
    const road=new Uint8Array(n*n),noise=Array.from({length:n*n},()=>range(0,.7));
    const nodes=[home,...lairs.map(p=>({x:p.x+1,y:p.y+1})),...clearings.map(([x,y])=>({x,y})),trollEntry];
    function route(a,b){
      const origin=Math.floor(a.y)*n+Math.floor(a.x),goal=Math.floor(b.y)*n+Math.floor(b.x),cost=new Float64Array(n*n),parent=new Int32Array(n*n),open=new G.Heap();
      cost.fill(Infinity);parent.fill(-1);cost[origin]=0;open.push({key:origin,g:0,f:0});
      while(open.items.length){
        const p=open.pop();if(p.g!==cost[p.key])continue;if(p.key===goal)break;
        const x=p.key%n,y=Math.floor(p.key/n);
        for(const [dx,dy]of [[1,0],[-1,0],[0,1],[0,-1]]){
          const xx=x+dx,yy=y+dy,key=yy*n+xx;if(xx<1||yy<1||xx>=n-1||yy>=n-1)continue;
          const next=p.g+(road[key] ? .7 : water[key] ? 9 : 1.3+noise[key]);if(next>=cost[key])continue;
          cost[key]=next;parent[key]=p.key;open.push({key,g:next,f:next+Math.hypot(xx-b.x,yy-b.y)*.7});
        }
      }
      if(parent[goal]===-1)throw Error('Road route failed for seed '+G.seed);
      const points=[];for(let k=goal;k!==-1;k=parent[k]){points.push([k%n,Math.floor(k/n)]);if(k===origin)break;}
      return points.reverse();
    }
    const connected=[nodes[0]],remaining=nodes.slice(1);
    while(remaining.length){
      let best={distance:Infinity};for(let i=0;i<remaining.length;i++)for(const from of connected){const distance=G.dist(from,remaining[i]);if(distance<best.distance)best={from,i,distance};}
      const to=remaining.splice(best.i,1)[0],points=route(best.from,to);level.roads.push(points);connected.push(to);
      points.forEach(([x,y],i)=>{
        road[y*n+x]=1;const before=points[Math.max(0,i-1)],after=points[Math.min(points.length-1,i+1)],axis=Math.abs(after[0]-before[0])>=Math.abs(after[1]-before[1])?'x':'y';
        for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){
          const t=G.tile(x+dx,y+dy);if(!t)continue;t.clearing=true;
          if(Math.abs(dx)>1||Math.abs(dy)>1)continue;
          if(t.kind==='water'&&water[y*n+x]){t.kind='bridge';t.bridgeAxis=axis;}
          else if(t.kind==='grass')t.kind='path';
        }
      });
    }
    for(const t of G.tiles){
      if(occupied.some(p=>Math.hypot(t.x+.5-p.x,t.y+.5-p.y)<p.radius))t.clearing=true;
      if(t.kind==='bridge')level.bridges.push({x:t.x,y:t.y,axis:t.bridgeAxis});
    }
    return {random:details,home,pineChance:range(.25,.85),forestPhase:[range(0,6.28),range(0,6.28),range(0,6.28)]};
  };
})();
