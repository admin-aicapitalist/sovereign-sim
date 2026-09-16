"""Original layered spell and combat Foley, synthesized offline; no external samples.

Deterministic modal bells, filtered air, bowed resonances, transient impacts and
short stereo early reflections. WAVs use Godot's browser-compatible sample mode.
"""
import json, math, random, struct, wave
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio/arcane'; OUT.mkdir(parents=True,exist_ok=True)
RATE=32000
TAU=math.tau
report={}

def bake(key,duration,tones=(),winds=(),gain=.65,reverb=.16):
    samples=[0.0]*round(duration*RATE)
    for freq,end,start,length,volume,attack,partials in tones:
        phase=0.0
        for i in range(min(round(length*RATE),len(samples)-round(start*RATE))):
            t=i/RATE; p=t/length
            phase+=TAU*freq*(end/freq)**p/RATE
            envelope=min(1,t/max(.001,attack))*math.exp(-p*5)*(1-p)**.4
            value=sum(weight*math.sin(phase*ratio) for ratio,weight in partials)
            samples[round(start*RATE)+i]+=value*envelope*volume
    for start,length,volume,cutoff,sweep,attack in winds:
        rng=random.Random(key+str(start)); low=0.0; deep=0.0
        for i in range(min(round(length*RATE),len(samples)-round(start*RATE))):
            t=i/RATE; p=t/length
            coefficient=1-math.exp(-TAU*cutoff*(sweep/cutoff)**p/RATE)
            low+=coefficient*(rng.uniform(-1,1)-low); deep+=.028*(low-deep)
            envelope=min(1,t/max(.001,attack))*(1-p)**2
            samples[round(start*RATE)+i]+=(low*.75+deep*.65)*envelope*volume
    left=samples.copy(); right=samples.copy()
    for delay,volume in [(.037,.41),(.073,.33),(.113,.27),(.173,.19),(.271,.10)]:
        for channel,offset in [(left,0),(right,.013)]:
            shift=round((delay+offset)*RATE)
            for i in range(shift,len(samples)): channel[i]+=samples[i-shift]*volume*reverb
    peak=max(abs(s) for channel in (left,right) for s in channel)
    scale=min(1,gain/max(.001,peak))
    pcm=bytearray()
    for l,r in zip(left,right): pcm.extend(struct.pack('<hh',round(l*scale*32767),round(r*scale*32767)))
    with wave.open(str(OUT/f'{key}.wav'),'wb') as out:
        out.setparams((2,2,RATE,0,'NONE','not compressed')); out.writeframes(pcm)
    report[key]={'seconds':duration,'peak':round(peak*scale,4),'rms':round(math.sqrt(sum((s*scale)**2 for s in left)/len(left)),4),'bytes':len(pcm)+44}

SINE=[(1,1)]
BRONZE=[(1,.65),(2.71,.20),(4.08,.10),(5.43,.035)]
GLASS=[(1,.7),(2.02,.14),(3.93,.08),(5.19,.03)]
def bell(f,t=0,d=1,v=.15): return (f,f*.998,t,d,v,.007,BRONZE)
def tone(f,end,t,d,v,attack=.006,partials=SINE): return (f,end,t,d,v,attack,partials)

bake('spell-heal',1.8,[bell(f,i*.095,1.3,.14) for i,f in enumerate([392,587.33,783.99,1174.66])]+[tone(196,196,0,1.4,.09,.18)],[(0,.95,.19,1500,3100,.18)],reverb=.4)
bake('spell-ward',1.8,[bell(293.66,0,1.4,.19),bell(440,.08,1.3,.12),bell(880,.19,1.1,.09),tone(98,147,0,.55,.2,.035)],[(0,.65,.24,750,2700,.05)],reverb=.35)
bake('spell-haste',1.3,[tone(f,f*1.12,i*.08,.55,.13,.03,GLASS) for i,f in enumerate([659.25,880,1318.51])],[(0,.52,.4,750,5100,.04),(.14,.6,.14,1500,4100,.06)],reverb=.2)
bake('spell-farsight',2.5,[tone(f,f, i*.13,1.8,.105,.12,GLASS) for i,f in enumerate([220,329.63,493.88,659.25,987.77])],[(.05,1.45,.2,1500,4500,.3)],reverb=.48)
bake('spell-frost',1.8,[tone(f,f*.92,i*.033,.72,.10,.002,GLASS) for i,f in enumerate([1568,2093,2349,1175,3136,1760])]+[tone(240,120,0,.32,.18)],[(0,.65,.6,6300,1400,.004)],reverb=.3)
bake('spell-lightning',1.25,[tone(95,33,0,.75,.32),tone(2300,510,0,.07,.13),tone(71,31,.18,.6,.11)],[(0,.25,.86,7400,800,.001),(.17,.12,.45,5900,1400,.001),(.25,.7,.23,310,90,.005)],gain=.72,reverb=.3)
bake('spell-meteor',.68,[tone(530,80,0,.65,.20,.06),tone(126,51,.08,.57,.14,.04)],[(0,.65,.63,3200,550,.045)],gain=.60,reverb=.04)
bake('meteor-impact',2.5,[tone(83,29,0,1.3,.51),tone(146,47,0,.42,.21),tone(47,28,.12,1.5,.18)],[(0,.30,.88,4800,600,.001),(.02,1.3,.7,450,80,.005),(.17,1.4,.20,1800,350,.05)],gain=.78,reverb=.42)
bake('fire',.58,[tone(180,510,0,.33,.15,.025)],[(0,.45,.7,650,2600,.015)],gain=.52,reverb=.1)
bake('fire-impact',.95,[tone(143,49,0,.5,.3),tone(67,35,0,.6,.14)],[(0,.38,.62,2800,380,.002),(.08,.6,.13,2200,1100,.025)],gain=.56,reverb=.18)
bake('bow',.32,[tone(460,115,0,.13,.17,.001,BRONZE)],[(0,.09,.37,7500,1700,.001),(.025,.19,.13,2400,1300,.004)],gain=.42,reverb=.04)
bake('shield-hit',.85,[bell(698.46,0,.6,.23),bell(1396.91,.012,.48,.09),tone(230,150,0,.12,.16)],[(0,.1,.39,4900,1500,.001)],gain=.57,reverb=.32)
for variant in range(3):
    f=840+variant*113
    bake(f'combat-metal-{variant}',.56,[tone(f,f*.96,0,.34,.2,.001,BRONZE),tone(210,81,0,.11,.17)],[(0,.085,.6,5100+variant*200,1700,.001)],gain=.5,reverb=.13)
    bake(f'combat-body-{variant}',.35,[tone(160+variant*19,53,0,.16,.3)],[(0,.12,.63,1200+variant*200,360,.001),(.022,.16,.2,2400,1000,.004)],gain=.44,reverb=.05)
(ROOT/'reports/arcane-audio.json').write_text(json.dumps(report,indent=2)+'\n')
print(f'Baked {len(report)} original stereo cues; {sum(v["bytes"] for v in report.values())/1e6:.2f} MB; all peaks below 0.8.')
