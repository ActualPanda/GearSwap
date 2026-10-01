include('Modes')

local res = require('resources')

local lockstyleset = nil
local macro_book = nil
local macro_page = nil

local jp_mode = false

local bindings = {
  ['^#'] = 'gs c echodrops',
  ['^R'] = 'gs c toggle_speed',
  ['^F4'] = 'gs c cycle_shield',
  ['^F3'] = 'gs c cycle_weapon',
  ['^F2'] = 'gs c cycle_tp',
  ['^F1'] = 'gs c cycle_idle',
}

local idle_mode = M({ ['description'] = 'What mode to idle in', 'dt', 'refresh' })
local tp_mode = M({ ['description'] = 'What mode to tp in', 'dt' })
local weapon = M({
  ['description'] = 'What weapon to use',
  'Naegling',
  'Sakpata',
  'Kaja Rod',
  'Marin Staff +1',
  "Bunzi's Rod",
  'Unlocked',
})
local shield = M({ ['description'] = 'What shield to use', 'Genbu', 'Unlocked' })
local run = M(false, 'If should equip movement gear')

send_command('bind ^a gs c nothing')

local can_burst = require('magic.lua')

local function setup_bindings()
  for key, command in pairs(bindings) do
    send_command('bind ' .. key .. ' ' .. command)
  end
end

local function destroy_bindings()
  for _, key in pairs(bindings) do
    send_command('unbind ' .. key)
  end
end

local function set_macros()
  send_command('@input /macro book ' .. macro_book .. '; wait 1; @input /macro set ' .. macro_page)
end

local function set_lockstyle()
  send_command('wait 10; input /lockstyleset ' .. lockstyleset)
end

local function equip_idle()
  if player.sub_job == 'NIN' or player.sub_job == 'DNC' then
    equip(sets.weapons[weapon.current], sets.idle[idle_mode.current])
  else
    equip(sets.weapons[weapon.current], sets.shields[shield.current], sets.idle[idle_mode.current])
  end
  if run.value then
    equip(sets.idle.speed)
  end
end

local function equip_tp()
  if player.sub_job == 'NIN' or player.sub_job == 'DNC' then
    equip(sets.weapons[weapon.current], sets.tp[tp_mode.current])
  else
    equip(sets.weapons[weapon.current], sets.shields[shield.current], sets.tp[tp_mode.current])
  end
end

local function refresh()
  if player.status == 'Engaged' then
    equip_tp()
  elseif player.status == 'Idle' then
    equip_idle()
  end
end

local function weathercheck(spell_element)
  if spell_element == world.weather_element or spell_element == world.day_element then
    equip({
      waist = 'Hachirin-no-Obi',
    })
  end
end

local function set_priorities(key1, key2)
  local future, current = gearswap.equip_list, gearswap.equip_list_history
  local function get_val(piece, key)
    if piece and type(piece) == 'table' and piece[key] and type(piece[key]) == 'number' then
      return piece[key]
    end
    return 0
  end
  for i, v in pairs(future) do
    local priority = get_val(future[i], key1)
      - get_val(current[i], key1)
      + (get_val(future[i], key2) - get_val(current[i], key2))
    if type(v) == 'table' then
      future[i].priority = priority
    else
      future[i] = { name = v, priority = priority }
    end
  end
end

