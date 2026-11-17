-- Hoja 5e · Fase 1. Pegar completo en Supabase > SQL Editor > Run.
create table characters (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  class text not null default 'Warlock',
  level int not null default 1 check (level between 1 and 20),
  abilities jsonb not null default '{"str":10,"dex":10,"con":10,"int":10,"wis":10,"cha":10}',
  casting_ability text not null default 'cha',
  hp_max int not null default 10,
  hp_current int not null default 10,
  ac int not null default 10,
  speed int not null default 30,
  sp_max int not null default 0,
  sp_current int not null default 0 check (sp_current >= 0),
  created_at timestamptz not null default now()
);

create table character_spells (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references characters on delete cascade,
  spell_id text not null,              -- id del catálogo (src/lib/spells.js)
  source text not null default 'known',
  unique (character_id, spell_id)
);

create table inventory_items (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references characters on delete cascade,
  container text not null default 'backpack',
  name text not null,
  qty int not null default 1,
  weight numeric not null default 0,
  equipped boolean not null default false,
  attuned boolean not null default false
);

create table features (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references characters on delete cascade,
  name text not null,
  origin text not null default 'class',  -- class | subclass | origin | feat | optional | misc
  action_type text,                       -- action | bonus | reaction | free
  description text
);

create table cast_log (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references characters on delete cascade,
  spell_id text not null,
  spell_level int not null,
  cost int not null,
  undone boolean not null default false,
  created_at timestamptz not null default now()
);

-- Seguridad: cada usuario solo ve y edita lo suyo.
alter table characters enable row level security;
create policy own_characters on characters for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

do $$ declare t text; begin
  foreach t in array array['character_spells','inventory_items','features','cast_log'] loop
    execute format('alter table %I enable row level security', t);
    execute format($p$create policy own_%1$s on %1$I for all
      using (exists (select 1 from characters c where c.id = character_id and c.owner_id = auth.uid()))
      with check (exists (select 1 from characters c where c.id = character_id and c.owner_id = auth.uid()))$p$, t);
  end loop;
end $$;

-- Lanzar: descuenta y registra en una sola operación atómica.
create function cast_spell(p_char uuid, p_spell text, p_level int, p_cost int)
returns int language plpgsql as $$
declare v int;
begin
  update characters set sp_current = sp_current - p_cost
   where id = p_char and sp_current >= p_cost returning sp_current into v;
  if v is null then raise exception 'Puntos de hechizo insuficientes'; end if;
  insert into cast_log (character_id, spell_id, spell_level, cost) values (p_char, p_spell, p_level, p_cost);
  return v;
end $$;

-- Deshacer: devuelve los puntos (sin pasar del máximo) y marca el registro.
create function undo_cast(p_log uuid)
returns int language plpgsql as $$
declare l cast_log; v int;
begin
  update cast_log set undone = true where id = p_log and not undone returning * into l;
  if l.id is null then raise exception 'Ese lanzamiento ya fue deshecho'; end if;
  update characters set sp_current = least(sp_current + l.cost, sp_max)
   where id = l.character_id returning sp_current into v;
  return v;
end $$;
