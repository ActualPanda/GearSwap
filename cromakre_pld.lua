include('Modes')

local lockstyleset = nil
local macro_book = nil
local macro_page = nil

local jp_mode = false

local bindings = {
  ['^#'] = 'gs c echodrops',
  ['^R'] = 'gs c toggle_speed',
  ['^F5'] = 'gs c toggle_phalanx',
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
local phalanx = false

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

local hp_resource_names
local hp_priority_warnings = {}
local hp_assigned_priorities = setmetatable({}, { __mode = 'k' })

local function hp_item_name(piece)
  if piece == empty then
    return 'empty'
  end
  local name = type(piece) == 'table' and piece.name or piece
  if type(name) ~= 'string' then
    return nil
  end
  name = name:lower()
  return hp_resource_names[name] or name
end

local function set_hp_priorities()
  for _, piece in pairs(gearswap.equip_list) do
    local original = type(piece) == 'table' and hp_assigned_priorities[piece]
    if original then
      piece.priority = original.priority
    end
  end

  if next(gearswap.equip_list) == nil then
    return
  end

  if not hp_resource_names then
    hp_resource_names = {}
    for _, item in pairs(gearswap.res.items) do
      local name, log_name = item[language], item[language .. '_log']
      if name then
        hp_resource_names[name:lower()] = name:lower()
        if log_name then
          hp_resource_names[log_name:lower()] = name:lower()
        end
      end
    end
  end

  local catalog, visited = {}, {}

  local function collect(set)
    if type(set) ~= 'table' or visited[set] then
      return
    end
    visited[set] = true

    if type(set.name) == 'string' and type(set.hp) == 'number' then
      local name = hp_item_name(set)
      if name then
        local previous = catalog[name]
        if previous == nil then
          catalog[name] = set
        elseif previous and (previous.hp ~= set.hp or (previous.hp_percent or 0) ~= (set.hp_percent or 0)) then
          catalog[name] = false
        end
      end
    end

    for _, value in pairs(set) do
      collect(value)
    end
  end

  collect(sets)
  collect(gear)

  local function warn(reason)
    if not hp_priority_warnings[reason] then
      gearswap.msg.debugging('HP priorities: keeping manual priorities; ' .. reason)
      hp_priority_warnings[reason] = true
    end
    print(reason)
  end

  local function metadata(piece)
    local name = hp_item_name(piece)
    if name == 'empty' then
      return { hp = 0 }
    end
    if type(piece) == 'table' and type(piece.hp) == 'number' then
      return piece
    end
    return name and catalog[name]
  end

  local future, history = gearswap.equip_list, gearswap.equip_list_history
  local changes, belt = {}, nil
  local old_belt = player.equipment.waist

  if hp_item_name(history.waist) == hp_item_name(old_belt) then
    old_belt = history.waist
  end

  old_belt = metadata(old_belt)
  if not old_belt then
    warn('missing or ambiguous HP metadata for the equipped waist.')
    return
  end

  local current_percent = old_belt.hp_percent or 0

  for slot_id = 0, 15 do
    local slot = gearswap.default_slot_map[slot_id]
    local piece = future[slot]
    local name = hp_item_name(piece)

    if name and not gearswap.encumbrance_table[slot_id] then
      if piece == empty then
        warn('explicit unequips cannot carry an equipment priority.')
        return
      end

      local current = player.equipment[slot]
      if hp_item_name(history[slot]) == hp_item_name(current) then
        current = history[slot]
      end

      local outgoing, incoming = metadata(current), metadata(piece)
      if not outgoing or not incoming then
        warn('missing or ambiguous HP metadata for ' .. slot .. ' (' .. tostring(player.equipment[slot]) .. ').')
        return
      end

      local change = {
        slot = slot,
        piece = piece,
        delta = incoming.hp - outgoing.hp,
        slot_id = slot_id,
      }

      if slot == 'waist' then
        belt = change
        belt.percent = incoming.hp_percent or 0
      else
        if (outgoing.hp_percent or 0) ~= 0 or (incoming.hp_percent or 0) ~= 0 then
          warn('percentage HP outside the waist slot is not supported.')
          return
        end
        changes[#changes + 1] = change
      end
    end
  end

  if #changes == 0 and not belt then
    return
  end

  if type(player.max_hp) ~= 'number' or player.max_hp <= 0 then
    warn('maximum HP is unavailable.')
    return
  end

  table.sort(changes, function(a, b)
    if a.delta == b.delta then
      return a.slot_id < b.slot_id
    end
    return a.delta > b.delta
  end)

  local best_order, best_minimum, best_sum

  for position = 0, (belt and #changes or 0) do
    local order = {}

    for i = 0, #changes do
      if belt and i == position then
        order[#order + 1] = belt
      end
      if changes[i + 1] then
        order[#order + 1] = changes[i + 1]
      end
    end

    local base_hp = math.ceil(player.max_hp / (1 + current_percent / 100) - 0.000001)
    local percent, minimum, sum = current_percent, player.max_hp, 0

    for _, change in ipairs(order) do
      base_hp = base_hp + change.delta
      if belt and change == belt then
        percent = belt.percent
      end

      local maximum = math.floor(base_hp * (1 + percent / 100) + 0.000001)
      minimum = math.min(minimum, maximum)
      sum = sum + maximum
    end

    if not best_order or minimum > best_minimum or (minimum < best_minimum and sum > best_sum) then
      best_order, best_minimum, best_sum = order, minimum, sum
    end
  end

  for i, change in ipairs(best_order) do
    local piece = {}

    if type(change.piece) == 'table' and change.piece ~= empty then
      for key, value in pairs(change.piece) do
        piece[key] = value
      end
    else
      piece.name = change.piece
    end

    if change.piece ~= empty then
      hp_assigned_priorities[piece] = { priority = piece.priority }
      piece.priority = #best_order - i + 1
      future[change.slot] = piece
    end
  end
end

local original_equip = equip

function equip(...)
  original_equip(...)
  set_hp_priorities()
end

local function equip_idle()
  equip(
    sets.weapons[weapon.current],
    sets.shields[shield.current],
    sets.idle[idle_mode.current],
    run.value and sets.idle.speed or {}
  )
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

-- custom functions
------------------------------
function get_sets()
  sets.weapons = {
    ['Sakpata'] = { main = { name = "Sakpata's Sword", hp = 100 } },
    ['Brilliance'] = { main = 'Brilliance' },
    ['Naegling'] = { main = 'Naegling' },
    ['Mafic Cudgel'] = { main = 'Mafic Cudgel' },
    ['Unlocked'] = { main = '' },
  }
  sets.shields = {
    ['Priwen'] = { sub = { name = 'Priwen', hp = 30 } },
  }

  sets.idle = {}
  sets.idle.dt = {
    ammo = { name = 'Staunch Tathlum', hp = 0 },
    head = { name = 'Chev. Armet +2', hp = 135 },
    body = { name = "Sakpata's Plate", hp = 136 },
    hands = { name = "Sakpata's Gauntlets", hp = 91 },
    legs = { name = 'Chev. Cuisses +2', hp = 117 },
    feet = { name = "Sakpata's Leggings", hp = 68 },
    neck = { name = 'Elite Royal Collar', hp = 0 },
    waist = { name = 'Platinum Moogle Belt', hp = 0, hp_percent = 10 },
    left_ear = { name = 'Alabaster Earring', hp = 100 },
    right_ear = { name = 'Tuisto Earring', hp = 150 },
    left_ring = { name = "Warden's Ring", hp = 0 },
    right_ring = { name = 'Supershear Ring', hp = 30 },
    back = { name = "Rudianos's Mantle", augments = { 'HP+60', 'Eva.+20 /Mag. Eva.+20', 'Enmity+10' }, hp = 60 },
  }

  sets.idle.speed = {
    legs = { name = 'Carmine Cuisses +1', augments = { 'HP+80', 'STR+12', 'INT+12' }, hp = 130 },
  }

  sets.tp = {}
  sets.tp.dt = {
    ammo = { name = 'Staunch Tathlum', hp = 0 },
    head = { name = 'Chev. Armet +2', hp = 135 },
    body = { name = "Sakpata's Plate", hp = 136 },
    hands = { name = "Sakpata's Gauntlets", hp = 91 },
    legs = { name = 'Chev. Cuisses +2', hp = 117 },
    feet = { name = "Sakpata's Leggings", hp = 68 },
    neck = { name = 'Elite Royal Collar', hp = 0 },
    waist = { name = 'Platinum Moogle Belt', hp = 0, hp_percent = 10 },
    left_ear = { name = 'Alabaster Earring', hp = 100 },
    right_ear = { name = 'Tuisto Earring', hp = 150 },
    left_ring = { name = "Warden's Ring", hp = 0 },
    right_ring = { name = 'Supershear Ring', hp = 30 },
    back = { name = "Rudianos's Mantle", augments = { 'HP+60', 'Eva.+20 /Mag. Eva.+20', 'Enmity+10' }, hp = 60 },
  }

  sets.precast = {}
  sets.precast.default = {
    ammo = { name = 'Staunch Tathlum', hp = 0 },
    head = { name = 'Chev. Armet +2', hp = 135 },
    body = { name = "Sakpata's Plate", hp = 136 },
    hands = {
      name = 'Souv. Handsch. +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 239,
    },
    legs = {
      name = 'Souv. Diechlings +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 161,
    },
    feet = { name = 'Chev. Sabatons +2', hp = 42 },
    neck = { name = 'Voltsurge Torque', hp = 0 },
    waist = { name = 'Creed Baudrier', hp = 40 },
    left_ear = { name = 'Alabaster Earring', hp = 100 },
    right_ear = { name = 'Tuisto Earring', hp = 150 },
    left_ring = { name = 'Defending Ring', hp = 0 },
    right_ring = { name = 'Kishar Ring', hp = 0 },
    back = {
      name = "Rudianos's Mantle",
      augments = { 'HP+60', 'Eva.+20 /Mag. Eva.+20', 'Enmity+10' },
      hp = 60,
    },
  }

  sets.midcast = {}
  sets.midcast.full_enmity = {
    ammo = { name = 'Staunch Tathlum', hp = 0 },
    head = {
      name = 'Souveran Schaller',
      augments = { 'HP+80', 'Enmity+7', 'Potency of "Cure" effect received +10%' },
      hp = 205,
    }, -- 7
    body = {
      name = 'Souveran Cuirass',
      augments = { 'HP+80', 'Enmity+7', 'Potency of "Cure" effect received +10%' },
      hp = 146,
    },
    hands = {
      name = 'Souv. Handsch. +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 239,
    }, -- 5
    legs = {
      name = 'Souv. Diechlings +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 162,
    }, -- 9
    feet = {
      name = 'Eschite Greaves',
      augments = { 'Mag. Evasion+15', 'Spell interruption rate down +15%', 'Enmity+7' },
      hp = 18,
    }, -- 15
    neck = { name = 'Moonbeam Necklace', hp = 0 },
    waist = { name = 'Creed Baudrier', hp = 40 },
    left_ear = { name = 'Alabaster Earring', hp = 100 },
    right_ear = { name = 'Tuisto Earring', hp = 150 },
    left_ring = { name = 'Apeile Ring', hp = 0 },
    right_ring = { name = 'Supershear Ring', hp = 30 },
    back = { name = "Rudianos's Mantle", augments = { 'HP+60', 'Eva.+20 /Mag. Eva.+20', 'Enmity+10' }, hp = 60 },
  }
  sets.midcast.sird = {
    ammo = { name = 'Staunch Tathlum', hp = 0 },
    head = {
      name = 'Souveran Schaller',
      augments = { 'HP+80', 'Enmity+7', 'Potency of "Cure" effect received +10%' },
      hp = 205,
    },
    body = { name = 'Chev. Cuirass +2', hp = 141 },
    hands = {
      name = 'Souv. Handsch. +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 239,
    },
    legs = { name = 'Carmine Cuisses +1', augments = { 'HP+80', 'STR+12', 'INT+12' }, hp = 130 },
    feet = {
      name = 'Odyssean Greaves',
      augments = { 'Attack+12', 'Enmity+6', 'VIT+6', 'Accuracy+3' },
      hp = 20,
    },
    neck = { name = 'Moonbeam Necklace', hp = 0 },
    waist = { name = 'Rumination Sash', hp = 0 },
    left_ear = { name = 'Alabaster Earring', hp = 100 },
    right_ear = { name = 'Tuisto Earring', hp = 150 },
    left_ring = { name = 'Defending Ring', hp = 0 },
    right_ring = { name = "K'ayres Ring", hp = 70 },
    back = { name = "Rudianos's Mantle", augments = { 'HP+60', 'Eva.+20 /Mag. Eva.+20', 'Enmity+10' }, hp = 60 },
  }

  -- +32 phalanx - with Sakpata and Priwen
  sets.midcast['Phalanx'] = set_combine(sets.idle.dt, {
    head = { name = 'Yorium Barbuta', augments = { 'Phalanx +3' }, hp = 41 }, -- +3
    body = { name = 'Yorium Cuirass', augments = { 'Phalanx +3' }, hp = 113 }, -- +3
    hands = {
      name = 'Souv. Handsch. +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 239,
    }, -- +5
    feet = {
      name = 'Souveran Schuhs +1',
      augments = { 'HP+105', 'Enmity+9', 'Potency of "Cure" effect received +15%' },
      hp = 227,
    }, -- 5
    legs = { name = "Sakpata's Cuisses", hp = 144 }, -- +5
    neck = { name = 'Sanctity Necklace', hp = 35 },
    waist = { name = 'Creed Baudrier', hp = 40 },
    back = { name = 'Weard Mantle', augments = { 'VIT+3', 'DEX+2', 'Enmity+6', 'Phalanx +4' }, hp = 40 }, -- +4
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
end

function midcast(spell)
  if sets.midcast[spell.name] then
    equip(sets.midcast[spell.name])
  elseif sets.midcast[spell.skill] then
    equip(sets.midcast[spell.skill])
  elseif spell.type == 'JobAbility' then
    equip(sets.midcast.full_enmity)
  end
end

function aftercast()
  refresh()
end

function sub_job_change()
  set_macros()
  set_lockstyle()
  equip_idle()
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
  elseif command == 'toggle_phalanx' then
    phalanx = not phalanx
    if phalanx then
      equip(sets.midcast['Phalanx'])
    else
      refresh()
    end
  end
end

send_command('wait 1; gs equip idle')