-- custom functions
------------------------------
function get_sets()
  sets.weapons = {
    ['Sakpata'] = { main = "Sakpata's Sword" },
    ['Brilliance'] = { main = 'Brilliance' },
    ['Naegling'] = { main = 'Naegling' },
    ['Mafic Cudgel'] = { main = 'Mafic Cudgel' },
    ['Kaja Rod'] = { main = 'Kaja Rod' },
    ['Marin Staff +1'] = { main = 'Marin Staff +1', sub = "Elder's Grip +1" },
    ["Bunzi's Rod"] = { main = "Bunzi's Rod" },
    ['Unlocked'] = { main = '' },
  }
  sets.shields = {
    ['Genbu'] = { sub = "Genbu's Shield" },
    ['Unlocked'] = { sub = '' },
  }

  sets.idle = {}
  sets.idle.dt = {
    ammo = 'Staunch Tathlum',
    head = 'Leth. Chappel +2',
    body = 'Lethargy Sayon +2',
    hands = 'Leth. Ganth. +2',
    legs = 'Leth. Fuseau +2',
    feet = 'Leth. Houseaux +2',
    neck = 'Loricate Torque',
    waist = 'Sailfi Belt +1',
    left_ear = 'Alabaster Earring',
    right_ear = 'Brutal Earring',
    left_ring = "Warden's Ring",
    right_ring = 'Gelatinous Ring +1',
    back = {
      name = "Sucellos's Cape",
      augments = { 'DEX+20', 'Accuracy+20 Attack+20', 'Accuracy+10', '"Dbl.Atk."+10', 'Damage taken-5%' },
    },
  }

  sets.idle.refresh = {
    ammo = 'Staunch Tathlum',
    head = 'Viti. Chapeau +3',
    body = 'Lethargy Sayon +2',
    hands = 'Leth. Ganth. +2',
    legs = 'Leth. Fuseau +2',
    feet = 'Leth. Houseaux +2',
    neck = 'Loricate Torque',
    waist = 'Fucho-no-Obi',
    left_ear = 'Alabaster Earring',
    right_ear = 'Brutal Earring',
    left_ring = "Warden's Ring",
    right_ring = 'Gelatinous Ring +1',
    back = {
      name = "Sucellos's Cape",
      augments = { 'DEX+20', 'Accuracy+20 Attack+20', 'Accuracy+10', '"Dbl.Atk."+10', 'Damage taken-5%' },
    },
  }

  sets.idle.speed = {
    legs = { name = 'Carmine Cuisses +1', augments = { 'HP+80', 'STR+12', 'INT+12' }, hp = 130 },
  }

  sets.tp = {}
  sets.tp.dt = {
    ammo = 'Staunch Tathlum',
    head = 'Leth. Chappel +2',
    body = 'Lethargy Sayon +2',
    hands = 'Leth. Ganth. +2',
    legs = 'Leth. Fuseau +2',
    feet = 'Leth. Houseaux +2',
    neck = 'Lissome Necklace',
    waist = 'Sailfi Belt +1',
    left_ear = 'Alabaster Earring',
    right_ear = 'Brutal Earring',
    left_ring = 'Defending Ring',
    right_ring = 'Petrov Ring',
    back = {
      name = "Sucellos's Cape",
      augments = { 'DEX+20', 'Accuracy+20 Attack+20', 'Accuracy+10', '"Dbl.Atk."+10', 'Damage taken-5%' },
    },
  }

  sets.precast = {}
  sets.precast.default = {
    ammo = 'Staunch Tathlum',
    head = 'Atrophy Chapeau +3',
    body = 'Viti. Tabard +3',
    hands = 'Leth. Ganth. +2',
    legs = 'Leth. Fuseau +2',
    feet = 'Leth. Houseaux +2',
    neck = 'Loricate Torque',
    waist = 'Witful Belt',
    left_ear = 'Alabaster Earring',
    right_ear = 'Brutal Earring',
    left_ring = 'Defending Ring',
    right_ring = 'Gelatinous Ring +1',
    back = {
      name = "Sucellos's Cape",
      augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
    },
  }

  sets.precast['Enhancing Magic'] = set_combine(sets.precast.default, {
    waist = 'Siegel Sash',
    right_ear = 'Lethargy Earring',
  })

  sets.midcast = {}
  sets.midcast.macc = {
    ammo = 'Kalboron Stone',
    head = 'Viti. Chapeau +3',
    body = 'Atrophy Tabard +3',
    hands = 'Leth. Ganth. +2',
    legs = 'Atrophy Tights +3',
    feet = 'Atro. Boots +3',
    neck = 'Sanctity Necklace',
    waist = 'Witful Belt',
    left_ear = 'Alabaster Earring',
    right_ear = 'Snotra Earring',
    left_ring = 'Defending Ring',
    right_ring = 'Metamor. Ring +1',
    back = {
      name = "Sucellos's Cape",
      augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
    },
  }

  sets.midcast['Dispel'] = set_combine(sets.midcast.macc, {
    neck = "Duelist's Torque +1",
  })
  sets.midcast['Frazzle II'] = sets.midcast.macc

  sets.midcast['Frazzle III'] = {
    ammo = 'Staunch Tathlum',
    head = 'Viti. Chapeau +3',
    body = 'Lethargy Sayon +2',
    hands = 'Leth. Ganth. +2',
    legs = 'Leth. Fuseau +2',
    feet = 'Leth. Houseaux +2',
    neck = { name = 'Dls. Torque +1', augments = { 'Path: A' } },
    waist = 'Witful Belt',
    left_ear = 'Alabaster Earring',
    right_ear = 'Snotra Earring',
    left_ring = 'Defending Ring',
    right_ring = 'Metamor. Ring +1',
    back = {
      name = "Sucellos's Cape",
      augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
    },
  }
  sets.midcast['Distract III'] = sets.midcast['Frazzle III']

  sets.midcast.potency = {
    ammo = 'Kalobron Stone',
    head = 'Viti. Chapeau +3',
    body = 'Lethargy Sayon +2',
    hands = 'Leth. Ganth. +2',
    legs = 'Leth. Fuseau +2',
    feet = 'Leth. Houseaux +2',
    neck = { name = 'Dls. Torque +1', augments = { 'Path: A' } },
    waist = 'Witful Belt',
    left_ear = 'Alabaster Earring',
    right_ear = 'Snotra Earring',
    left_ring = 'Defending Ring',
    right_ring = 'Metamor. Ring +1',
    back = {
      name = "Sucellos's Cape",
      augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
    },
  }

  sets.midcast['Paralyze'] = sets.midcast.potency
  sets.midcast['Paralyze II'] = sets.midcast.potency
  sets.midcast['Slow'] = sets.midcast.potency
  sets.midcast['Slow II'] = sets.midcast.potency
  sets.midcast['Addle'] = sets.midcast.potency
  sets.midcast['Addle II'] = sets.midcast.potency

  sets.midcast.duration = {
    ammo = 'Staunch Tathlum',
    head = 'Leth. Chappel +2',
    body = 'Lethargy Sayon +2',
    hands = 'Leth. Ganth. +2',
    legs = 'Leth. Fuseau +2',
    feet = 'Leth. Houseaux +2',
    neck = { name = 'Dls. Torque +1', augments = { 'Path: A' } },
    waist = 'Witful Belt',
    left_ear = 'Alabaster Earring',
    right_ear = 'Snotra Earring',
    left_ring = 'Kishar Ring',
    right_ring = 'Metamor. Ring +1',
    back = {
      name = "Sucellos's Cape",
      augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
    },
  }

  sets.midcast['Silence'] = sets.midcast.duration
  sets.midcast['Sleep'] = sets.midcast.duration
  sets.midcast['Sleep II'] = sets.midcast.duration
  sets.midcast['Sleepga'] = sets.midcast.duration
  sets.midcast['Petrify'] = sets.midcast.duration
  sets.midcast['Bind'] = sets.midcast.duration
  sets.midcast['Dia'] = sets.midcast.duration
  sets.midcast['Dia II'] = sets.midcast.duration
  sets.midcast['Dia III'] = sets.midcast.duration
  sets.midcast['Diaga'] = sets.midcast.duration

  sets.midcast.heal = {
    ammo = 'Staunch Tathlum',
    head = { name = 'Kaykaus Mitra', augments = { 'MP+60', '"Cure" spellcasting time -5%', 'Enmity-5' } },
    body = 'Viti. Tabard +3',
    hands = 'Leth. Ganth. +2',
    legs = 'Gyve Trousers',
    feet = 'Leth. Houseaux +2',
    neck = 'Nodens Gorget',
    waist = 'Witful Belt',
    left_ear = 'Alabaster Earring',
    right_ear = 'Snotra Earring',
    left_ring = 'Defending Ring',
    right_ring = 'Metamor. Ring +1',
    back = {
      name = "Sucellos's Cape",
      augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
    },
  }

  sets.midcast['Cure'] = sets.midcast.heal
  sets.midcast['Cure II'] = sets.midcast.heal
  sets.midcast['Cure III'] = sets.midcast.heal
  sets.midcast['Cure IV'] = sets.midcast.heal
  sets.midcast['Curaga'] = sets.midcast.heal
  sets.midcast['Curaga II'] = sets.midcast.heal
  sets.midcast['Curaga III'] = sets.midcast.heal

  sets.midcast['Free Nuke'] = {
    ammo = 'Ghastly Tathlum +1',
    head = 'Leth. Chappel +2',
    body = 'Lethargy Sayon +2',
    hands = 'Leth. Ganth. +2',
    legs = 'Leth. Fuseau +2',
    feet = 'Leth. Houseaux +2',
    neck = 'Sanctity Necklace',
    waist = 'Eschan Stone',
    left_ear = 'Alabaster Earring',
    right_ear = 'Friomisi Earring',
    left_ring = 'Defending Ring',
    right_ring = 'Metamor. Ring +1',
    back = {
      name = "Sucellos's Cape",
      augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
    },
  }

  sets.midcast['Burst'] = {
    ammo = 'Ghastly Tathlum +1',
    head = 'Leth. Chappel +2',
    body = 'Lethargy Sayon +2',
    hands = 'Leth. Ganth. +2',
    legs = 'Leth. Fuseau +2',
    feet = 'Leth. Houseaux +2',
    neck = 'Sanctity Necklace',
    waist = 'Eschan Stone',
    left_ear = 'Alabaster Earring',
    right_ear = 'Friomisi Earring',
    left_ring = 'Defending Ring',
    right_ring = 'Metamor. Ring +1',
    back = {
      name = "Sucellos's Cape",
      augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
    },
  }

  sets.midcast['Drain'] = set_combine(sets.midcast.macc, {
    waist = 'Fucho-no-Obi',
    left_ring = 'Excelsis Ring',
    right_ring = 'Archon Ring',
  })
  sets.midcast['Drain'] = sets.midcast['Drain']

  sets.midcast.max_enhancing = {
    main = 'Naegling',
    sub = "Genbu's Shield",
    ammo = 'Ghastly Tathlum +1',
    head = 'Leth. Chappel +2',
    body = 'Viti. Tabard +3',
    hands = 'Leth. Ganth. +2',
    legs = 'Atrophy Tights +3',
    feet = 'Leth. Houseaux +2',
    neck = 'Loricate Torque',
    waist = 'Olympus Sash',
    left_ear = 'Alabaster Earring',
    right_ear = { name = 'Lethargy Earring', augments = { 'System: 1 ID: 1676 Val: 0', 'Accuracy+7', 'Mag. Acc.+7' } },
    left_ring = 'Defending Ring',
    right_ring = 'Ayanmo Ring',
    back = {
      name = "Sucellos's Cape",
      augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
    },
  }

  sets.midcast['Enfire'] = sets.midcast.max_enhancing
  sets.midcast['Enblizzard'] = sets.midcast.max_enhancing
  sets.midcast['Enaero'] = sets.midcast.max_enhancing
  sets.midcast['Ennstone'] = sets.midcast.max_enhancing
  sets.midcast['Enthunder'] = sets.midcast.max_enhancing
  sets.midcast['Enwater'] = sets.midcast.max_enhancing

  sets.midcast['Temper II'] = sets.midcast.max_enhancing

  sets.midcast['Enhancing Magic'] = {
    self = {
      ammo = 'Staunch Tathlum',
      head = 'Leth. Chappel +2',
      body = 'Viti. Tabard +3',
      hands = 'Atrophy Gloves +3',
      legs = 'Leth. Fuseau +2',
      feet = 'Leth. Houseaux +2',
      neck = { name = 'Dls. Torque +1', augments = { 'Path: A' } },
      waist = 'Embla Sash',
      left_ear = 'Alabaster Earring',
      right_ear = { name = 'Lethargy Earring', augments = { 'System: 1 ID: 1676 Val: 0', 'Accuracy+7', 'Mag. Acc.+7' } },
      left_ring = 'Defending Ring',
      right_ring = 'Ayanmo Ring',
      back = {
        name = "Sucellos's Cape",
        augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
      },
    },
    other = {
      ammo = 'Staunch Tathlum',
      head = 'Leth. Chappel +2',
      body = 'Lethargy Sayon +2',
      hands = 'Atrophy Gloves +3',
      legs = 'Leth. Fuseau +2',
      feet = 'Leth. Houseaux +2',
      neck = { name = 'Dls. Torque +1', augments = { 'Path: A' } },
      waist = 'Embla Sash',
      left_ear = 'Alabaster Earring',
      right_ear = { name = 'Lethargy Earring', augments = { 'System: 1 ID: 1676 Val: 0', 'Accuracy+7', 'Mag. Acc.+7' } },
      left_ring = 'Defending Ring',
      right_ring = 'Ayanmo Ring',
      back = {
        name = "Sucellos's Cape",
        augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
      },
    },
  }

  sets.midcast.refresh = {
    self = {
      ammo = 'Staunch Tathlum',
      head = 'Leth. Chappel +2',
      body = 'Atrophy Tabard +3',
      hands = 'Atrophy Gloves +3',
      legs = 'Leth. Fuseau +2',
      feet = 'Leth. Houseaux +2',
      neck = { name = 'Dls. Torque +1', augments = { 'Path: A' } },
      waist = 'Gishdubar Sash',
      left_ear = 'Alabaster Earring',
      right_ear = { name = 'Lethargy Earring', augments = { 'System: 1 ID: 1676 Val: 0', 'Accuracy+7', 'Mag. Acc.+7' } },
      left_ring = 'Defending Ring',
      right_ring = 'Ayanmo Ring',
      back = {
        name = "Sucellos's Cape",
        augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
      },
    },
    other = {
      ammo = 'Staunch Tathlum',
      head = 'Leth. Chappel +2',
      body = 'Atrophy Tabard +3',
      hands = 'Atrophy Gloves +3',
      legs = 'Leth. Fuseau +2',
      feet = 'Leth. Houseaux +2',
      neck = { name = 'Dls. Torque +1', augments = { 'Path: A' } },
      waist = 'Embla Sash',
      left_ear = 'Alabaster Earring',
      right_ear = { name = 'Lethargy Earring', augments = { 'System: 1 ID: 1676 Val: 0', 'Accuracy+7', 'Mag. Acc.+7' } },
      left_ring = 'Defending Ring',
      right_ring = 'Ayanmo Ring',
      back = {
        name = "Sucellos's Cape",
        augments = { 'MND+20', 'Mag. Acc+20 /Mag. Dmg.+20', 'Mag. Acc.+10', '"Fast Cast"+10' },
      },
    },
  }

  sets.midcast['Savage Blade'] = {
    ammo = 'Coiste Bodhar',
    head = 'Viti. Chapeau +3',
    body = 'Viti. Tabard +3',
    hands = 'Atrophy Gloves +3',
    legs = 'Nyame Flanchard',
    feet = 'Leth. Houseaux +2',
    neck = 'Lissome Necklace',
    waist = 'Sailfi Belt +1',
    left_ear = 'Ishvara Earring',
    right_ear = 'Moonshade Earring',
    left_ring = 'Defending Ring',
    right_ring = 'Karieyh Ring',
    back = {
      name = "Sucellos's Cape",
      augments = {
        'STR+20',
        'Accuracy+20 Attack+20',
        'STR+5',
        'Weapon skill damage +10%',
      },
    },
  }

  sets.midcast['Black Halo'] = sets.midcast['Savage Blade']
  sets.midcast['Death Blossom'] = sets.midcast['Savage Blade']

  sets.midcast['Chant du Cygne'] = set_combine(sets.midcast['Savage Blade'], {
    neck = 'fotia Gorget',
    waist = 'Fotia Belt',
  })
  sets.midcast['Evisceration'] = sets.midcast['Chant du Cygne']
  sets.midcast['Requiescat'] = sets.midcast['Evisceration']
  -- ###############################################################

  -- ###############################################################
  lockstyleset = 6

  macro_book = 5
  macro_page = 1

  setup_bindings()
  set_macros()
  set_lockstyle()
  equip_idle()
