// Catálogo inicial (solo metadatos de hechizos del SRD 5.1). Se amplía agregando filas.
const s = (id, name, level, school, range, extra = {}) => ({ id, name, level, school, range, ...extra });
export const SPELLS = [
  s('chill-touch', 'Chill Touch', 0, 'Necromancy', '120 ft'),
  s('eldritch-blast', 'Eldritch Blast', 0, 'Evocation', '120 ft'),
  s('false-life', 'False Life', 1, 'Necromancy', 'Self'),
  s('find-familiar', 'Find Familiar', 1, 'Conjuration', '10 ft', { ritual: true }),
  s('identify', 'Identify', 1, 'Divination', 'Touch', { ritual: true }),
  s('armor-of-agathys', 'Armor of Agathys', 2, 'Abjuration', 'Self'),
  s('mirror-image', 'Mirror Image', 2, 'Illusion', 'Self'),
  s('ray-of-enfeeblement', 'Ray of Enfeeblement', 2, 'Necromancy', '60 ft', { concentration: true }),
  s('counterspell', 'Counterspell', 3, 'Abjuration', '60 ft', { reaction: true }),
  s('vampiric-touch', 'Vampiric Touch', 3, 'Necromancy', 'Self', { concentration: true })
];
