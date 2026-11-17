<script>
  import { onMount } from 'svelte';
  import { sb } from './lib/supabase.js';
  import { SPELLS } from './lib/spells.js';
  import * as R from './lib/rules.js';

  let session = null, email = '', msg = '';
  let chars = [], c = null, known = [], log = [];
  let pick = '', lvl = {}, hpDelta = 1;

  $: knownSpells = known.map((id) => SPELLS.find((s) => s.id === id)).filter(Boolean);
  const nameOf = (id) => SPELLS.find((s) => s.id === id)?.name ?? id;

  onMount(async () => {
    session = (await sb.auth.getSession()).data.session;
    sb.auth.onAuthStateChange((_, s) => { session = s; if (s) loadChars(); });
    if (session) loadChars();
  });

  async function login() {
    const { error } = await sb.auth.signInWithOtp({ email, options: { emailRedirectTo: location.origin } });
    msg = error ? error.message : 'Te enviamos un enlace. Abrilo desde este dispositivo para entrar.';
  }

  async function loadChars() {
    chars = (await sb.from('characters').select('*').order('created_at')).data ?? [];
    if (chars.length) choose(chars[0].id);
  }
  async function choose(id) {
    c = chars.find((x) => x.id === id);
    const r = await sb.from('character_spells').select('spell_id').eq('character_id', id);
    known = (r.data ?? []).map((x) => x.spell_id);
    await loadLog();
  }
  async function loadLog() {
    const r = await sb.from('cast_log').select('*').eq('character_id', c.id)
      .order('created_at', { ascending: false }).limit(15);
    log = r.data ?? [];
  }
  async function create() {
    const sp = R.spMax(1);
    const { data, error } = await sb.from('characters')
      .insert({ name: 'Nuevo personaje', sp_max: sp, sp_current: sp }).select().single();
    if (error) return (msg = error.message);
    chars = [...chars, data];
    choose(data.id);
  }

  function patchLocal(p) {
    c = { ...c, ...p };
    chars = chars.map((x) => (x.id === c.id ? c : x));
  }
  async function save(p) {
    patchLocal(p);
    const { error } = await sb.from('characters').update(p).eq('id', c.id);
    if (error) msg = error.message;
  }
  function setLevel(level) {
    if (!(level >= 1 && level <= 20)) return;
    const sp_max = R.spMax(level);
    save({ level, sp_max, sp_current: Math.min(c.sp_current, sp_max) });
  }
  const setAbility = (k, v) => save({ abilities: { ...c.abilities, [k]: +v } });
  const hp = (sign) => save({ hp_current: R.applyHp(c, sign * hpDelta) });
  const longRest = () => save({ sp_current: c.sp_max, hp_current: c.hp_max });

  async function addSpell() {
    if (!pick) return;
    const { error } = await sb.from('character_spells').insert({ character_id: c.id, spell_id: pick });
    if (error) return (msg = error.message);
    known = [...known, pick];
    pick = '';
  }

  async function cast(s) {
    const level = lvl[s.id] ?? s.level;
    const check = R.canCast(c, s, level);
    if (!check.ok) return (msg = check.reason);
    const { data, error } = await sb.rpc('cast_spell',
      { p_char: c.id, p_spell: s.id, p_level: level, p_cost: check.cost });
    if (error) return (msg = error.message);
    msg = '';
    patchLocal({ sp_current: data });
    loadLog();
  }
  async function undo(l) {
    const { data, error } = await sb.rpc('undo_cast', { p_log: l.id });
    if (error) return (msg = error.message);
    patchLocal({ sp_current: data });
    loadLog();
  }
</script>

