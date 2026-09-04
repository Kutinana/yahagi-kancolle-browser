const fs = require('fs'), path = require('path');
// Usage: node tool/battle_detail_poi_oracle.cjs LIB_ROOT [FIXTURE_ROOT] [CAPTURE]
// Reads captures and emits oracle output only. Does not modify the database.
const root = path.resolve(process.argv[2]);
const lib = require(root);
const output = [];
const fixtureRoot = process.argv[3];
function inspect(name, j) {
  const packets = j.packet.filter(p => !/battleresult|battle_result/.test(p.poi_path) && /battle|ld_shooting/.test(p.poi_path));
  const s = lib.Simulator.auto(new lib.Battle({...j, packet: packets}), {usePoiAPI: false});
  const fleetArrays = [s.mainFleet, s.escortFleet, s.enemyFleet, s.enemyEscort];
  const ids = new Map();
  fleetArrays.forEach((fleet, group) => (fleet || []).forEach((ship, i) => {
    if (ship) ids.set(ship, `${group < 2 ? 'friend' : 'enemy'}:${group % 2 ? 'escort' : 'main'}:${i}`);
  }));
  const key = ship => ship ? (ids.get(ship) || `npc:${ship.id}:${ship.pos}`) : null;
  output.push({name, fleetType:j.fleet?.type || 0, packets,
    fleets: fleetArrays.map(fleet => (fleet || []).map(ship => ship && ({
      id: ship.id, initial: ship.initHP, final: ship.nowHP, max: ship.maxHP, items: ship.items,
      damageDealt:ship.damage, damageReceived:ship.lostHP
    }))),
    attacks: s.stages.filter(Boolean).flatMap(stage => stage.attacks || []).filter(a => a.toShip).map(a => ({
      from: key(a.fromShip), to: key(a.toShip), before: a.fromHP, after: a.toHP,
      damage: a.damage, hit: a.hit.map(v => ['miss','hit','critical'][v]),
      type: a.type, useItem: a.useItem || null
    }))
  });
}
function walk(dir) {
  for (const e of fs.readdirSync(dir, {withFileTypes:true})) {
    const p = path.join(dir,e.name);
    if (e.isDirectory()) walk(p);
    else if (p.endsWith('.json')) inspect(path.relative(fixtureRoot,p),JSON.parse(fs.readFileSync(p,'utf8')));
  }
}
if (fixtureRoot && fixtureRoot !== '-') walk(fixtureRoot);
const userCapture = process.argv[4];
if (userCapture && fs.existsSync(userCapture)) inspect('user/pasted-text', JSON.parse(fs.readFileSync(userCapture,'utf8').replace(/^\uFEFF/,'')));
const ours = (id, hp=100, items=[]) => ({api_id:id,api_ship_id:id,api_nowhp:hp,api_maxhp:100,api_lv:99,poi_slot:items.map(api_slotitem_id=>({api_slotitem_id}))});
const shell = (flags, ats, dfs, damages, types) => ({api_at_eflag:flags,api_at_list:ats,api_df_list:dfs,api_damage:damages,api_cl_list:damages.map(row=>row.map(()=>1)),api_at_type:types || flags.map(()=>0)});
function sample(name, packet, options={}) {
  inspect('synthetic/'+name, {version:'2.1',type:'Normal',map:[1,1,1],time:1,
    fleet:{type:options.type||0,main:options.main||Array.from({length:6},(_,i)=>ours(i+1)),escort:options.escort||[]},
    packet:[{poi_path:options.path||'/kcsapi/api_req_sortie/battle',api_ship_ke:[101,102,103,104,105,106],api_e_nowhps:[100,100,100,100,100,100],api_e_maxhps:[100,100,100,100,100,100],...packet}]
  });
}
sample('ctf-third-shell', {api_hougeki1:shell([0],[6],[[0]],[[10]]),api_hougeki2:shell([0],[0],[[0]],[[20]]),api_hougeki3:shell([0],[1],[[0]],[[30]])}, {type:1,path:'/kcsapi/api_req_combined_battle/battle',escort:Array.from({length:6},(_,i)=>ours(i+11))});
sample('support-escort',{api_ship_ke_combined:[201],api_e_nowhps_combined:[100],api_e_maxhps_combined:[100],api_support_flag:2,api_support_info:{api_support_hourai:{api_damage:[0,0,0,0,0,0,15],api_cl_list:[0,0,0,0,0,0,1]}}},{path:'/kcsapi/api_req_combined_battle/ec_battle'});
sample('double-hit-damage-control',{api_hougeki1:shell([1],[0],[[0,0]],[[15,15]],[2])},{main:[ours(1,10,[42])]});
sample('nelson-touch',{api_hougeki1:shell([0],[0],[[0,0,1]],[[10,20,30]],[100])});
sample('torpedo-targets',{api_raigeki:{api_frai:[0,0,1,-1,-1,-1],api_fydam:[10,20,0,0,0,0],api_fcl:[1,2,0,0,0,0],api_edam:[30,0,0,0,0,0]}});
sample('friendly-enemy-counterattack',{api_friendly_info:{api_ship_id:[501],api_maxhps:[100],api_nowhps:[100]},api_friendly_battle:{api_hougeki:{...shell([0,1],[0,0],[[0],[0]],[[10],[7]]),api_sp_list:[0,0]}}},{path:'/kcsapi/api_req_battle_midnight/battle'});
sample('friendly-air-damage',{api_friendly_info:{api_ship_id:[501],api_maxhps:[100],api_nowhps:[100]},api_friendly_kouku:{api_stage3:{api_edam:[10],api_ebak_flag:[1],api_erai_flag:[0],api_ecl_flag:[0],api_fdam:[7],api_fbak_flag:[1],api_frai_flag:[0],api_fcl_flag:[0]}}});
sample('day-type-400',{api_hougeki1:shell([0],[0],[[0,1,2]],[[10,20,30]],[400])});
sample('aerial-critical',{api_kouku:{api_stage3:{api_edam:[10],api_ebak_flag:[1],api_erai_flag:[0],api_ecl_flag:[1]}}});
sample('combined-carrier-order', {
  api_ship_ke_combined:[201],api_e_nowhps_combined:[100],api_e_maxhps_combined:[100],
  api_hougeki1:shell([0],[0],[[0]],[[10]]), api_hougeki2:shell([0],[6],[[0]],[[20]]),
  api_raigeki:{api_frai:[0],api_fydam:[5],api_fcl:[1]},
  api_hougeki3:shell([0],[1],[[0]],[[30]])
}, {type:1,path:'/kcsapi/api_req_combined_battle/each_battle',escort:Array.from({length:6},(_,i)=>ours(i+11))});
sample('opening-multiple-torpedoes', {api_opening_atack:{
  api_frai_list_items:[[0,1],null,[2]],api_fydam_list_items:[[10.9,20.8],null,[0]],api_fcl_list_items:[[1,2],null,[0]],
  api_erai_list_items:[[0,1]],api_eydam_list_items:[[5.7,6.3]],api_ecl_list_items:[[1,2]]
}});
sample('air-support-escort', {api_ship_ke_combined:[201],api_e_nowhps_combined:[100],api_e_maxhps_combined:[100],
  api_support_flag:1,api_support_info:{api_support_airatack:{api_stage3:{
    api_edam:[0,0,0,0,0,0,15],api_ebak_flag:[0,0,0,0,0,0,1],api_erai_flag:[],api_ecl_flag:[0,0,0,0,0,0,1]
  }}}}, {path:'/kcsapi/api_req_combined_battle/ec_battle'});
