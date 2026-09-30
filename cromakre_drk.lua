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
local tp_mode = M({ ['description'] = 'What mode to tp in', 'normal', 'dt' })
local weapon = M({
  ['description'] = 'What weapon to use',
  'Montante',
  'Deathbane',
  'Naegling',
  'Club',
  'Unlocked',
})
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
  equip(sets.weapons[weapon.current], sets.idle[idle_mode.current])
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
    ['Montante'] = { main = 'Montante +1', sub = 'Utu Grip' },
    ['Deathbane'] = { main = 'Deathbane', sub = 'Utu Grip' },
    ['Naegling'] = { main = 'Naegling', sub = 'Blurred Shield' },
    ['Club'] = { main = 'Mafic Cudgel', sub = 'Blurred Shield' },
    ['Unlocked'] = { main = '', sub = '' },
  }

  sets.idle = {}
  sets.idle.dt = {
    ammo = 'Staunch Tathlum',
    head = "Sakpata's Helm",
    body = "Sakpata's Plate",
    hands = "Sakpata's Gauntlets",
    legs = "Sakpata's Cuisses",
    feet = "Sakpata's Leggings",
    neck = 'Loricate Torque',
    waist = 'Ioskeha Belt',
    left_ear = 'Alabaster Earring',
    right_ear = 'Eabani Earring',
    left_ring = "K'ayres Ring",
    right_ring = 'Defending Ring',
    back = 'Grounded Mantle',
  }

  sets.idle.speed = {
    legs = { name = 'Carmine Cuisses +1', augments = { 'HP+80', 'STR+12', 'INT+12' }, hp = 130 },
  }

  sets.tp = {}
  sets.tp.normal = {
    ammo = 'Coiste Bodhar',
    head = 'Flam. Zucchetto +2',
    body = "Sakpata's Plate",
    hands = "Sakpata's Gauntlets",
    legs = 'Ig. Flanchard +2',
    feet = 'Flam. Gambieras +2',
    neck = 'Lissome Necklace',
    waist = 'Ioskeha Belt',
    left_ear = 'Alabaster Earring',
    right_ear = 'Brutal Earring',
    left_ring = 'Hetairoi Ring',
    right_ring = 'Petrov Ring',
    back = 'Grounded Mantle',
  }

  sets.tp.dt = {
    ammo = 'Coiste Bodhar',
    head = "Sakpata's Helm",
    body = "Sakpata's Plate",
    hands = "Sakpata's Gauntlets",
    legs = "Sakpata's Cuisses",
    feet = "Sakpata's Leggings",
    neck = 'Lissome Necklace',
    waist = 'Sailfi Belt +1',
    left_ear = 'Alabaster Earring',
    right_ear = 'Brutal Earring',
    left_ring = 'Defending Ring',
    right_ring = 'Petrov Ring',
    back = 'Grounded Mantle',
  }

  sets.precast = {}
  sets.precast.default = {
    ammo = 'Coiste Bodhar',
    head = "Sakpata's Helm",
    body = "Sakpata's Plate",
    hands = { name = 'Leyline Gloves', augments = { 'Accuracy+10', 'Mag. Acc.+7', '"Fast Cast"+1' } },
    legs = 'Enif Cosciales',
    feet = 'Carmine Greaves',
    neck = 'Voltsurge Torque',
    waist = 'Sailfi Belt +1',
    left_ear = 'Alabaster Earring',
    right_ear = 'Loquac. Earring',
    left_ring = "Naji's Loop",
    right_ring = 'Kishar Ring',
    back = 'Grounded Mantle',
  }

  sets.midcast = {}

  sets.midcast['Dark Magic'] = {}
  sets.midcast['Dark Magic']['Drain'] = set_combine(sets.idle.dt, {
    ammo = 'Ghastly Tathlum +1',
    hands = { name = 'Carmine Fin. Ga.', augments = { 'Rng.Atk.+15', '"Mag.Atk.Bns."+10', '"Store TP"+5' } },
    feet = { name = 'Odyssean Greaves', augments = { 'Attack+12', 'Enmity+6', 'VIT+6', 'Accuracy+3' } },
    neck = 'Sanctity Necklace',
    waist = 'Eschan Stone',
    left_ear = 'Halasz Earring',
    right_ear = 'Hermetic Earring',
    left_ring = 'Excelsis Ring',
    right_ring = 'Archon Ring',
    back = 'Merciful Cape',
  })

  sets.midcast['Dark Magic']['Aspir'] = sets.midcast['Drain']

  sets.midcast['Dark Magic']['Dread Spikes'] = set_combine(sets.idle.dt, {
    ammo = 'Aqreqaq Bomblet',
    head = 'Nyame Helm',
    body = 'Heath. Cuirass +2',
    hands = 'Nyame Gauntlets',
    legs = 'Nyame Flanchard',
    feet = 'Nyame Sollerets',
    neck = 'Sanctity Necklace',
    waist = 'Eschan Stone',
    left_ear = 'Alabaster Earring',
    right_ear = 'Eabani Earring',
    left_ring = "K'ayres Ring",
    right_ring = 'Gelatinous Ring +1',
    back = 'Merciful Cape',
  })
  -- ###############################################################

  -- ###############################################################

  sets.ws = {}
  sets.ws['Torcleaver'] = {
    ammo = 'Knobkierrie',
    head = 'Nyame Helm',
    body = 'Nyame Mail',
    hands = 'Nyame Gauntlets',
    legs = 'Nyame Flanchard',
    feet = 'Nyame Sollerets',
    neck = 'Lissome Necklace',
    waist = 'Sailfi Belt +1',
    left_ear = 'Thrud Earring',
    right_ear = 'Moonshade Earring',
    left_ring = 'Karieyh Ring',
    right_ring = 'Hetairoi Ring',
    back = 'Grounded Mantle',
  }

  sets.ws['Resolution'] = {
    ammo = 'Coiste Bodhar',
    head = 'Flam. Zucchetto +2',
    body = "Sakpata's Plate",
    hands = "Sakpata's Gauntlets",
    legs = "Sakpata's Cuisses",
    feet = 'Flam. Gambieras +2',
    neck = 'Fotia Gorget',
    waist = 'Fotia Belt',
    left_ear = 'Brutal Earring',
    right_ear = 'Moonshade Earring',
    left_ring = 'Petrov Ring',
    right_ring = 'Hetairoi Ring',
    back = 'Grounded Mantle',
  }

  lockstyleset = 11

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
  set_priorities('hp', 'mp')
end

function midcast(spell)
  if spell.skill == 'Enhancing Magic' then
  elseif sets.midcast[spell.skill] then
    if sets.midcast[spell.name] then
      equip(sets.midcast[spell.name])
    end
  elseif spell.type == 'JobAbility' then
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
  end
end

send_command('wait 1; gs equip idle')
