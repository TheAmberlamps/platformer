local tween = require 'tween'
local grid_square = 16
local grid_width = 20
local grid_height = 11 --+4 pixels
local debrisIndexes = {65, 66, 149, 161, 162, 165}
local map = {}
local colMap = {}
local tweens = {}
local portals = {}
local charTypes = {mask = {166, 167}, tusk = {168, 169}, cultTusk = {152, 153}, spook = {183, 182}}
local gravity = 5

function _init()
  -- Live reload preserves globals across saved edits but resets locals.
  -- Stash mutable game state in a capitalized global like `State` so it
  -- survives reloads; F5 calls _init again to reset.
  State = {
    player = nil,
    characters = {},
    map = {},
    time = 0
  }
  StonePlatform(32, 80, 6)
  PitStone(176, 112, 2)
  SiftMap(State.map)
  Player(48, 16)
  Character(64, 64, charTypes.mask, true)
  --Character(80, 64, charTypes.tusk)
  Character(96, 64, charTypes.spook, false)
  --Character(112, 64, charTypes.cultTusk)
end

function Player(x, y)
  local player = {
    x = x,
    y = y,
    spd = 60,
    spr = {150, 151},
    flip = false,
    velX = 0,
    velY = 0,
    jmp = false,
    fall = true
  }
  State.player = player
end

function SpawnCheck(p)
  local player = p
  for i=1, #colMap do
    if colMap[i][2] > player.x and colMap[i][2] <= player.x + 16 and player.flip == false then
      Character(colMap[i][2], colMap[i][3] - 16, charTypes.mask, false)
    end
    if colMap[i][2] < player.x and colMap[i][2] > player.x - 16 and player.flip == true then
      Character(colMap[i][2], colMap[i][3] - 16, charTypes.tusk, true)
    end
  end
end

function PMovement(p, dt)
  local player = p
  local delta = dt
  local sprite = nil
  if player.fall == true then
    player.velY += gravity * delta
    player.y += player.velY
  end
  if input.held(input.LEFT) then
    player.flip = true
    player.x -= (player.spd * delta)
    if player.x < 16 then
      player.x = 16
    end
  end
  if input.held(input.RIGHT) then
    player.flip = false
    player.x += (player.spd * delta)
    if player.x > usagi.GAME_W - 32 then
      player.x = usagi.GAME_W - 32
    end
  end
  if input.pressed(input.BTN1) and player.jmp == false and player.fall == false then
    player.jmp = true
    player.velY = 60
  end
  if input.pressed(input.BTN2) then
    SpawnCheck(p)
  end
  if player.jmp == true then
    player.y -= player.velY * dt
    player.velY -= gravity
  end
  if math.floor(State.time % 2) == 0 then
    sprite = player.spr[2]
  else
    sprite = player.spr[1]
  end
  gfx.spr_ex(sprite, player.x, player.y, player.flip, false, 0, gfx.COLOR_TRUE_WHITE, 1)
end

function Character(x, y, t, f)
  local char = {
    x = x,
    y = y + 16,
    xVel = 0,
    yVel = 0,
    spr = t,
    flip = f,
    rot = 0,
    alpha = 1,
    type = tostring(t),
    time = State.time,
    mov = false,
    drop = false,
    movTween = nil
  }
  char.movTween = tween.new(1, char, {y = char.y - 16}, 'outQuad')
  table.insert(State.characters, char)
  MakePortal(x, y)
end

function CMovement(c, dt)
  local chars = c
  local tweenVal = nil
  for i=1, #chars do
    if chars[i].movTween then
      tweenVal = chars[i].movTween:update(dt)
      if chars[i].mov == false and tweenVal == true then
        chars[i].mov = true
      end
    end
    if State.time > chars[i].time + 2 and chars[i].mov == true and chars[i].drop == false then
      local scanVal = MoveScan(colMap, chars[i])
      if scanVal == true then
        chars[i].time = State.time
        if chars[i].flip == false then
          chars[i].movTween = tween.new(1, chars[i], {x = chars[i].x + 16}, 'outQuad')
        else
          chars[i].movTween = tween.new(1, chars[i], {x = chars[i].x - 16}, 'outQuad')
        end
      else
        chars[i].drop = true
        if chars[i].flip == false then
          chars[i].movTween = tween.new(1, chars[i], {x = chars[i].x + 16}, 'outQuad')
        else
          chars[i].movTween = tween.new(1, chars[i], {x = chars[i].x - 16}, 'outQuad')
        end
      end
    end
    if chars[i].drop == true then
      if tweenVal == true then
        chars[i].yVel += gravity * dt
        chars[i].y += chars[i].yVel
        if chars[i].flip == false then
          chars[i].rot += math.rad(5)
        else
          chars[i].rot -= math.rad(5)
        end
      end
    end
  end