end

function file_unload()
  destroy_bindings()
end

function precast(spell)
  equip(sets.precast.default)
  set_priorities('hp', 'mp')
end

function midcast(spell)
  if string.match(spell.name, '^Refresh') then
    if spell.target.name == 'Cromakre' then
      equip(sets.midcast.refresh.self)
    else
      equip(sets.midcast.refresh.other)
    end
  elseif spell.skill == 'Elemental Magic' then
    if can_burst(spell) then
      equip(sets.midcast['Burst'])
    else
      equip(sets.midcast['Free Nuke'])
    end
  elseif sets.midcast[spell.name] then
    equip(sets.midcast[spell.name])
  elseif spell.skill == 'Enhancing Magic' then
    if spell.target.name == 'Cromakre' then
      equip(sets.midcast[spell.skill].self)
    else
      equip(sets.midcast[spell.skill].other)
    end
  elseif sets.midcast[spell.skill] then
    equip(sets.midcast[spell.skill])
  end

  weathercheck(spell.element)

  -- just add refresh gear here
  if string.match(spell.name, '^Refresh') and spell.target.name == player.name then
    equip({ waist = 'Gishdubar Sash' })
  end
  set_priorities('hp', 'mp')
end

function aftercast()
  refresh()
  set_priorities('hp', 'mp')