{#if !session}
  <main class="login">
    <h1>Hoja 5e</h1>
    <p>Entrá con tu mail para guardar tus personajes en la nube.</p>
    <input type="email" bind:value={email} placeholder="tu@mail.com" />
    <button class="primary" on:click={login}>Enviar enlace de acceso</button>
    <p class="msg">{msg}</p>
  </main>
{:else}
  <main>
    <header>
      <select on:change={(e) => choose(e.target.value)}>
        {#each chars as x}<option value={x.id} selected={x.id === c?.id}>{x.name}</option>{/each}
      </select>
      <button on:click={create}>Nuevo</button>
      <button on:click={() => sb.auth.signOut()}>Salir</button>
    </header>

    {#if msg}<p class="msg" on:click={() => (msg = '')}>{msg}</p>{/if}

    {#if !c}
      <p>Todavía no tenés personajes. Creá el primero con “Nuevo”.</p>
    {:else}
      <input class="name" value={c.name} on:change={(e) => save({ name: e.target.value })} />
      <section class="stats">
        <label>Nivel <input type="number" min="1" max="20" value={c.level} on:change={(e) => setLevel(+e.target.value)} /></label>
        <span>Competencia <b>{R.fmt(R.profBonus(c.level))}</b></span>
        <span>CD <b>{R.spellDC(c)}</b></span>
        <span>Ataque <b>{R.fmt(R.spellAttack(c))}</b></span>
      </section>

      <section>
        <h2>Vida {c.hp_current}/{c.hp_max}</h2>
        <div class="row">
          <input type="number" min="1" bind:value={hpDelta} />
          <button on:click={() => hp(-1)}>Daño</button>
          <button on:click={() => hp(1)}>Curar</button>
          <label>Máx <input type="number" value={c.hp_max} on:change={(e) => save({ hp_max: +e.target.value })} /></label>
        </div>
      </section>

      <section class="abil">
        {#each R.ABILITIES as k}
          <label>{k.toUpperCase()}
            <input type="number" value={c.abilities[k]} on:change={(e) => setAbility(k, e.target.value)} />
            <b>{R.fmt(R.mod(c.abilities[k]))}</b>
          </label>
        {/each}
      </section>

      <section>
        <h2>Puntos de hechizo {c.sp_current}/{c.sp_max}</h2>
        <progress max={c.sp_max} value={c.sp_current}></progress>
        <button on:click={longRest}>Descanso largo</button>

        {#each knownSpells as s (s.id)}
          <div class="spell">
            <div><b>{s.name}</b>
              <small>{s.level ? 'Nivel ' + s.level : 'Truco'}, {s.school}, {s.range}{s.concentration ? ', concentración' : ''}{s.ritual ? ', ritual' : ''}</small>
            </div>
            {#if s.level}
              <select bind:value={lvl[s.id]}>
                {#each R.castLevels(c, s) as n}<option value={n}>Nivel {n} ({R.SP_COST[n]} pts)</option>{/each}
              </select>
            {/if}
            <button class="primary" on:click={() => cast(s)}>Lanzar</button>
          </div>
        {/each}

        <div class="row">
          <select bind:value={pick}>
            <option value="">Agregar hechizo…</option>
            {#each SPELLS.filter((s) => !known.includes(s.id)) as s}<option value={s.id}>{s.name}</option>{/each}
          </select>
          <button on:click={addSpell}>Agregar</button>
        </div>
      </section>

      <section>
        <h2>Historial de lanzamientos</h2>
        {#each log as l (l.id)}
          <div class="row log" class:undone={l.undone}>
            <span>{nameOf(l.spell_id)}, nivel {l.spell_level}, −{l.cost} pts</span>
            {#if !l.undone}<button on:click={() => undo(l)}>Deshacer</button>{/if}
          </div>
        {:else}<p class="dim">Todavía no lanzaste nada.</p>{/each}
      </section>
    {/if}
  </main>
{/if}

<style>
  :global(body) { margin: 0; background: #14161f; color: #e6e8f2; font: 16px/1.4 system-ui, sans-serif; }
  main { max-width: 560px; margin: 0 auto; padding: 12px 14px 48px; }
  header, .row, .stats { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
  .stats { justify-content: space-between; margin: 10px 0; color: #9aa0bd; }
  .stats b { color: #e6e8f2; }
  section { background: #1d2030; border: 1px solid #2e3350; border-radius: 10px; padding: 12px; margin: 12px 0; }
  h1, h2 { margin: 0 0 8px; font-size: 1.1rem; }
  input, select, button { font: inherit; color: inherit; background: #262b42; border: 1px solid #353b5c; border-radius: 8px; padding: 8px 10px; }
  input[type='number'] { width: 4.5rem; }
  .name { width: 100%; box-sizing: border-box; font-size: 1.3rem; margin-top: 10px; }
  button { cursor: pointer; }
  button.primary { background: #a78bfa; color: #14161f; border-color: #a78bfa; font-weight: 600; }
  .abil { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
  .abil label { display: grid; gap: 4px; justify-items: center; }
  progress { width: 100%; accent-color: #a78bfa; margin: 4px 0 8px; }
  .spell { display: flex; gap: 8px; align-items: center; justify-content: space-between; padding: 8px 0; border-top: 1px solid #2e3350; }
  .spell small { display: block; color: #9aa0bd; }
  .log { justify-content: space-between; }
  .undone { opacity: 0.45; text-decoration: line-through; }
  .msg { color: #f87171; cursor: pointer; }
  .dim { color: #9aa0bd; }
  .login { display: grid; gap: 10px; padding-top: 18vh; }
</style>
