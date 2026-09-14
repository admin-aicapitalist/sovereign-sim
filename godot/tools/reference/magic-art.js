(function(){
  // Painted light, mineral colors and engraved circles; all geometry is drawn at
  // the display resolution. Visual randomness never consumes the simulation RNG.
  const TAU=Math.PI*2,clamp=t=>Math.max(0,Math.min(1,t)),ease=t=>1-Math.pow(1-clamp(t),3);
  const {ellipse,line,poly}=G.art;
  const glows=new Map();
  function glow(c,x,y,r,color,alpha=1,flatten=1){
    if(r<=0||alpha<=0)return;
    let stamp=glows.get(color);
    if(!stamp){
      stamp=document.createElement('canvas');stamp.width=stamp.height=128;const s=stamp.getContext('2d');
      const g=s.createRadialGradient(64,64,0,64,64,64);g.addColorStop(0,color+'cc');g.addColorStop(.17,color+'80');g.addColorStop(.48,color+'26');g.addColorStop(1,color+'00');
      s.fillStyle=g;s.fillRect(0,0,128,128);
      const rng=G.rng(719);s.globalCompositeOperation='destination-out';
      for(let i=0;i<900;i++){s.fillStyle='rgba(0,0,0,'+(rng()*.16)+')';s.fillRect(rng()*128,rng()*128,1+rng()*2,1+rng()*2);}
      glows.set(color,stamp);
    }
    c.save();c.globalAlpha*=alpha;c.drawImage(stamp,x-r,y-r*flatten,r*2,r*2*flatten);c.restore();
  }
  function arc(c,x,y,r,color,angle=0,span=TAU,width=1,flatten=.5){
    c.strokeStyle=color;c.lineWidth=width;c.beginPath();c.ellipse(x,y,r,r*flatten,0,angle,angle+span);c.stroke();
  }
  function sigil(c,x,y,r,color,rotation,alpha=1){
    c.save();c.globalAlpha*=alpha;arc(c,x,y,r,color,0,TAU,1.1);arc(c,x,y,r*.88,color,0,TAU,.6);
    for(let i=0;i<12;i++){
      const a=rotation+i*TAU/12,co=Math.cos(a),si=Math.sin(a),xx=x+co*r*.95,yy=y+si*r*.475;
      line(c,[[x+co*r*.9,y+si*r*.45],[x+co*r,y+si*r*.5]],color,1);
      if(i%3===0)poly(c,[[xx,yy-3],[xx+2,yy],[xx,yy+3],[xx-2,yy]],color);
    }
    for(let i=0;i<2;i++){
      const points=Array.from({length:4},(_,n)=>{const a=rotation+i*Math.PI+n*TAU/3;return[x+Math.cos(a)*r*.7,y+Math.sin(a)*r*.35];});line(c,points,color,.75);
    }
    c.restore();
  }
  function star(c,x,y,r,color){
    poly(c,[[x,y-r],[x+r*.2,y-r*.2],[x+r,y],[x+r*.2,y+r*.2],[x,y+r],[x-r*.2,y+r*.2],[x-r,y],[x-r*.2,y-r*.2]],color);
  }
  function ice(c,x,y,h,rng){
    const w=3+h*.1,lean=(rng()-.5)*w,tip=[x+lean,y-h];
    const g=c.createLinearGradient(x-w,y-h,x+w,y);g.addColorStop(0,'#d5e3df');g.addColorStop(.4,'#90b7c1');g.addColorStop(1,'#617f8a70');
    c.save();poly(c,[[x-w,y-1],tip,[x+w*.7,y-h*.22],[x+w,y+1],[x,y+3]],g);
    c.clip();
    poly(c,[tip,[x+w*.7,y-h*.22],[x+w,y+1],[x+1,y]],'#b9d6d38c');
    for(let j=0;j<18;j++){const yy=y-rng()*h,xx=x+(rng()-.5)*w*2;ellipse(c,xx,yy,.3+rng(),.4+rng()*1.8,j%2?'#e8efe226':'#47677524');}
    line(c,[[x-w*.4,y-h*.35],[x+1,y-h*.5],[x+lean*.7,y-h*.8]],'#e4eee36b',.55);
    c.restore();line(c,[[x-w,y-1],tip,[x+w*.7,y-h*.22]],'#c8dbd5a0',.65);glow(c,x,y,w*4,'#98bac4',.4,.45);
  }
  function dust(c,rng,r,t,color,n=32,rise=55){
    for(let i=0;i<n;i++){
      const a=rng()*TAU,d=Math.sqrt(rng())*r,s=.5+rng()*1.3,phase=(t+rng()*.6)%1;
      const x=Math.cos(a)*d,y=Math.sin(a)*d*.5-phase*rise;
      c.save();c.globalAlpha*=Math.sin(phase*Math.PI)*.85;
      glow(c,x,y,s*5,color,.55);ellipse(c,x,y,s,s*.65,color);
      if(i%7===0)star(c,x,y,s*2,'#eee5bd');c.restore();
    }
  }
  function lightning(c,rng,age){
    const pulse=(Math.exp(-age*7)+.55*Math.exp(-Math.pow((age-.19)*24,2)));
    c.save();c.globalAlpha*=pulse;
    const points=[[0,-230]];for(let i=1;i<8;i++)points.push([(rng()-.5)*34,-230+i*29]);points.push([0,-8]);
    c.lineJoin='round';line(c,points,'#819fad30',20);line(c,points,'#9cbfc673',8);line(c,points,'#cee0d7',2.7);line(c,points,'#fff3d0',.9);
    for(let i=2;i<7;i+=2){const [x,y]=points[i],side=i%4?1:-1,branch=[[x,y],[x+side*24,y+10],[x+side*13,y+30],[x+side*43,y+49]];line(c,branch,'#9cbfc658',6);line(c,branch,'#d5e1d5',1);}
    glow(c,0,-8,66,'#b9d4d4',.85);c.restore();
    arc(c,0,0,10+ease(age*2)*87,'#b5c9c3',0,TAU,1.2);glow(c,0,0,90,'#a9c7c6',.35,.5);
  }
  G.magicArt={
    effect(c,e,age){
      const d=G.SPELLS[e.spell];if(!d||age<0||age>e.life)return;
      const t=age/e.life,p=G.iso(e.x,e.y),r=d.radius*Math.SQRT2*G.TW/2,rng=G.rng(Math.floor(e.seed*999999));
      c.save();c.translate(p.x,p.y);c.globalAlpha*=Math.min(1,(1-t)*3);c.lineCap='round';
      if(e.caster&&age<.5){const origin=G.iso(e.caster.x,e.caster.y);glow(c,origin.x-p.x,origin.y-p.y-29,24,d.color,1-age*2);sigil(c,origin.x-p.x,origin.y-p.y,19,d.color,age,1-age*2);}
      if(e.spell==='lightning')lightning(c,rng,age);
      if(e.spell==='heal'){
        const spread=ease(age*2);glow(c,0,0,r,'#c2c68c',.5,.5);sigil(c,0,0,r*.7*spread,'#d4c38d',age*.13,.8);
        for(let i=0;i<7;i++){
          const a=i*TAU/7,xx=Math.cos(a)*r*.42,yy=Math.sin(a)*r*.21,h=70+15*Math.sin(i);
          const g=c.createLinearGradient(xx,yy,xx,yy-h);g.addColorStop(0,'#ded2a830');g.addColorStop(1,'#ded2a800');
          poly(c,[[xx-6,yy],[xx+6,yy],[xx+13,yy-h],[xx-13,yy-h]],g);
        }
        dust(c,rng,r*.65,t,'#d6dfac',48,75);
      }
      if(e.spell==='frost'){
        const spread=ease(age*2.8);glow(c,0,0,r*spread,'#93bdc5',.7,.5);sigil(c,0,0,r*.78,'#accccc',0,.35);
        arc(c,0,0,r*spread,'#c8dedd',0,TAU,2*(1-t)+.5);
        for(let i=0;i<24;i++){
          const a=i*TAU/24+rng()*.15,dist=r*(.25+rng()*.6)*spread,xx=Math.cos(a)*dist,yy=Math.sin(a)*dist*.5,h=(8+rng()*25)*Math.sin(Math.PI*Math.min(.95,age*.8));
          ice(c,xx,yy,h,rng);
        }
        dust(c,rng,r*.8,t,'#c7dfda',32,30);
      }
      if(e.spell==='ward'){
        glow(c,0,0,r,'#bda56b',.5,.5);sigil(c,0,0,r*.8*ease(age*3),'#d4bd83',age*.1,.8);
        c.save();c.globalAlpha*=.32*Math.sin(Math.PI*t);const dome=c.createRadialGradient(-r*.2,-35,8,0,-20,r*.7);dome.addColorStop(0,'#edddb57a');dome.addColorStop(.7,'#b39c4d08');dome.addColorStop(1,'#d8c18080');
        ellipse(c,0,-20,r*.72,r*.5,dome);arc(c,0,-20,r*.72,'#d5bd83',Math.PI,Math.PI,1,.7);c.restore();
        dust(c,rng,r*.6,t,'#ddca8f',25,50);
      }
      if(e.spell==='haste'){
        glow(c,0,0,r,'#a7bb94',.35,.5);
        for(let i=0;i<5;i++){
          const rr=r*(.25+i*.13),a=age*(2+i*.15)+i*1.4;
          arc(c,0,-i*7,rr,i%2?'#d6c898':'#a7c4ad',a,Math.PI*.75,1.5-i*.15);
          const x=Math.cos(a+Math.PI*.75)*rr,y=-i*7+Math.sin(a+Math.PI*.75)*rr*.5;
          star(c,x,y,3,'#e5dab0');
        }
        dust(c,rng,r*.5,t,'#ced9b2',25,35);
      }
      if(e.spell==='farsight'){
        const rr=Math.min(r,230)*ease(age*1.8);glow(c,0,0,rr,'#a2b6af',.22,.5);
        sigil(c,0,0,rr,'#c4bd94',age*.07,.6);
        c.save();c.translate(0,-35-age*9);c.strokeStyle='#e0d0a0';c.lineWidth=1.4;c.beginPath();c.moveTo(-26,0);c.quadraticCurveTo(0,-23,26,0);c.quadraticCurveTo(0,23,-26,0);c.stroke();arc(c,0,0,7,'#e0d0a0',0,TAU,1,1);star(c,0,0,4,'#eee4bc');glow(c,0,0,35,'#bdcbb8',.4);c.restore();
        dust(c,rng,rr*.8,t,'#d8d1aa',28,25);
      }
      if(e.spell==='meteor'){
        if(age<d.delay){
          sigil(c,0,0,r*.83,'#cb945f',0,.7);glow(c,0,0,r,'#b76b43',age*.8,.5);
          const q=clamp(age/d.delay),x=-185*(1-q),y=-320*(1-q)-9;
          const trail=c.createLinearGradient(x,y,x-80,y-140);trail.addColorStop(0,'#f0c58c');trail.addColorStop(.2,'#cf8c4baf');trail.addColorStop(.65,'#a7613940');trail.addColorStop(1,'#a7613900');
          poly(c,[[x-14,y+5],[x+13,y-8],[x-70,y-152],[x-52,y-115],[x-93,y-130],[x-62,y-70]],trail);
          for(let i=9;i>=0;i--){const xx=x-i*10,yy=y-i*17;glow(c,xx,yy,8+(9-i)*1.2,i<3?'#f0bd76':'#b87952',.55*(1-i/11));}
          const rock=c.createRadialGradient(x-6,y-8,1,x,y,22);rock.addColorStop(0,'#c6a17e');rock.addColorStop(.35,'#876247');rock.addColorStop(1,'#302d2b');
          poly(c,[[x-14,y-9],[x-5,y-22],[x+10,y-15],[x+16,y+2],[x+3,y+12],[x-10,y+6]],rock,'#e3b477');
          poly(c,[[x-14,y-9],[x-5,y-22],[x+1,y-7],[x-10,y+6]],'#cda67870');
          line(c,[[x-7,y-13],[x-2,y-3],[x+6,y-7],[x+13,y+3]],'#e6a968',2);line(c,[[x-2,y-3],[x-5,y+7]],'#ebbb7d',1.3);glow(c,x,y,32,'#ecc084',.8);
        }else{
          const q=(age-d.delay)/(e.life-d.delay),spread=ease(q*3);
          glow(c,0,0,r,'#bc7748',.65*(1-q),.5);glow(c,0,-8,70*(1-q),'#efcc8d',Math.exp(-q*8));
          for(let i=0;i<9;i++){const a=i*TAU/9,rr=20+q*45,xx=Math.cos(a)*rr,yy=Math.sin(a)*rr*.4-q*28;glow(c,xx,yy,22+q*15,i%2?'#b87b49':'#e1ad63',Math.exp(-q*7)*.8);}
          arc(c,0,0,r*spread,'#cf9c67',0,TAU,2*(1-q));
          for(let i=0;i<38;i++){
            const a=rng()*TAU,v=20+rng()*r,xx=Math.cos(a)*v*spread,yy=Math.sin(a)*v*.5*spread-Math.sin(q*Math.PI)*45*rng(),s=1+rng()*3;
            if(i<13){glow(c,xx,yy,12+q*24,'#706b59',.28*(1-q));ellipse(c,xx,yy,s*1.7,s,'#73624b60');}
            else {glow(c,xx,yy,s*4,'#c99758',.7);poly(c,[[xx-s,yy],[xx,yy-s*2],[xx+s,yy],[xx,yy+s]],i%3?'#d4a164':'#ecd19c');}
          }
        }
      }
      c.restore();
    },
    aura(c,u,p){
      const b=u.magicBuffs,t=G.time;if(!b)return;c.save();
      if(b.ward>0){c.globalAlpha=Math.min(1,b.ward);glow(c,p.x,p.y-21,34,'#c7ac70',.18);arc(c,p.x,p.y-21,16,'#c5ae7370',0,TAU,.8,1.4);sigil(c,p.x,p.y+1,19,'#c8b47d',t*.12,.6);}
      if(b.haste>0){c.globalAlpha=Math.min(.65,b.haste);for(let i=0;i<2;i++)arc(c,p.x,p.y-i*12,17,'#c7d0a5',t*3+i*Math.PI,Math.PI*.7,1,.4);}
      if(b.frost>0){c.globalAlpha=Math.min(.75,b.frost);glow(c,p.x,p.y,22,'#a5cacf',.35,.5);for(let i=0;i<5;i++){const a=i*TAU/5;const x=p.x+Math.cos(a)*13,y=p.y+Math.sin(a)*5;poly(c,[[x-2,y],[x,y-7],[x+2,y+1]],'#bdd8d6');}}
      c.restore();
    },
    projectile(c,p,a,b){
      const angle=Math.atan2(b.y-a.y,b.x-a.x),dx=Math.cos(angle),dy=Math.sin(angle);
      for(let i=5;i>=0;i--){const x=a.x-dx*i*5,y=a.y-19-dy*i*5;glow(c,x,y,9-i*.8,i<2?'#e1b46e':'#b3734c',.65-i*.07);if(i%2===0)ellipse(c,x+Math.sin(G.time*17+i)*2,y,1,1,'#dab16f');}
      ellipse(c,a.x,a.y-19,3.5,3,'#f1d6a1');
    },
    target(c,key,p,valid){
      const d=G.SPELLS[key],r=d.radius*Math.SQRT2*G.TW/2,color=valid?d.color:'#b27464';
      c.save();c.globalAlpha=.65;arc(c,p.x,p.y,r,color,0,TAU,1.2);arc(c,p.x,p.y,r-4,color,0,TAU,.5);
      for(let i=0;i<4;i++){const a=i*TAU/4;star(c,p.x+Math.cos(a)*r,p.y+Math.sin(a)*r*.5,4,color);}star(c,p.x,p.y,5,color);c.restore();
    }
  };
})();
