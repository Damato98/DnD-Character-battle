// Reglas 5e puras (sin red ni interfaz): fáciles de probar y reutilizar en la Fase 2.
export const ABILITIES = ['str', 'dex', 'con', 'int', 'wis', 'cha'];
export const mod = (score) => Math.floor((score - 10) / 2);
export const fmt = (n) => (n >= 0 ? '+' : '') + n;
export const profBonus = (level) => 2 + Math.floor((level - 1) / 4);
export const spellAbilityMod = (c) => mod(c.abilities[c.casting_ability]);
export const spellDC = (c) => 8 + profBonus(c.level) + spellAbilityMod(c);
export const spellAttack = (c) => profBonus(c.level) + spellAbilityMod(c);

// Variante de puntos de hechizo (DMG, p. 288).
export const SP_COST = { 1: 2, 2: 3, 3: 5, 4: 6, 5: 7, 6: 9, 7: 10, 8: 11, 9: 13 };
const SP_BY_LEVEL = [4, 6, 14, 17, 27, 32, 38, 44, 57, 64, 73, 73, 83, 83, 94, 94, 107, 114, 123, 133];
const MAX_SLOT = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 9, 9];
export const spMax = (level) => SP_BY_LEVEL[level - 1];
export const maxSlot = (level) => MAX_SLOT[level - 1];

// Niveles a los que se puede lanzar un hechizo (base hasta el máximo del personaje).
export const castLevels = (c, spell) =>
  Array.from({ length: Math.max(0, maxSlot(c.level) - spell.level + 1) }, (_, i) => spell.level + i);

export function canCast(c, spell, level) {
  if (spell.level === 0) return { ok: true, cost: 0 };
  if (level < spell.level || level > maxSlot(c.level))
    return { ok: false, reason: `Tu nivel permite lanzar hasta el nivel ${maxSlot(c.level)}.` };
  const cost = SP_COST[level];
  if (c.sp_current < cost)
    return { ok: false, reason: `Faltan puntos: cuesta ${cost} y tenés ${c.sp_current}.` };
  return { ok: true, cost };
}

export const applyHp = (c, delta) => Math.min(c.hp_max, Math.max(0, c.hp_current + delta));
