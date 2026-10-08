local tween = require 'tween'
local dandelion = require 'dandelion'
local grid_square = 16
local grid_width = 20
local grid_height = 11 --+4 pixels
local debrisIndexes = {65, 66, 149, 161, 162, 165}
local map = {}
local colMap = {}
local tweens = {}
local portals = {}
local skulls = {}
local charTypes = {mask = {166, 167}, tusk = {168, 169}, cultTusk = {152, 153}, spook = {183, 182, 184, 185}}
local gravity = 5
local intro = true

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
  --Rope(128, 80, 0, false)
  Rope(224, 112, 1, false)
  PitStone(176, 112, 2)
  SiftMap(State.map)
  Player(48, 16)
  --Character(96, 64, charTypes.tusk, false)
  Character(64, 64, charTypes.tusk, true)
  Character(112, 64, charTypes.spook, false)
  --Character(128, 64, charTypes.cultTusk, false)
  --Character(80, 64, charTypes.mask, false)
  intro = false
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
      Character(colMap[i][2], colMap[i][3] - 16, charTypes.mask, true)
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
    sfx.play("jump")
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
    y = y,
    xVel = 0,
    yVel = 0,
    spr = t,
    flip = f,
    rot = 0,
    alpha = 1,
    type = t,
    time = State.time,
    rope = false,
    cast = false,
    summon = false,
    climb = false,
    mov = true,
    drop = false,
    emote = false,
    movTween = nil,
  }
  if char.type == charTypes.tusk then
    char.rope = true
  end
  if char.type == charTypes.spook then
    char.cast = true
  end
  table.insert(State.characters, char)
  if intro == false then
    char.move = false
    char.y += 16
    char.movTween = tween.new(1, char, {y = char.y - 16}, 'outQuad')
    sfx.play('synth')
    MakePortal(x, y)
  end
end

function Climbing(m, c, ci, t)
  local map = m
  local char = c
  local charInd = ci
  local tweenCheck = t
  for i=1, #map do
    if map[i][1] == 8 and char.x == map[i][2] and tweenCheck == true then
      if char.flip == false then
        char.flip = true
        char.movTween = tween.new(1, char, {x = char.x + 16}, 'outQuad')
      else
        char.flip = false
        char.movTween = tween.new(1, char, {x = char.x - 16}, 'outQuad')
      end
    end
    local tile = map[i][1]
    if tile == 9 or tile == 25 or tile == 41 then
      if tweenCheck == true and map[i][2] == char.x and map[i][3] == char.y then
        char.movTween = tween.new(1, char, {y = char.y + 16}, 'outQuad')
      end
    end
    if tile == 57 and tweenCheck == true and map[i][2] == char.x and map[i][3] == char.y then
      local groundVal = false
      for i=1, #colMap do
        if char.y + 16 == colMap[i][3] then
          print("Touchdown!")
          groundVal = true
        end
      end
      if groundVal == true then
        char.mov = true
        char.climb = false
        if char.flip == false then
            char.flip = true
          else
            char.flip = false
          end
      else
        print("line 187, this is where the state of the character changes")
        -- oh wait is this a reference to the value that needs to be changed instead of the actual thing?...
        --State.characters[charInd].drop = true
        --State.characters[charInd].emote = true
        -- evidently not, what the fuck is happening?
        char.drop = true
        char.emote = true
        char.climb = false
        char.mov = true
        char.movTween = tween.new(1, char, {y = char.y + 16}, "outQuad")
      end
    end
  end
end

