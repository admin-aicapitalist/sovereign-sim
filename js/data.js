(function () {
  G.MAP = 88;
  G.ZOOM_MIN = .35; G.ZOOM_MAX = 2.1;
  G.LEVEL = {
    lairs: [
      {type:'sewer',x:8,y:11,name:'The Old Sewer'},
      {type:'graveyard',x:29,y:8,name:'Haunted Graveyard'},
      {type:'goblin',x:8,y:28,name:'Western Goblin Camp'},
      {type:'goblin',x:36,y:30,name:'Eastern Goblin Camp'},
      {type:'goblin',x:68,y:18,name:'Pinewatch Camp',frontier:true},
      {type:'sewer',x:67,y:47,name:'Reedwater Sewer',frontier:true},
      {type:'graveyard',x:52,y:70,name:'Ashen Graveyard',frontier:true},
      {type:'goblin',x:17,y:67,name:'Southwood Camp',frontier:true}
    ],
    clearings: [[51,23,6],[48,44,6],[21,48,7],[70,73,7]],
    roads: [
      [[20,32],[20,47],[20,70],[7,78]],
      [[20,47],[35,47],[48,47],[68,47],[79,38]],
      [[36,20],[51,20],[69,19],[80,10]],
      [[36,31],[49,33],[51,20]],
      [[49,33],[48,47],[46,60],[48,71],[70,73],[81,80]],
      [[20,70],[35,70],[48,71]]
    ]
  };
  G.BUILDINGS = {
    palace: { name:'Royal Palace', subtitle:'The heart of your kingdom', hp:2600, size:3, cost:0, sight:12, tax:9, description:'Your seat of power. Peasants and tax collectors serve the crown, while royal guards defend its gates.' },
    warriors: { name:'Warriors’ Guild', short:'Warriors’ Guild', subtitle:'Where courage finds a home', hp:850, size:2, cost:350, sight:7, buildTime:15, recruits:'warrior', capacity:4, description:'Recruits stalwart warriors. Brave, heavily armored heroes who favor attack bounties and a good brawl.' },
    rangers: { name:'Rangers’ Lodge', short:'Rangers’ Lodge', subtitle:'For those who wander', hp:650, size:2, cost:300, sight:9, buildTime:13, recruits:'ranger', capacity:4, description:'Recruits keen-eyed rangers. Independent explorers who fight from afar and eagerly follow exploration flags.' },
    wizards: { name:'Wizards’ Guild', short:'Wizards’ Guild', subtitle:'Knowledge is a kind of power', hp:580, size:2, cost:500, sight:7, buildTime:19, recruits:'wizard', capacity:4, description:'Recruits wizards and unlocks Lightning Bolt. Their fireballs strike hard, but they need protection.' },
    marketplace: { name:'Marketplace', short:'Marketplace', subtitle:'A little trade, a little prosperity', hp:700, size:2, cost:250, sight:6, buildTime:12, tax:6, description:'Sells healing potions to heroes. Their spending becomes tax revenue, delivered to your treasury by collectors.' },
    temple: { name:'Temple of Light', short:'Temple', subtitle:'A sanctuary for the weary', hp:900, size:2, cost:400, sight:7, buildTime:17, description:'Unlocks Healing Light. Heroes recover faster near the temple and can return to their adventures sooner.' },
    tower: { name:'Guard Tower', short:'Guard Tower', subtitle:'An ever-watchful eye', hp:800, size:1, cost:200, sight:9, buildTime:11, damage:21, range:7, attackRate:1.4, description:'Shoots approaching monsters. A wise investment near your borders, and an excellent answer to trolls.' },
    house: { name:'Peasant Cottage', short:'Cottage', subtitle:'A place to call home', hp:320, size:1, cost:100, sight:5, buildTime:8, tax:3, description:'A warm home for your subjects. Produces a small, steady stream of taxable income.' },
    sewer: { name:'The Old Sewer', subtitle:'Something stirs below', hp:680, size:2, hostile:true, interval:52, spawn:'rat', reward:180, description:'A forgotten drain teeming with giant rats. Destroy it to make the kingdom safer.' },
    graveyard: { name:'Haunted Graveyard', subtitle:'No rest for the wicked', hp:1050, size:2, hostile:true, interval:60, spawn:'skeleton', reward:260, description:'Restless skeletons rise beneath the old chapel. Its ancient stones must fall.' },
    goblin: { name:'Goblin Camp', subtitle:'Unwelcome neighbors', hp:880, size:2, hostile:true, interval:56, spawn:'goblin', reward:220, description:'A crude goblin stronghold. It calls defenders when attacked; send heroes with a generous bounty.' }
  };
  G.UNITS = {
    warrior:{name:'Warrior',hp:220,damage:23,range:1.25,speed:1.5,rate:1.15,cost:100,armor:4,sight:7,bravery:1.3,affinity:1.3,color:'#7197ae',hero:true},
    ranger:{name:'Ranger',hp:135,damage:17,range:5.5,speed:1.85,rate:1.15,cost:110,armor:1,sight:10,bravery:.95,affinity:.85,color:'#82a76c',hero:true},
    wizard:{name:'Wizard',hp:105,damage:42,range:5.8,speed:1.45,rate:2,cost:160,armor:0,sight:7,bravery:.85,affinity:1.15,color:'#a99bc5',hero:true},
    guard:{name:'Palace Guard',hp:210,damage:17,range:1.35,speed:1.5,rate:1.25,armor:4,sight:6,color:'#92aeb2'},
    peasant:{name:'Peasant',hp:75,damage:3,range:1,speed:1.45,rate:2,armor:0,sight:5,color:'#c3b083'},
    collector:{name:'Tax Collector',hp:95,damage:0,range:0,speed:1.7,rate:2,armor:0,sight:4,color:'#b29258'},
    rat:{name:'Giant Rat',hp:40,damage:5,range:1,speed:1.7,rate:1.4,armor:0,sight:5,color:'#938574',hostile:true,loot:13,xp:12},
    goblin:{name:'Goblin Raider',hp:80,damage:10,range:1.1,speed:1.55,rate:1.5,armor:1,sight:6,color:'#8ca56b',hostile:true,loot:22,xp:20},
    skeleton:{name:'Restless Skeleton',hp:90,damage:12,range:1.2,speed:1.25,rate:1.6,armor:2,sight:6,color:'#d4ccb0',hostile:true,loot:26,xp:24},
    troll:{name:'Hill Troll',hp:850,damage:36,range:1.6,speed:1.05,rate:2,armor:5,sight:9,color:'#758b63',hostile:true,loot:170,xp:120}
  };
  G.SPELLS = {
    heal:{name:'Healing Light',cost:65,cooldown:14,requires:'temple',symbol:'✥',description:'Restore 130 health to friendly units and buildings in a small area. Requires a completed Temple.'},
    lightning:{name:'Lightning Bolt',cost:90,cooldown:9,requires:'wizards',symbol:'ϟ',description:'Strike a monster or lair for 190 damage, with a smaller blast around it. Requires a completed Wizards’ Guild.'},
    farsight:{name:'Far Sight',cost:35,cooldown:18,symbol:'◉',description:'Lift the fog over a distant area for 45 seconds. Knowledge is the first step to conquest.'}
  };
  G.NAMES = { warrior:['Aldric the Bold','Bram Ironheart','Ser Cedric','Elara Brightblade','Oswin the Stout','Rowan Ashford','Freya the Fearless','Sir Peregrin'], ranger:['Wren Farwalker','Robin of the Vale','Ivy Greenmantle','Finn Swiftarrow','Hazel Woodward','Lark the Keen'], wizard:['Orin the Wise','Mira Starweaver','Althea Moonfall','Erasmus the Odd','Sylas Emberhand'] };
  G.TIPS = ['A kingdom needs heroes, Your Majesty. Start with a Warriors’ Guild.','Heroes choose their own adventures. A gold bounty makes yours more tempting.','Build a Marketplace. Heroes buy potions, and their coin comes home as taxes.','Rangers love to wander. Exploration flags help them find the places you care about.','Your peasants repair damaged buildings. Give them time, and keep the monsters away.','The Temple unlocks Healing Light. A timely blessing can turn a desperate battle.','A Guard Tower is a comfort. Two are a rather firmer statement.','Select a bounty flag to raise its reward. Great danger deserves great incentive.','Eight lairs stand between us and peace. Follow the roads into the frontier.'];
})();