sample('seven-ship-fleet', {api_hougeki1:shell([0,1],[6,0],[[0],[6]],[[10],[20]])},
  {main:Array.from({length:7},(_,i)=>ours(i+1))});
sample('night-combined-special-index', {api_hougeki:{...shell([0],[0],[[0,1]],[[10,20]]),api_sp_list:[104]}},
  {type:2,path:'/kcsapi/api_req_combined_battle/midnight_battle',escort:Array.from({length:6},(_,i)=>ours(i+11))});
sample('night-to-day-order', {api_n_hougeki1:{...shell([0],[0],[[0]],[[5]]),api_sp_list:[0]},
  api_n_hougeki2:{...shell([0],[0],[[0]],[[6]]),api_sp_list:[0]},
  api_hougeki1:shell([0],[0],[[0]],[[7]]),api_hougeki2:shell([0],[0],[[0]],[[8]]),
  api_hougeki3:shell([0],[0],[[0]],[[9]]),api_raigeki:{api_frai:[0],api_fydam:[10],api_fcl:[1]}},
  {path:'/kcsapi/api_req_combined_battle/ec_night_to_day'});
sample('repair-item-repeat-poi-semantics', {api_hougeki1:shell([1,1],[0,0],[[0],[0]],[[20],[30]])},
  {main:[ours(1,10,[42,43])]});
sample('goddess-double-hit', {api_hougeki1:shell([1],[0],[[0,0]],[[15,15]],[2])},
  {main:[ours(1,10,[43,42])]});
sample('aerial-negative-slot-preserves-index', {api_kouku:{api_stage3:{
  api_edam:[-1,10],api_ebak_flag:[0,1],api_erai_flag:[0,0],api_ecl_flag:[0,1]
}}});
for (const night of [false,true]) {
  for (const id of [0,1,2,3,4,5,6,7,100,101,102,103,104,105,106,200,300,301,302,400,401,1000]) {
    const attack = {...shell([0],[0],[[0,1,0,1,0,1]],[[1.9,2.9,3.9,4.9,5.9,6.9]],[id]),api_sp_list:[id]};
    sample(`${night?'night':'day'}-type-${id}`, {[night?'api_hougeki':'api_hougeki1']:attack},
      {path:night?'/kcsapi/api_req_battle_midnight/battle':'/kcsapi/api_req_sortie/battle'});
  }
}
process.stdout.write(JSON.stringify(process.env.POI_DETAIL_REVIEW_SYNTHETIC ? output.filter(c => c.name.startsWith('synthetic/')) : output));