function CMovement(c, dt) 
  local chars = c
  local tweenVal = nil
  local delta = dt
  for i=1, #chars do
    local mainChar = chars[i]
    if mainChar.movTween then
      tweenVal = mainChar.movTween:update(dt)
      -- commenting-out because it seems to not exist for a good reason
      --if chars[i].mov == false and tweenVal == true then
        --print("for some reason")
        --chars[i].mov = true
      --end
    end
    if mainChar.drop == true then
      if tweenVal == true then
        print(mainChar.y)
        print(mainChar.yVel)
        mainChar.yVel += gravity * delta
        print(mainChar.yVel)
        mainChar.y += mainChar.yVel
        print(mainChar.y)
        --print(debug.traceback("Message!"))
        if mainChar.emote == true then
          mainChar.emote = false
          dandelion.Spawn("bubble_burst", mainChar.x + 8, mainChar.y + 4)
        end
        if mainChar.flip == false then
          mainChar.rot += math.rad(5)
        else
          mainChar.rot -= math.rad(5)
        end
      end
    end
    if mainChar.climb == true then
      -- climbing function here
      Climbing(State.map, mainChar, i, tweenVal)
    end
    if State.time > mainChar.time + 2 and mainChar.mov == true and mainChar.drop == false then
      local scanVal = MoveScan(colMap, mainChar)
      if scanVal == true then
        mainChar.time = State.time
        if mainChar.flip == false then
          mainChar.movTween = tween.new(1, mainChar, {x = mainChar.x + 16}, 'outQuad')
          return
        else
          mainChar.movTween = tween.new(1, mainChar, {x = mainChar.x - 16}, 'outQuad')
          return
        end
      elseif scanVal == 'rope' then
        mainChar.climb = true
        print("setting rope")
        if mainChar.flip then
          Rope(mainChar.x, mainChar.y + 16, 1, true)
        else
          Rope(mainChar.x, mainChar.y + 16, 0, false)
        end
      elseif scanVal == 'cast' then
        PlatSpell(mainChar.x, mainChar.y + 16, mainChar)
      else
        mainChar.drop = true
        mainChar.emote = true
        print("walking off a ledge")
        if mainChar.flip == false then
          mainChar.movTween = tween.new(1, mainChar, {x = mainChar.x + 16}, 'outQuad')
        else
          mainChar.movTween = tween.new(1, mainChar, {x = mainChar.x - 16}, 'outQuad')
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
    col = gfx.COLOR_ORANGE,
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
      local offset = 0
      if j < 5 then
        offset = 3
      elseif j < 9 then
        offset = 2
      elseif j < 13 then
        offset = 1
      end
      gfx.line(port[i].x - offset, port[i].y + (j - 1), port[i].x + 16 + offset, port[i].y + (j - 1), port[i].col, alpha * j * port[i].a)
    end
  end
end

-- this doesn't seem to work currently
function RopeCheck(m, c)
    local map = m
    local char = c
    for i=1, #map do
      if char.flip == false then
        if map[i][2] + 16 == char.x + 16 and map[i][1] == 9 then
          print("Absolutely")
        end
      else
        if map[i][2] - 16 == char.x - 16 and map[i][1] == 9 then
          print("Trabsolutely")
        end
      end
    end
end

function MoveScan(m, c)
  local map = m
  local char = c
  -- if this is the collision map then this won't work
  local ropeMap = State.map
  RopeCheck(ropeMap, char)
  for i=1, #map do
    if char.x == map[i][2] and char.y + 16 == map[i][3] then
      -- aha this is triggering twice because it's being run on both maps?
      -- seems not... very strange
      --print('OK')
      --print(i)
    end
    if char.x + 16 == map[i][2] and char.y + 16 == map[i][3] and char.flip == false then
      return true
    end
    if char.x - 16 == map[i][2] and char.y + 16 == map[i][3] and char.flip == true then
      return true
    end
  end
  if char.rope == true then
    char.rope = false
    char.mov = false
    print("returning 'rope'")
    --print(char.x / 16)
    --print(char.y / 16)
    return 'rope'
  end
  if char.cast == true then
    char.mov = false
    return 'cast'
  end
  return false
end

-- seems clear, can't find a reason why this would be resetting char.y
function CDraw(c)
  local chars = c
  local sprite = nil
  for i=1, #chars do
    if math.floor(State.time % 2) == 0 then
      sprite = chars[i].spr[2]
    else
      sprite = chars[i].spr[1]
    end
    if chars[i].cast == true and chars[i].mov == false then
      if math.floor(State.time % 2) == 0 then
        sprite = chars[i].spr[4]
        -- lol, time to find a more appropriate place to fire these off so they don't get spammed... at least this solves why plat_drip was acting so strangely
        -- weird that prayer is throwing nil, too... I wonder if "text" only displays numbers for some reason?
        -- so it turns out it threw nil because to properly supply a string, it had to be a string inside a string. In fact I think that every argument in particles 
      else
        sprite = chars[i].spr[3]
      end
      if State.time > chars[i].time + 2 then
        chars[i].time = State.time
        dandelion.Spawn("plat_drip", chars[i].x + 15, chars[i].y + 16)
        if math.random() > 0.5 then
          dandelion.Spawn("prayer1", chars[i].x + 8, chars[i].y)
        else
          dandelion.Spawn("prayer2", chars[i].x + 8, chars[i].y)
        end
      end
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
  --print(endLength)
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

