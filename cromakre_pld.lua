include('Modes')

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

local idle_mode = M({ ['description'] = 'What mode to idle in', 'dt' })
local tp_mode = M({ ['description'] = 'What mode to tp in', 'dt' })
local weapon = M({
  ['description'] = 'What weapon to use',
  'Sakpata',
  'Brilliance',
  'Naegling',
  'Mafic Cudgel',
  'Unlocked',
})
local shield = M({ ['description'] = 'What shield to use', 'Priwen', 'Unlocked' })
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
  equip(sets.weapons[weapon.current], sets.shields[shield.current], sets.idle[idle_mode.current])
  if run.value then
    equip(sets.idle.speed)
  end
end

local function equip_tp()
  equip(sets.weapons[weapon.current], sets.shields[shield.current], sets.tp[tp_mode.current])
end

local function refresh()
  if player.status == 'Engaged' then
    equip_tp()
  elseif player.status == 'Idle' then
    equip_idle()
  end
end

local function weathercheck(spell_element, set)
  if not set then
    return
  end
  if spell_element == world.weather_element or spell_element == world.day_element then
    equip(set, sets.obis[spell_element])
  else
    equip(set)
  end
  if set[spell_element] then
    equip(set[spell_element])
  end
end

local function set_priorities(key)
  local future, current = gearswap.equip_list, gearswap.equip_list_history
  local function get_val(piece, key)
    if piece and type(piece) == 'table' and piece[key] and type(piece[key]) == 'number' then
      return piece[key]
    end
    return 0
  end
  for i, v in pairs(future) do
    local priority = get_val(future[i], key) - get_val(current[i], key)
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
    ['Unlocked'] = { main = '' },
  }
  sets.shields = {
    ['Priwen'] = { sub = 'Priwen' },
  }

  sets.idle = {}
  sets.idle.dt = {
    ammo = 'Staunch Tathlum',
    head = { name = 'Chev. Armet +2', hp = 135 },
    body = { name = "Sakpata's Plate", hp = 136 },
    hands = {
      name = 'Souv. Handsch. +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 239,
    },
    legs = { name = 'Chev. Cuisses +2', hp = 117 },
    feet = { name = "Sakpata's Leggings", hp = 68 },
    neck = { name = 'Elite Royal Collar' },
    waist = { name = 'Creed Baudrier', hp = 40 },
    left_ear = { name = 'Alabaster Earring', hp = 100 },
    right_ear = { name = 'Tuisto Earring', hp = 150 },
    left_ring = { name = "Warden's Ring" },
    right_ring = { name = "K'ayres Ring", hp = 70 },
    back = { name = "Rudianos's Mantle", augments = { 'HP+60', 'Eva.+20 /Mag. Eva.+20', 'Enmity+10' }, hp = 60 },
  }

  sets.idle.speed = {
    legs = { name = 'Carmine Cuisses +1', augments = { 'HP+80', 'STR+12', 'INT+12' }, hp = 130 },
  }

  sets.tp = {}
  sets.tp.dt = {
    ammo = 'Staunch Tathlum',
    head = { name = 'Chev. Armet +2', hp = 135 },
    body = { name = "Sakpata's Plate", hp = 136 },
    hands = {
      name = 'Souv. Handsch. +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 239,
    },
    legs = { name = 'Chev. Cuisses +2', hp = 117 },
    feet = { name = "Sakpata's Leggings", hp = 68 },
    neck = { name = 'Elite Royal Collar' },
    waist = { name = 'Creed Baudrier', hp = 40 },
    left_ear = { name = 'Alabaster Earring', hp = 100 },
    right_ear = { name = 'Tuisto Earring', hp = 150 },
    left_ring = { name = "Warden's Ring" },
    right_ring = { name = "K'ayres Ring", hp = 70 },
    back = { name = "Rudianos's Mantle", augments = { 'HP+60', 'Eva.+20 /Mag. Eva.+20', 'Enmity+10' }, hp = 60 },
  }

  sets.precast = {}
  sets.precast.default = {
    body = { name = "Sakpata's Plate", hp = 136 },
    hands = {
      name = 'Souv. Handsch. +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 239,
    },
    legs = {
      name = 'Souv. Diechlings +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%', hp = 162 },
    },
    head = { name = 'Chev. Armet +2', hp = 135 },
    left_ear = { name = 'Alabaster Earring', hp = 100 },
    back = {
      name = "Rudianos's Mantle",
      augments = { 'HP+60', 'Eva.+20 /Mag. Eva.+20', 'Enmity+10' },
      priority = 7,
      hp = 60,
    },
    waist = { name = 'Creed Baudrier', hp = 40 },
    feet = { name = 'Carmine Greaves', augments = { 'HP+60', 'MP+60', 'Phys. dmg. taken -3' }, hp = 75 },
    left_ring = { name = "K'ayres Ring", hp = 70 },
    neck = { name = 'Voltsurge Torque', mp = 20 },
    right_ear = { name = 'Tuisto Earring', hp = 150 },
    right_ring = { name = 'Kishar Ring' },
    ammo = 'Staunch Tathlum',
  }

  sets.midcast = {}
  sets.midcast.full_enmity = {
    hands = {
      name = 'Souv. Handsch. +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 239,
    }, -- 5
    head = {
      name = 'Souveran Schaller',
      augments = { 'HP+80', 'Enmity+7', 'Potency of "Cure" effect received +10%' },
      hp = 205,
    }, -- 7
    legs = {
      name = 'Souv. Diechlings +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 162,
    }, -- 9
    right_ear = { name = 'Tuisto Earring', hp = 150 },
    body = {
      name = 'Souveran Cuirass',
      augments = { 'HP+80', 'Enmity+7', 'Potency of "Cure" effect received +10%' },
      priority = 10,
      hp = 146,
    },
    left_ear = { name = 'Alabaster Earring', hp = 100 },
    back = { name = "Rudianos's Mantle", augments = { 'HP+60', 'Eva.+20 /Mag. Eva.+20', 'Enmity+10' }, hp = 60 },
    waist = { name = 'Creed Baudrier', hp = 40 },
    right_ring = { name = 'Supershear Ring', hp = 30 },
    feet = {
      name = 'Eschite Greaves',
      augments = { 'Mag. Evasion+15', 'Spell interruption rate down +15%', 'Enmity+7' },
      hp = 18,
    }, -- 15
    left_ring = { name = 'Apeile Ring', priority = 4 },
    neck = { name = 'Moonbeam Necklace', priority = 2 },
    ammo = { name = 'Staunch Tathlum', priority = 1 },
  }
  sets.midcast.sird = {
    hands = {
      name = 'Souv. Handsch. +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 239,
    },
    head = {
      name = 'Souveran Schaller',
      augments = { 'HP+80', 'Enmity+7', 'Potency of "Cure" effect received +10%' },
      hp = 205,
    },
    right_ear = { name = 'Tuisto Earring', hp = 150 },
    body = { name = 'Chev. Cuirass +2', hp = 141 },
    legs = { name = 'Carmine Cuisses +1', augments = { 'HP+80', 'STR+12', 'INT+12' }, hp = 130 },
    left_ear = { name = 'Alabaster Earring', hp = 100 },
    right_ring = { name = "K'ayres Ring", hp = 70 },
    back = { name = "Rudianos's Mantle", augments = { 'HP+60', 'Eva.+20 /Mag. Eva.+20', 'Enmity+10' }, hp = 60 },
    waist = { name = 'Rumination Sash' },
    feet = {
      name = 'Odyssean Greaves',
      augments = { 'Attack+12', 'Enmity+6', 'VIT+6', 'Accuracy+3' },
      hp = 20,
    },
    left_ring = { name = 'Defending Ring' },
    neck = { name = 'Moonbeam Necklace' },
    ammo = { name = 'Staunch Tathlum' },
  }

  -- +24 phalanx
  sets.midcast['Phalanx'] = set_combine(sets.idle.dt, {
    head = { name = 'Yorium Barbuta', augments = { 'Phalanx +3' }, hp = 41 }, -- +3
    body = { name = 'Yorium Cuirass', augments = { 'Phalanx +3' }, hp = 113 }, -- +3
    hands = {
      name = 'Souv. Handsch. +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 239,
    }, -- +5
    feet = {
      name = 'Souveran Schuhs',
      augments = { 'HP+80', 'Enmity+7', 'Potency of "Cure" effect received +10%' },
      hp = 152,
    }, -- +4
    right_ear = { name = 'Tuisto Earring', hp = 150 },
    legs = { name = "Sakpata's Cuisses", hp = 144 }, -- +5
    neck = { name = 'Sanctity Necklace', hp = 35 },
    waist = { name = 'Creed Baudrier', hp = 40 },
    back = { name = 'Weard Mantle', augments = { 'VIT+3', 'DEX+2', 'Enmity+6', 'Phalanx +4' } },
  })
  -- ###############################################################

  -- ###############################################################
  sets.midcast['Healing Magic'] = sets.midcast.sird
  sets.midcast['Enhancing Magic'] = sets.midcast.sird
  sets.midcast['Divine Magic'] = sets.midcast.sird
  sets.midcast['Blue Magic'] = sets.midcast.sird

  sets.midcast['Flash'] = sets.midcast.full_enmity
  sets.midcast['Jettatura'] = sets.midcast.full_enmity

  sets.midcast['Savage Blade'] = sets.midcast.full_enmity
  sets.midcast['Requiescat'] = sets.midcast.full_enmity
  sets.midcast['Chant du Cygne'] = sets.midcast.full_enmity
  sets.midcast['Atonement'] = set_combine(sets.midcast.full_enmity, {
    ammo = "Oshasha's Treatise",
  })

  sets.midcast['Divine Emblem'] = set_combine(sets.midcast.full_enmity, {
    feet = { name = 'Chev. Sabatons +2', hp = 42 },
  })

  lockstyleset = 14

  macro_book = 7
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
  if string.match(spell.type, 'Magic$') then
    equip(sets.precast.default)
  end
  set_priorities('hp')
end

function midcast(spell)
  if sets.midcast[spell.name] then
    equip(sets.midcast[spell.name])
  elseif sets.midcast[spell.skill] then
    equip(sets.midcast[spell.skill])
  elseif spell.type == 'JobAbility' then
    equip(sets.midcast.full_enmity)
  end

  set_priorities('hp')
end

function aftercast()
  refresh()
  set_priorities('hp')
end

function status_change(new)
  refresh()
  set_priorities('hp')
end

function sub_job_change()
  set_macros()
  set_lockstyle()
  equip_idle()
  set_priorities('hp')
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