end

function MakePortal(x, y)
  local portal = {
    x = x,
    y = y,
    a = 0,
    fade = false,
    col = gfx.COLOR_RED,
    tween = nil
  }
  portal.tween = tween.new(1, portal, {a = 0.8})
  table.insert(portals, portal)
end

function DrawPortals(t, dt)
  local port = t
  local alpha = 1 / 16
  local newAlpha = nil
  for i=1, #port do
    local fadeCheck = port[i].tween:update(dt)
    if fadeCheck == true then
      if port[i].fade == false then
        port[i].fade = true
        port[i].tween = tween.new(1, port[i], {a = 0})
      end
    end
    for j=1, 16 do
      gfx.line(port[i].x, port[i].y + (j - 1), port[i].x + 16, port[i].y + (j - 1), port[i].col, alpha * j * port[i].a)
    end
  end
end

function MoveScan(m, c)
  local map = m
  local char = c
  for i=1, #map do
    --print(char.x)
    if char.x + 16 == map[i][2] and char.y + 16 == map[i][3] and char.flip == false then
      return true
    end
    if char.x - 16 == map[i][2] and char.y + 16 == map[i][3] and char.flip == true then
      return true
    end
  end
  return false
end

function CDraw(c)
  local chars = c
  local sprite = nil
  for i=1, #chars do
    if math.floor(State.time % 2) == 0 then
      sprite = chars[i].spr[2]
    else
      sprite = chars[i].spr[1]
    end
    gfx.spr_ex(sprite, chars[i].x, chars[i].y, chars[i].flip, false, chars[i].rot, gfx.COLOR_TRUE_WHITE, chars[i].alpha)
  end
end

function Outline()
  -- top corners
  gfx.spr(70, 0, 0)
  gfx.spr(71, 302, 0)
  -- top and bottom
  for i=1, 18 do
    if i % 2 ~= 0 then
      gfx.spr(69, i * 16, 0)
      gfx.spr(69, i * 16, 160)
    else
      gfx.spr_ex(85, i * 16, 0, true, false, 0, gfx.COLOR_TRUE_WHITE, 1)
      gfx.spr_ex(85, i * 16, 160, true, false, 0, gfx.COLOR_TRUE_WHITE, 1)
    end
  end
  -- bottom corners
  gfx.spr(86, 0, 160)
  gfx.spr(87, 302, 160)
  -- left and right
  for i=1, 9 do
    if i % 2 ~= 0 then
      gfx.spr_ex(69, 0, i * 16, true, false, 0, gfx.COLOR_TRUE_WHITE, 1)
      gfx.spr(85, 302, i * 16)
    else
      gfx.spr_ex(85, 0, i * 16, true, false, 0, gfx.COLOR_TRUE_WHITE, 1)
      gfx.spr(69, 302, i * 16)
    end
  end
end

function Ruin1(x, y)
  local x = x
  local y = y
  gfx.spr(35, x, y)
  gfx.spr(21, x - 16, y)
  gfx.spr(7, x + 16, y)
  gfx.spr(5, x + 16 * 2, y - 16 * 2)
  gfx.spr(21, x, y - 16)
  gfx.spr(37, x + 16 * 2, y - 16)
  gfx.spr(65, x + 16 * 2, y)
  gfx.spr(36, x + 16 * 3, y)
  gfx.spr(20, x + 16 * 3, y - 16)
  gfx.spr(6, x + 16 * 3, y - 16 * 2)
  gfx.spr(7, x + 16 * 4, y)
  gfx.spr(161, x + 16 * 5, y)
end