function Rope(x, y, l, f)
  local x = x
  local y = y
  local len = l
  local flip = f
  table.insert(State.map, {8, x, y - 16, false, flip})
  if flip then
    table.insert(State.map, {9, x - 16, y - 16, false, flip})
    table.insert(State.map, {25, x - 16, y, false, flip})
    for i=1, len do
      table.insert(State.map, {41, x - 16, y + 16 * i, false, flip})
    end
    table.insert(State.map, {57, x - 16, y + 16 * (len + 1), false, flip})
  else  
    table.insert(State.map, {9, x + 16, y - 16, false, flip})
    table.insert(State.map, {25, x + 16, y, false, flip})
    for i=1, len do
      table.insert(State.map, {41, x + 16, y + 16 * i, false, flip})
    end
    table.insert(State.map, {57, x + 16, y + 16 * (len + 1), false, flip})
  end
end

-- currently only applies in one direction, and there's no condition to remove platforms if the spook stops casting
function PlatSpell(x, y, c)
  local x = x
  local y = y
  local char = c
  for i=1, 2 do
    table.insert(colMap, {40, x + 16 * i, y})
  end
end

function Skull(x, y)
  local x = x
  local y = y
  local skull = {
    x = x,
    y = y,
    tween = nil,
    a = 1
  }
  skull.tween = tween.new(1, skull, {y = y - 16}, 'outQuad')
  table.insert(skulls, skull)
  sfx.play('hitHurt')
end

function SkullDraw(t, dt)
  local tab = t
  for i=#tab, 1, -1 do
    gfx.spr(24, tab[i].x, tab[i].y, tab[i].a)
    local check = tab[i].tween:update(dt)
    if check == true then
      if tab[i].a < 1 then
        table.remove(skulls, i)
      else
        tab[i].tween = tween.new(1, tab[i], {a = 0}, 'outQuad')
      end
    end
  end
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
  local flip = false
  for i=1, #map do
    if map[i][5] then
      gfx.spr_ex(map[i][1], map[i][2], map[i][3], map[i][5], false, 0, gfx.COLOR_TRUE_WHITE, 1)
    else
      gfx.spr_ex(map[i][1], map[i][2], map[i][3], false, false, 0, gfx.COLOR_TRUE_WHITE, 1)
    end
  end
end

local displayNum = 0

function DrawGrid()
  if input.pressed(input.BTN3) then
    displayNum += 1
    if displayNum > 2 then
      displayNum = 0
    end
  end
  for i=1, grid_width do
    gfx.line(grid_square * i, 0, grid_square * i, usagi.GAME_H, gfx.COLOR_RED)
    -- commented-out not because it doesn't work, but because grids are too small for the text
    -- well this might work instead
    for j=1, grid_height do
      gfx.line(0, grid_square * j, usagi.GAME_W, grid_square * j, gfx.COLOR_RED)
      local textW = tostring(i - 1)
      local textH = tostring(j - 1)
      local textChoice = ''
      if displayNum > 0 then
        if displayNum < 2 then
          textChoice = textW
        else
          textChoice = textH
        end
      end
      local wi, hi = usagi.measure_text(textW)
      local wj, hj = usagi.measure_text(textH)
      gfx.text_ex(textChoice, (grid_square * (i - 1)), (grid_square * (j - 1)), 1, 0, gfx.COLOR_WHITE, 1)
    end
  end
end

function Removals(t)
  local tab = t
  for i=#tab, 1, -1 do
    if tab[i].y > usagi.GAME_H then
      Skull(tab[i].x, usagi.GAME_H - 16)
      --Character(96, 64, tab[i].type, false)
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
  dandelion.DrawExcept()
  CDraw(State.characters)
  CollChk(State.player, colMap)
  DrawPortals(portals, dt)
  DrawMap(colMap)
  SkullDraw(skulls, dt)
  Outline()
  DrawGrid()
end