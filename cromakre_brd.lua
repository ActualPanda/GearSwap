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
  'Naegling',
  'Mafic Cudgel',
  'Unlocked',
})
local shield = M({ ['description'] = 'What shield to use', 'Culminus', 'Unlocked' })
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
    ['Naegling'] = { main = 'Naegling' },
    ['Mafic Cudgel'] = { main = 'Mafic Cudgel' },
    ['Unlocked'] = { main = '' },
  }
  sets.shields = {
    ['Culminus'] = { sub = 'Culminus' },
  }

  sets.idle = {}
  sets.idle.dt = {
    head = 'Nyame Helm',
    body = 'Ayanmo Corazza +2',
    hands = 'Aya. Manopolas +2',
    legs = 'Aya. Cosciales +2',
    feet = 'Nyame Sollerets',
    neck = 'Loricate Torque',
    waist = 'Sailfi Belt +1',
    left_ear = 'Brutal Earring',
    right_ear = 'Alabaster Earring',
    left_ring = 'Defending Ring',
    right_ring = 'Gelatinous Ring +1',
    back = { name = 'Mecisto. Mantle', augments = { 'Cap. Point+49%', 'MND+1', 'Rng.Acc.+5', 'DEF+6' } },
  }

  sets.idle.speed = {
    legs = { name = 'Carmine Cuisses +1', augments = { 'HP+80', 'STR+12', 'INT+12' }, hp = 130 },
  }

  sets.tp = {}
  sets.tp.dt = {}

  sets.precast = {}
  sets.precast.fastcast = set_combine(sets.idle.dt, {
    body = 'Inyanga Jubbah +2',
    hands = 'Gende. Gages +1',
    legs = 'Aya. Cosciales +2',
    neck = 'Voltsurge Torque',
    waist = 'Embla Sash',
    left_ear = 'Loquac. Earring',
    left_ring = 'Kishar Ring',
    right_ring = "Naji's Loop",
  })

  sets.precast.songs = set_combine(sets.precast.fastcast, {
    head = "Aoidos' Calot +1",
  })

  sets.midcast = {}
  -- ###############################################################

  -- ###############################################################
  sets.midcast['Healing Magic'] = sets.midcast.sird
  sets.midcast['Enhancing Magic'] = sets.midcast.sird
  sets.midcast['Divine Magic'] = sets.midcast.sird

  lockstyleset = 12

  macro_book = 18
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
    equip(sets.precast.fastcast)
  elseif string.match(spell.type, "Song$") then
    equip(sets.precast.songs)
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