function StonePlatform(x, y, l)
  local x = x
  local y = y
  local len = l
  local endLength = 0
  --gfx.spr(37, x, y)
  table.insert(State.map, {37, x, y, false})
  --gfx.spr(3, x + 16, y)
  table.insert(State.map, {3, x + 16, y, true})
  for i=1, len -2 do
    endLength = x + 16 * (i + 1)
    --gfx.spr(4, endLength, y)
    table.insert(State.map, {4, endLength, y, true})
  end
  --gfx.spr(1, endLength + 16, y)
  table.insert(State.map, {1, endLength + 16, y, true})
  --gfx.spr(39, endLength + 16 * 2, y)
  table.insert(State.map, {39, endLength + 16 * 2, y, false})
end

function DirtPlatform(x, y, l)
  local x = x
  local y = y
  local len = l
  local endLength = 0
  gfx.spr(145, x, y)
  for i=1, len -2 do
    endLength = x + 16 * i
    gfx.spr(146, endLength, y)
  end
  gfx.spr(147, endLength + 16, y)
end

function Chain(x, y, l)
  local x = x
  local y = y
  local len = l
  for i=1, len do
    if i == len then
      gfx.spr(82, x, y * i)
    else
      gfx.spr(81, x, y * i)
    end
  end
end

function PitStone(x, y, w)
  local x = x
  local y = y
  local w = w
  local endLength = 0
  --gfx.spr(49, x, y)
  table.insert(State.map, {49, x, y, true})
  --gfx.spr(21, x, y + 16)
  table.insert(State.map, {21, x, y+ 16})
  for i=1, w do
    local newLength = x + 16 * i
    endLength = newLength
    --gfx.spr(54, newLength, y)
    table.insert(State.map, {54, newLength, y})
    --gfx.spr(22, newLength, y + 16)
    table.insert(State.map, {22, newLength, y + 16})
  end
  --gfx.spr(23, endLength + 16, y + 16)
  table.insert(State.map, {23, endLength + 16, y + 16})
  --gfx.spr(51, endLength + 16, y)
  table.insert(State.map, {52, endLength + 16, y, true})
end

function CollChk(p, m)
  local player = p
  local map = m
  local playerBox = {x = player.x, y = player.y, w = 16, h = 16}
  for i=1, #map do
    local newBox = {x = map[i][2], y = map[i][3], w = 16, h = 16}
    local result = util.rect_overlap(playerBox, newBox)
    if result == true then
      player.velY = 0
      player.y = newBox.y - 16
      player.fall = false
      player.jmp = false
    end
  end
end

function SiftMap(m)
  local map = m
  for i=1, #map do
    if map[i][4] == true then
      table.insert(colMap, map[i])
    end
  end
end

function DrawMap(m)
  local map = m
  for i=1, #map do
    gfx.spr(map[i][1], map[i][2], map[i][3])
  end
end

function DrawGrid()
  for i=1, grid_width do
    gfx.line(grid_square * i, 0, grid_square * i, usagi.GAME_H, gfx.COLOR_RED)
    -- commented-out not because it doesn't work, but because grids are too small for the text
    for j=1, grid_height do
      gfx.line(0, grid_square * j, usagi.GAME_W, grid_square * j, gfx.COLOR_RED)
      --local text = tostring(i) .. ' ' ..tostring(j)
      --local w, h = usagi.measure_text(text)
      --gfx.text_ex(text, (grid_square * i), (grid_square * j), 1, 0, gfx.COLOR_WHITE, 1)
    end
  end
end

function Removals(t)
  local tab = t
  for i=#tab, 1, -1 do
    if tab[i].y > usagi.GAME_H then
      table.remove(tab, i)
    end
  end
end

function _update(dt)
  State.time += dt
  Removals(State.characters)
  CMovement(State.characters, dt)
  --MoveScan(colMap, State.characters)
end

function _draw(dt)
  gfx.clear(gfx.COLOR_BLACK)
  --StonePlatform(32, 80, 6)
  DirtPlatform(48, 112, 6)
  Chain(144, 16, 1)
  Chain(160, 16, 3)
  Ruin1(48, 64)
  DrawMap(State.map)
  --PitStone(176, 112, 1)
  PMovement(State.player, dt)
  CDraw(State.characters)
  CollChk(State.player, colMap)
  DrawPortals(portals, dt)
  DrawMap(colMap)
  Outline()
  --DrawGrid()
end