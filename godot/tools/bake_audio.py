"""Bake the browser synth's notes/envelopes to sample-mode WAVs for Godot Web."""
from pathlib import Path
import math, random, struct, wave

OUT=Path(__file__).resolve().parents[1]/'assets/audio'
OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
def render(name, notes, noise=None, duration=None):
    end=duration or max((t+d+.05 for f,t,d,kind,v,last in notes),default=1)
    samples=[0.0]*math.ceil(end*RATE)
    for f,t,d,kind,volume,last in notes:
        phase=0.0
        for i in range(int(d*RATE)):
            time=i/RATE
            freq=f*((last/f)**(time/d)) if last else f
            phase+=freq/RATE
            tone=math.sin(phase*math.tau) if kind=='sine' else 2/math.pi*math.asin(math.sin(phase*math.tau))
            envelope=(.001*(volume/.001)**(time/.025)) if time<.025 else volume*(.001/volume)**((time-.025)/max(.001,d-.025))
            index=int(t*RATE)+i
            if index<len(samples):samples[index]+=tone*envelope*.24
    if noise:
        length,volume,freq=noise; rng=random.Random(41972); low=0.0
        alpha=1-math.exp(-math.tau*freq/RATE)
        for i in range(min(len(samples),int(length*RATE))):
            low+=alpha*((rng.random()*2-1)*(1-i/(length*RATE))-low)
            samples[i]+=low*volume*.24
    with wave.open(str(OUT/(name+'.wav')),'wb') as out:
        out.setparams((1,2,RATE,0,'NONE','not compressed'))
        out.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,s))*32767)) for s in samples))
def chord(notes,d=.5,v=.17,spacing=.1,kind='sine'):
    return [(f,i*spacing,d,kind,v,None) for i,f in enumerate(notes)]
render('select',[(560,0,.08,'sine',.12,None),(840,.035,.1,'sine',.08,None)])
render('coin',[(1300,0,.2,'sine',.16,None),(1950,.06,.25,'sine',.11,None)])
render('build',[(145,0,.12,'triangle',.26,75),(220,.11,.16,'triangle',.12,None)],(.17,.35,600))
render('hit',[(180,0,.08,'triangle',.16,65)],(.09,.25,1500))
render('bow',[(630,0,.07,'triangle',.1,180)],(.1,.2,2500),.15)
render('fire',[(130,0,.3,'sine',.16,430)],(.35,.23,1200),.4)
render('flag',chord([330,440,660],.35,.13,.07,'triangle'))
for name in ['level','complete','recruit']:render(name,chord([392,494,587,784]))
render('spell-lightning',[(85,0,.35,'triangle',.25,35),(1700,0,.12,'sine',.1,None)],(.24,.28,2600))
render('spell-frost',chord([1175,1568,2093],.55,.08,.07),(.4,.1,3200))
for name,notes in {'heal':[392,587,784],'ward':[294,440,587],'haste':[659,880,1318],'farsight':[440,660,990]}.items():
    render('spell-'+name,chord(notes,.85,.11,.1))
render('spell-meteor',[(320,0,.6,'triangle',.13,60)],(.6,.15,650))
render('meteor-impact',[(72,0,.55,'sine',.3,30)],(.6,.3,850),.65)
render('victory',chord([294,392,494,587,784],.9,.17,.15,'triangle'))
render('danger',chord([146,155,146],.65,.3,.5,'triangle'))
for index,notes in enumerate([[196,246.94,293.66,392],[174.61,220,261.63,349.23],[164.81,196,246.94,329.63],[146.83,196,220,293.66]]):
    tones=[]
    for i,f in enumerate(notes):tones.extend([(f,i*.35,5.5,'sine',.042,None),(f*2,i*.66+1,1.3,'triangle',.025,None)])
    for i in range(3):tones.append((1500+i*350,4+i*.16,.12,'sine',.018,2400+i*100))
    render('ambience_'+str(index),tones,duration=8)
print('Baked sound cues and four ambient chords using the original synth score.')