end

function status_change(new)
  refresh()
  set_priorities('hp', 'mp')
end

function sub_job_change()
  set_macros()
  set_lockstyle()
  equip_idle()
  set_priorities('hp', 'mp')
end

function self_command(command)
  if command == 'echodrops' then
    send_command("@input item 'echo drops' <me>")
  elseif command == 'toggle_jp' then
    jp_mode = not jp_mode
    if jp_mode then
      send_command('@input /echo JP MODE Off')
      enable('back')
      aftercast()
    else
      send_command('@input /echo JP MODE On')
      equip({ back = { name = 'Mecisto. Mantle', augments = { 'Cap. Point+49%', 'MND+1', 'Rng.Acc.+5', 'DEF+6' } } })
      disable('back')
    end
  elseif command == 'toggle_speed' then
    run:cycle()
    send_command('@input /echo SPEED ' .. run.current)
    refresh()
  elseif command == 'cycle_idle' then
    idle_mode:cycle()
    send_command('@input /echo Idle Mode: ' .. idle_mode.current)
    refresh()
  elseif command == 'cycle_tp' then
    tp_mode:cycle()
    send_command('@input /echo TP Mode: ' .. tp_mode.current)
    refresh()
  elseif command == 'cycle_weapon' then
    weapon:cycle()
    send_command('@input /echo Weapon: ' .. weapon.current)
    refresh()
  elseif command == 'cycle_shield' then
    shield:cycle()
    send_command('@input /echo Shield: ' .. shield.current)
    refresh()
  end
end

send_command('wait 1; gs equip idle')
