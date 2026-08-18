const fs = require('fs')
const path = require('path')
const Module = require('module')
const { createRequire } = require('module')

const pluginRoot = path.resolve(process.argv[2])
const snapshotPath = path.resolve(
  process.argv[3] || 'test/fixtures/poi_ezexped/expedition_rules.json',
)
const pluginRequire = createRequire(path.join(pluginRoot, 'package.json'))

pluginRequire('@babel/register')({
  extensions: ['.es'],
  babelrc: false,
  cwd: pluginRoot,
  only: [pluginRoot],
  presets: [
    [
      pluginRequire.resolve('@babel/preset-env'),
      { targets: { node: 'current' } },
    ],
  ],
})
global.window = { getStore: () => ({}) }
const originalLoad = Module._load
Module._load = function (request) {
  if (request === 'views/utils/selectors') {
    return { allCVEIdsSelector: () => [] }
  }
  return originalLoad.apply(this, arguments)
}

const expedReqs = pluginRequire(
  path.join(pluginRoot, 'exped-reqs', 'index.es'),
).expedReqs
const snapshot = JSON.parse(fs.readFileSync(snapshotPath, 'utf8')).missions

const composition = value =>
  Object.entries(value).map(([type, count]) => `${type}:${count}`).join('+')

const normalRule = requirement => {
  const value = requirement.ereq
  switch (value.type) {
    case 'FSLevel': return `FSLevel=${value.level}`
    case 'ShipCount': return `ShipCount=${value.count}`
    case 'Morale': return `Morale=${value.morale}`
    case 'LevelSum': return `LevelSum=${value.level}`
    case 'DrumCarrierCount': return `DrumCarrierCount=${value.count}`
    case 'DrumCount': return `DrumCount=${value.count}`
    case 'FSType': return `FSType=${value.estype}`
    case 'FleetCompo': return `FleetCompo=${composition(value.compo)}`
    case 'AnyFleetCompo':
      return `AnyFleetCompo=${value.compos.map(composition).join('|')}`
    case 'TotalFirepower': return `TotalFirepower=${value.firepower}`
    case 'TotalAntiAir': return `TotalAntiAir=${value.antiAir}`
    case 'TotalAsw': return `TotalAsw=${value.asw}`
    case 'TotalLos': return `TotalLos=${value.los}`
    default: throw new Error(`Unsupported Poi requirement: ${value.type}`)
  }
}

const greatSuccess = requirements => {
  const drum = requirements.find(item => item.ereq.type === 'GSRateDrum')
  if (drum) {
    const required = requirements.find(item => item.ereq.type === 'DrumCount')
    return `drum:${drum.ereq.min}:${drum.ereq.max}:${required.ereq.count}`
  }
  if (requirements.some(item => item.ereq.type === 'GSRateFlag')) {
    return 'flagship'
  }
  return 'standard'
}

const runtime = Object.values(expedReqs)
  .filter(value => Number.isInteger(value.id))
  .map(value => ({
    id: value.id,
    normal: [...new Set(value.norm.map(normalRule))],
    greatSuccess: greatSuccess(value.gs),
  }))
const expected = new Map(snapshot.map(value => [value.id, value]))
const mismatches = []
for (const value of runtime) {
  const target = expected.get(value.id)
  if (!target ||
      JSON.stringify(value.normal) !== JSON.stringify(target.normal) ||
      value.greatSuccess !== target.greatSuccess) {
    mismatches.push({ runtime: value, snapshot: target || null })
  }
}
for (const target of snapshot) {
  if (!runtime.some(value => value.id === target.id)) {
    mismatches.push({ runtime: null, snapshot: target })
  }
}

console.log(JSON.stringify({
  poiCount: runtime.length,
  snapshotCount: snapshot.length,
  mismatches,
}))
if (mismatches.length > 0) process.exitCode = 1
