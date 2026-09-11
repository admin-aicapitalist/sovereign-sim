(function () {
  G.sprites = {};
  const S = G.sprites;
  function surface(w,h,scale=2) { const c=document.createElement('canvas'); c.width=Math.round(w*scale);c.height=Math.round(h*scale);const x=c.getContext('2d');x.scale(scale,scale);return {canvas:c,ctx:x,w,h}; }
  function poly(c,pts,fill,stroke) { c.beginPath();pts.forEach((p,i)=>i?c.lineTo(p[0],p[1]):c.moveTo(p[0],p[1]));c.closePath();c.fillStyle=fill;c.fill();if(stroke){c.strokeStyle=stroke;c.lineWidth=.6;c.stroke();} }
  function grad(c,x,y,x2,y2,a,b) { const g=c.createLinearGradient(x,y,x2,y2);g.addColorStop(0,a);g.addColorStop(1,b);return g; }
  function line(c,pts,color,width=1) { c.beginPath();pts.forEach((p,i)=>i?c.lineTo(...p):c.moveTo(...p));c.strokeStyle=color;c.lineWidth=width;c.stroke(); }
  function ellipse(c,x,y,rx,ry,color) { c.fillStyle=color;c.beginPath();c.ellipse(x,y,rx,ry,0,0,Math.PI*2);c.fill(); }
  function shadow(c,x,y,rx,ry){ellipse(c,x+5,y+2,rx,ry,'#14251c28');ellipse(c,x+3,y,rx*.75,ry*.73,'#13231f30');}
  function box(c,x,y,w,d,h,light='#c8c1a0',dark='#939680') {
    poly(c,[[x,y-h],[x+w,y+w*.5-h],[x+w,y+w*.5],[x,y]],grad(c,x,y-h,x+w,y,light,dark),'#454c4140');
    poly(c,[[x,y-h],[x-d,y+d*.5-h],[x-d,y+d*.5],[x,y]],grad(c,x-d,y-h,x,y,dark,'#777d69'),'#414d3b45');
    poly(c,[[x,y-h],[x+w,y+w*.5-h],[x+w-d,y+(w+d)*.5-h],[x-d,y+d*.5-h]],'#d7cbae','#766f5440');
    // Mortar joints, washed in the same warm directional light as the walls.
    c.save();c.globalAlpha=.13;
    for(let j=7;j<h;j+=8){line(c,[[x,y-j],[x+w,y+w*.5-j]],'#4c534a',.7);line(c,[[x,y-j],[x-d,y+d*.5-j]],'#394a40',.7);for(let k=8;k<w;k+=13)line(c,[[x+k,y+k*.5-j],[x+k,y+k*.5-j+5]],'#3e483e',.6);}
    c.restore();
  }
  function roof(c,x,y,w,d,rise,color='#5b818b') {
    const p=[[x,y],[x+w,y+w*.5],[x+w-d,y+(w+d)*.5],[x-d,y+d*.5]],a=[x+(w-d)*.5,y+(w+d)*.25-rise];
    poly(c,[p[0],p[1],a],grad(c,x,y-rise,x+w,y+20,color,'#426773'),'#314e575c');
    poly(c,[p[1],p[2],a],grad(c,x,y-rise,x,y+25,'#76959a',color),'#2d515753');
    poly(c,[p[2],p[3],a],grad(c,x-d,y-rise,x,y+30,color,'#36555d'),'#2e474c70');
    for(let i=1;i<6;i++){let t=i/6;line(c,[[G.lerp(a[0],p[2][0],t),G.lerp(a[1],p[2][1],t)],[G.lerp(a[0],p[3][0],t),G.lerp(a[1],p[3][1],t)]],'#d7e6d21a',.6);line(c,[[G.lerp(a[0],p[1][0],t),G.lerp(a[1],p[1][1],t)],[G.lerp(a[0],p[2][0],t),G.lerp(a[1],p[2][1],t)]],'#d7e6d224',.6);}
    line(c,[p[1],p[2],p[3]],'#2c4d50',1.4);line(c,[a,p[2]],'#9eb3a070',.8);return a;
  }
  function window(c,x,y,w=5,h=10,lit=true){c.fillStyle='#525e53';c.fillRect(x-1,y-1,w+2,h+2);c.fillStyle=lit?'#d3b77b':'#3e5550';c.beginPath();c.moveTo(x,y+h);c.lineTo(x,y+3);c.quadraticCurveTo(x+w/2,y-4,x+w,y+3);c.lineTo(x+w,y+h);c.fill();line(c,[[x+w/2,y+1],[x+w/2,y+h]],'#4d5a4d',.8);line(c,[[x,y+h/2],[x+w,y+h/2]],'#5d6351',.6);}
  function door(c,x,y,w=10,h=18){c.fillStyle='#65715e';c.beginPath();c.moveTo(x-w/2-2,y);c.lineTo(x-w/2-2,y-h+5);c.quadraticCurveTo(x,y-h-7,x+w/2+2,y-h+5);c.lineTo(x+w/2+2,y);c.fill();c.fillStyle=grad(c,x,y-h,x,y,'#263e36','#4d5040');c.beginPath();c.moveTo(x-w/2,y);c.lineTo(x-w/2,y-h+4);c.quadraticCurveTo(x,y-h-4,x+w/2,y-h+4);c.lineTo(x+w/2,y);c.fill();for(let i=-w/2+2;i<w/2;i+=3)line(c,[[x+i,y-2],[x+i,y-h+4]],'#a88b582a',.6);c.fillStyle='#c2a56c';c.fillRect(x+2,y-8,1.5,1.5);}
  function flag(c,x,y,color='#e5d1a0',side=1){line(c,[[x,y+25],[x,y-3]],'#695f45',1.2);poly(c,[[x,y],[x+side*16,y+2],[x+side*14,y+7],[x+side*17,y+12],[x,y+10]],grad(c,x,y,x+16,y,color,'#a58e5f'));line(c,[[x+3*side,y+2],[x+3*side,y+8]],'#f8e6b284',.7);ellipse(c,x,y-3,1.5,1.5,'#d0b67a');}
  function turret(c,x,y,size=23,h=43){box(c,x,y,size,size,h,'#d0c9aa','#929783');const a=roof(c,x,y-h-2,size,size,29,'#607f8a');window(c,x+size*.48,y-h+14,4,9);window(c,x-size*.55,y-h+12,4,9,false);line(c,[[a[0],a[1]],[a[0],a[1]-6]],'#d5c695',1);return a;}
  function timber(c,x,y,w,d,h){box(c,x,y,w,d,h,'#d2c3a0','#9a987b');line(c,[[x,y-h],[x,y]],'#655c43',3);line(c,[[x+w,y+w*.5-h],[x+w,y+w*.5]],'#75654a',2.5);line(c,[[x-d,y+d*.5-h],[x-d,y+d*.5]],'#625c44',2.5);for(let k=10;k<w;k+=12){line(c,[[x+k,y+k*.5-h],[x+k,y+k*.5]],'#766447',1.6);}line(c,[[x,y-h*.5],[x+w,y+w*.5-h*.5]],'#786847',2);line(c,[[x-d,y+d*.5-h*.5],[x,y-h*.5]],'#655d42',2);}
  function building(type){const o=surface(240,240),c=o.ctx;const x=120,y=163;shadow(c,x,y+23,78,30);
    // Stone foundations, scattered cobbles and small border plants.
    const r=G.rng(type.length*979+type.charCodeAt(0));ellipse(c,x,y+24,type==='palace'?88:65,32,'#b3aa7239');
    for(let i=0;i<38;i++){let a=r()*Math.PI*2,rr=.6+r()*.45;ellipse(c,x+Math.cos(a)*72*rr,y+25+Math.sin(a)*26*rr,1.4+r()*3,.7+r()*1.3,i%2?'#aeaf8990':'#757e6070');}
    if(type==='palace'){
      box(c,120,159,58,56,48);roof(c,120,107,58,56,37,'#597e87');
      turret(c,112,125,23,61);turret(c,67,155,24,50);turret(c,174,155,24,50);
      box(c,122,192,40,41,45,'#d4cbaa','#a0a18a');box(c,122,148,42,43,5,'#d6ceb1','#a6ac92');
      for(let k=0;k<4;k++){box(c,122+k*11,145+k*5.5,6,5,7,'#e1d7b8','#a7ad92');box(c,122-k*11,145+k*5.5,5,6,7,'#c6c7a8','#949e88');}
      door(c,142,211,16,27);window(c,127,171,6,12);window(c,148,180,5,10);
      box(c,78,190,22,21,48);roof(c,78,139,25,24,32,'#587d86');box(c,165,187,22,22,47);roof(c,165,137,25,25,32,'#638992');
      window(c,86,166,5,11);window(c,174,163,5,11);window(c,66,161,4,10,false);
      flag(c,113,29,'#ddc58f');flag(c,67,74,'#d6ba7d',-1);flag(c,174,74,'#e5ce97');
      poly(c,[[137,164],[149,170],[149,186],[143,191],[137,180]],'#3d6b78');line(c,[[143,171],[143,183]],'#d8c391',1.6);line(c,[[139,176],[147,180]],'#d8c391',1.5);
      for(let i=0;i<4;i++)poly(c,[[134-i*2,211+i*3],[150+i*2,219+i*3],[157+i*2,215+i*3],[141-i*2,207+i*3]],i%2?'#a2a48b':'#bcb99a');
    }else if(type==='warriors'){
      timber(c,119,177,45,42,44);roof(c,119,128,49,46,36,'#798c8a');box(c,159,171,21,20,51);roof(c,159,118,24,23,24,'#647f84');door(c,144,196,13,23);window(c,125,157,7,11);window(c,91,153,6,10,false);flag(c,159,77,'#cdad78');
      line(c,[[129,147],[142,158]],'#d1cfb4',2.5);line(c,[[142,146],[130,159]],'#d1cfb4',2.5);ellipse(c,138,153,5,6,'#516f77');
      for(let i=0;i<3;i++){line(c,[[75+i*9,184+i*4],[75+i*9,160+i*4]],'#826d49',2);line(c,[[71+i*9,168+i*4],[79+i*9,172+i*4]],'#a79b77',2);}
    }else if(type==='rangers'){
      timber(c,121,177,42,40,34);roof(c,121,138,47,44,36,'#708369');timber(c,88,171,24,22,27);roof(c,88,140,28,26,23,'#7b8d6d');door(c,140,196,11,21);window(c,122,159,6,9);flag(c,121,91,'#9ca56b');
      ellipse(c,75,195,10,13,'#9b9773');ellipse(c,75,194,7,10,'#c9bd8c');ellipse(c,75,194,4,6,'#89744f');ellipse(c,75,194,1.5,2.5,'#b6c18b');line(c,[[69,205],[67,214]],'#675f44',2);line(c,[[81,205],[84,214]],'#675f44',2);
    }else if(type==='thieves'){
      timber(c,121,177,42,40,39);roof(c,121,133,47,44,33,'#a07650');timber(c,85,160,23,23,61);roof(c,85,95,27,27,27,'#9b704c');door(c,141,195,12,22);window(c,121,155,6,10);poly(c,[[154,151],[169,158],[169,174],[154,167]],'#493e32');ellipse(c,159,158,2,2,'#c3ad73');line(c,[[160,160],[166,165]],'#c3ad73',1.5);
    }else if(type==='wizards'){
      box(c,127,180,31,30,84,'#b8b4a3','#868d86');roof(c,127,90,37,36,49,'#697493');box(c,101,177,27,25,34);roof(c,101,138,31,28,28,'#797f99');door(c,141,195,11,22);window(c,139,118,6,14);window(c,114,106,5,12);window(c,139,150,5,11);flag(c,127,35,'#bdacd1');ellipse(c,127,29,3,3,'#ddcfa0');
      poly(c,[[153,152],[164,157],[164,178],[158,181],[153,171]],'#686480');line(c,[[158,157],[158,173]],'#d5c996',1);line(c,[[155,163],[162,167]],'#d5c996',1);
    }else if(type==='marketplace'){
      timber(c,119,172,45,36,38);roof(c,119,130,49,40,29,'#ab8260');door(c,137,190,12,21);window(c,94,150,7,10);box(c,123,190,50,22,12,'#9e8055','#756746');
      const awn=[[109,156],[176,186],[176,167],[109,137]];poly(c,awn,'#dac494');for(let i=0;i<6;i++)if(i%2===0)poly(c,[[109+i*11,137+i*5],[120+i*11,142+i*5],[120+i*11,161+i*5],[109+i*11,156+i*5]],'#748c81');
      line(c,[[110,156],[110,193]],'#7b6544',2);line(c,[[176,185],[176,211]],'#7b6544',2);for(let i=0;i<16;i++)ellipse(c,120+r()*43,183+r()*14,2,1.7,i%2?'#d8ad65':'#a67a50');
      for(let i=0;i<3;i++){ellipse(c,82+i*9,191+i*5,8,5,'#93794e');c.fillStyle='#9c8057';c.fillRect(74+i*9,185+i*5,16,8);ellipse(c,82+i*9,185+i*5,8,4,'#b79b6a');line(c,[[75+i*9,187+i*5],[89+i*9,187+i*5]],'#5e6047',1.4);}
    }else if(type==='temple'){
      box(c,119,177,44,37,45,'#dfd3ae','#aaa991');roof(c,119,127,48,41,31,'#809589');box(c,96,176,21,23,70,'#d6ceb1','#a5a88d');roof(c,96,100,26,28,24,'#84998e');door(c,141,197,13,25);window(c,125,150,7,16);window(c,85,121,5,12);line(c,[[95,72],[95,58]],'#d6bd76',2.5);line(c,[[89,63],[101,69]],'#d6bd76',2.3);
    }else if(type==='tower'){
      box(c,120,189,22,23,74);box(c,120,114,29,30,13,'#c9c8ab','#9ca38a');roof(c,120,98,33,33,31,'#6d8e94');door(c,131,200,8,16);window(c,129,143,4,11);window(c,108,139,4,11,false);flag(c,120,59,'#d9c28b');
    }else if(type==='house'){
      timber(c,119,181,31,28,27);roof(c,119,148,36,33,28,'#aa8660');door(c,136,197,9,17);window(c,121,168,5,7);window(c,101,167,6,7);box(c,102,136,7,7,21,'#b4ac8e','#939780');
      line(c,[[156,188],[172,196],[172,206]],'#958c63',2);line(c,[[157,183],[157,199]],'#aaa17a',2);line(c,[[166,188],[166,203]],'#aaa17a',2);ellipse(c,94,198,10,4,'#748561');
    }else if(type==='goblin'){
      for(let i=0;i<11;i++){let px=68+i*9,py=178+Math.abs(i-5)*4;poly(c,[[px,py],[px,py-26],[px+3,py-32],[px+6,py-24],[px+6,py+2]],i%2?'#75694d':'#8c7a54');}
      poly(c,[[80,190],[123,118],[160,196],[120,213]],'#79664a','#4b533b');poly(c,[[123,118],[160,196],[120,213]],grad(c,120,120,150,200,'#a68d64','#7e7452'));poly(c,[[108,206],[123,157],[134,207],[120,213]],'#354333');line(c,[[123,118],[123,102]],'#a39871',2);flag(c,158,130,'#a7654b');ellipse(c,85,211,9,4,'#5b6246');
    }else if(type==='graveyard'){
      box(c,133,169,31,29,47,'#999e8c','#747f72');roof(c,133,117,35,34,31,'#657b7c');door(c,150,183,12,22);window(c,139,139,6,13,false);box(c,110,163,16,18,66,'#a5aa95','#7e8b7a');roof(c,110,91,20,22,19,'#6c7e7e');line(c,[[110,65],[110,53]],'#a1aa8e',2);line(c,[[105,57],[115,62]],'#a1aa8e',2);for(let i=0;i<7;i++){let px=72+(i%4)*20,py=185+Math.floor(i/4)*20;box(c,px,py,7,4,12,'#a8ab93','#7d8a75');line(c,[[px+3,py-9],[px+3,py-3]],'#78856e',1);line(c,[[px+1,py-7],[px+5,py-5]],'#78856e',1);}
    }else if(type==='sewer'){
      ellipse(c,120,193,39,20,'#546a51');poly(c,[[77,194],[83,165],[106,151],[141,163],[161,186],[145,208],[108,214]],grad(c,100,150,140,213,'#9da58a','#697b63'));c.fillStyle='#2e463b';c.beginPath();c.ellipse(124,192,20,14,-.2,Math.PI,Math.PI*2);c.lineTo(144,199);c.lineTo(104,207);c.closePath();c.fill();for(let i=0;i<6;i++)line(c,[[108+i*6,180],[108+i*6,204-i*1.2]],'#7b8772',2);ellipse(c,125,211,27,6,'#5b7f6a70');
    }
    return o;
  }
  function tree(kind,variant){const o=surface(112,156),c=o.ctx,r=G.rng(variant*792+kind.length*299);shadow(c,56,139,29,10);line(c,[[56,140],[54,73]],'#645e41',5);line(c,[[56,125],[73,98]],'#696044',2);line(c,[[54,116],[35,91]],'#716747',2);
    if(kind==='pine'){for(let i=0;i<6;i++){let yy=121-i*16,ww=38-i*5.7;poly(c,[[54,yy-39],[54-ww,yy+3],[45,yy],[56,yy+10],[65,yy+5],[54+ww,yy+5]],grad(c,25,yy-25,80,yy+15,'#60816b','#2f5a4b'));poly(c,[[54,yy-39],[54-ww,yy+3],[54,yy-4]],'#75917458');line(c,[[54-ww+3,yy+3],[45,yy]],'#91a68240',1);}}
    else {for(let i=0;i<48;i++){let a=r()*Math.PI*2,rr=Math.sqrt(r()),xx=54+Math.cos(a)*39*rr,yy=75+Math.sin(a)*40*rr;let sz=9+r()*9;ellipse(c,xx,yy,sz,sz*.84,yy<70?['#769367','#829c6b','#8da572','#71915f'][i%4]:['#5b7d56','#63885b','#6e8b5d','#4b7150'][i%4]);ellipse(c,xx-3,yy-4,sz*.6,sz*.45,'#b6bc7b18');}}
    return o;
  }
  function unit(type,frame,attack){const big=type==='troll',o=surface(64,76),c=o.ctx,d=G.UNITS[type],x=32,y=64,s=big?1.55:1;shadow(c,x,y,9*s,3*s);c.save();c.translate(x,y);c.scale(s,s);const step=[-2,0,2,0][frame],bob=frame%2?-.6:0;c.translate(0,bob);
    if(type==='rat'){ellipse(c,0,-5,9,5,'#776e5e');ellipse(c,-3,-7,6,4,'#978575');poly(c,[[5,-8],[12,-4],[6,-2]],'#998c75');ellipse(c,6,-8,3,3,'#a49b84');line(c,[[-8,-4],[-14,-7],[-16,-3]],'#9d8c78',1.5);line(c,[[-4,-1],[-6+step,1]],'#605d4c',2);line(c,[[5,-1],[7-step,1]],'#605d4c',2);ellipse(c,10,-5,.6,.6,'#b0bc82');}
    else {const hostile=d.hostile,cloth=d.color;line(c,[[-3,-11],[-4-step,0]],'#465449',3);line(c,[[3,-11],[4+step,0]],'#3a4c43',3);line(c,[[-5-step,0],[-2-step,0]],'#665e49',2.5);line(c,[[3+step,0],[6+step,0]],'#665e49',2.5);
      poly(c,[[-6,-24],[4,-25],[7,-10],[-6,-9]],grad(c,-6,-22,7,-9,cloth,hostile?'#566448':'#425d5a'));line(c,[[-4,-14],[5,-13]],'#a59161',2);
      ellipse(c,-1,-28,4.5,5,hostile?(type==='skeleton'?'#d7d0b4':'#93a370'):'#d4b78e');ellipse(c,-2,-29,2.2,3,'#ebcc9d3a');
      if(type==='warrior'||type==='guard'){poly(c,[[-6,-29],[-5,-34],[2,-35],[5,-30],[3,-27],[-5,-26]],grad(c,-5,-34,6,-26,'#d0d1bf','#849c9d'));line(c,[[2,-31],[2,-25]],'#6a858a',1.4);poly(c,[[-5,-23],[4,-23],[5,-16],[-4,-16]],'#a5b7b5');poly(c,[[-10,-23],[-3,-20],[-4,-10],[-9,-8],[-12,-17]],'#5d8291','#bed0bb');line(c,[[-9,-19],[-7,-12]],'#d9c798',1);const ax=attack?18:9,ay=attack?-24:-12;line(c,[[4,-22],[8,-18],[ax,ay]],'#b1b6a1',2.5);line(c,[[ax,ay],[attack?24:11,attack?-32:-32]],'#dce0c9',2);line(c,[[ax-3,ay-2],[ax+3,ay]],'#c4ae72',1.6);}
      else if(type==='ranger'){poly(c,[[-7,-28],[-3,-37],[4,-30],[3,-24]],'#78936c');poly(c,[[-6,-23],[-11,-7],[-2,-9]],'#587b5b');line(c,[[4,-22],[10,-17]],'#c4ac7e',2.5);c.beginPath();c.arc(8,-19,10,-1.2,1.2);c.strokeStyle='#bea270';c.lineWidth=1.5;c.stroke();line(c,[[11,-28],[attack?5:11,-19],[11,-10]],'#d4c89c',.6);if(attack)line(c,[[5,-19],[21,-20]],'#bfb999',1);}
      else if(type==='thief'){poly(c,[[-7,-28],[-2,-37],[5,-30],[3,-25]],'#494b50');poly(c,[[-7,-23],[-11,-7],[-2,-9]],'#3e4145');line(c,[[-4,-26],[3,-26]],'#484b50',3);line(c,[[4,-21],[attack?16:9,-17]],'#796c59',3);line(c,[[attack?16:9,-17],[attack?23:12,-25]],'#ced4cc',2);line(c,[[-7,-17],[-12,-23]],'#ced4cc',2);}
      else if(type==='wizard'){poly(c,[[-6,-24],[5,-24],[9,-4],[-10,-4]],grad(c,-6,-25,9,-4,'#aa9ab9','#696783'));poly(c,[[-9,-31],[7,-31],[0,-43]],'#8a83a5');line(c,[[-9,-31],[7,-31]],'#b3a4ba',1);poly(c,[[-4,-27],[2,-27],[-1,-19]],'#d3d0b7');line(c,[[5,-23],[11,-18]],'#baa3b8',3);line(c,[[12,-5],[12,-35]],'#ac966c',1.5);ellipse(c,12,-36,3,4,attack?'#f1c783':'#b9c3cf');}
      else if(type==='peasant'){poly(c,[[-7,-31],[6,-31],[2,-35],[-4,-35]],'#bfa879');line(c,[[4,-21],[9,-13]],'#c0ac82',3);line(c,[[8,-8],[13,-24]],'#947e56',1.5);line(c,[[9,-24],[17,-22]],'#9baba0',2.5);}
      else if(type==='collector'){poly(c,[[-7,-30],[6,-30],[3,-35],[-5,-35]],'#927947');ellipse(c,8,-13,5,6,'#b3975d');line(c,[[4,-21],[9,-17]],'#b9a071',3);}
      else {if(type==='skeleton'){line(c,[[-4,-22],[4,-18]],'#d5ccb0',2);line(c,[[-4,-18],[4,-15]],'#d5ccb0',2);ellipse(c,-2,-28,1,1,'#516051');ellipse(c,1,-28,1,1,'#516051');}if(type==='goblin')poly(c,[[-4,-30],[-12,-32],[-5,-25]],'#9da873');line(c,[[5,-22],[11,-13]],cloth,3);line(c,[[11,-13],[attack?24:15,attack?-22:-27]],type==='troll'?'#837147':'#bfc4a9',big?4:2);}
    }c.restore();return o;
  }
  G.makeSprites=function(){Object.keys(G.BUILDINGS).forEach(k=>S[k]=building(k));for(const type of Object.keys(G.UNITS)){delete S['idle_'+type];S['unit_'+type]=[];for(let f=0;f<4;f++)S['unit_'+type].push(unit(type,f,false));S['attack_'+type]=unit(type,1,true);}for(let i=0;i<6;i++){S['pine'+i]=tree('pine',i);S['oak'+i]=tree('oak',i);}S.flag=surface(64,82);shadow(S.flag.ctx,25,74,10,3);flag(S.flag.ctx,25,37,'#c17958');S.explore=surface(64,82);shadow(S.explore.ctx,25,74,10,3);flag(S.explore.ctx,25,37,'#d5ba79');};
  G.loadSpriteAssets=function(){
    if(typeof Image==='undefined')return Promise.resolve([]);
    const buildings=Object.entries(G.spriteAssets||{}).map(([key,asset])=>new Promise(resolve=>{
      const img=new Image();
      img.onload=()=>{
        // Keep the source texture's pixels while retaining its logical game size.
        const sprite=surface(asset.w,asset.h,Math.max(2,img.naturalWidth/asset.w));
        sprite.ctx.imageSmoothingEnabled=!asset.pixelArt;
        sprite.ctx.imageSmoothingQuality='high';
        sprite.ctx.drawImage(img,0,0,asset.w,asset.h);
        Object.assign(sprite,{anchor:asset.anchor,bounds:asset.bounds,pixelArt:asset.pixelArt,
          hitRows:asset.hitRows,effects:asset.effects,category:asset.category,assetLoaded:true});
        S[key]=sprite;resolve(true);
      };
      img.onerror=()=>{console.warn('Using procedural sprite fallback for '+key);resolve(false);};
      img.src=asset.src;
    }));
    const units=Object.entries(G.unitAssets||{}).map(([type,asset])=>new Promise(resolve=>{
      const img=new Image();
      const fallback=()=>{console.warn('Using procedural character fallback for '+type);resolve(false);};
      img.onload=()=>{
        if(img.naturalWidth!==asset.sourceSize[0]||img.naturalHeight!==asset.sourceSize[1])return fallback();
        // Poses share one native-resolution atlas. Each draw samples just its frame.
        const canvas=document.createElement('canvas');canvas.width=img.naturalWidth;canvas.height=img.naturalHeight;
        canvas.getContext('2d').drawImage(img,0,0);
        const frames=asset.frames.map(frame=>({canvas,w:asset.w,h:asset.h,anchor:asset.anchor,
          pixelArt:false,assetLoaded:true,selection:asset.selection,selectionRadius:asset.selectionRadius,
          healthOffset:asset.healthOffset,...frame}));
        S['idle_'+type]=frames[asset.animations.idle[0]];
        S['unit_'+type]=asset.animations.walk.map(i=>frames[i]);
        S['attack_'+type]=asset.animations.attack.map(i=>frames[i]);
        resolve(true);
      };
      img.onerror=fallback;img.src=asset.src;
    }));
    return Promise.all([...buildings,...units]);
  };
  G.buildingSpriteLayout=function(type){
    const sprite=S[type],scale=type==='palace'?1.03:.89,anchor=sprite.anchor||[120,211];
    return{sprite,scale,x:-anchor[0]*scale,y:-anchor[1]*scale,w:sprite.w*scale,h:sprite.h*scale};
  };
  G.unitSpriteLayout=function(u){
    const walk=S['unit_'+u.type],attack=S['attack_'+u.type];
    const working=u.type==='peasant'&&!u.path.length&&/^(Building|Repairing) /.test(u.state||'');
    let sprite=S['idle_'+u.type]||walk[1];
    if(u.attacking>0||working){
      const frame=working?Math.floor(G.time*7+(u.id||0))%3:Math.min(2,Math.floor((1-u.attacking/.34)*3));
      sprite=Array.isArray(attack)?attack[Math.max(0,frame)]:attack;
    }else if(u.path.length)sprite=walk[Math.floor(u.anim)%walk.length];
    const anchor=sprite.anchor||[32,64];
    return{sprite,x:-anchor[0],y:-anchor[1],w:sprite.w,h:sprite.h,
      selection:sprite.selection||[0,-17],selectionRadius:sprite.selectionRadius||20,
      healthOffset:sprite.healthOffset??-43};
  };
  G.paintSprite=function(ctx,sprite,x,y,w=sprite.w,h=sprite.h){
    if(sprite.frame)ctx.drawImage(sprite.canvas,...sprite.frame,x,y,w,h);
    else ctx.drawImage(sprite.canvas,x,y,w,h);
  };
  G.spriteContainsPoint=function(sprite,x,y){
    if(x<0||y<0||x>=sprite.w||y>=sprite.h)return false;
    // Exported row outlines also work with file://, where imported canvas pixels
    // cannot be read. Transparent roof corners should not intercept other buildings.
    if(sprite.hitRows){const row=sprite.hitRows[Math.floor(y)];return !!row&&x>=row[0]&&x<row[1];}
    if(sprite.assetLoaded)return true;
    const c=sprite.canvas,r=c.width/sprite.w;
    sprite.hitPixels=sprite.hitPixels||sprite.ctx.getImageData(0,0,c.width,c.height).data;
    return sprite.hitPixels[(Math.floor(y*r)*c.width+Math.floor(x*r))*4+3]>=96;
  };
  G.drawSprite=function(ctx,key,x,y,w,h){const s=S[key];if(s)ctx.drawImage(s.canvas,x,y,w||s.w,h||s.h);};
  G.art={poly,ellipse,line,grad};
})();
