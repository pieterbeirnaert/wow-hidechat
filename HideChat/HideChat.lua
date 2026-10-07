-- HideChat: hide the chat windows, show them again while typing.
-- Toggle with the minimap button, /hidechat, or a key binding.

local ADDON_NAME = ...

-- Chat-related frames beyond the numbered chat windows and their tabs.
local EXTRA_FRAMES = {
  "GeneralDockManager",
  "ChatFrameMenuButton",
  "ChatFrameChannelButton",
  "ChatFrameToggleVoiceDeafenButton",
  "ChatFrameToggleVoiceMuteButton",
  "QuickJoinToastButton",
}

local db
local typing = false
local applying = false
local hooked = {}
local wantShown = {} -- frames Blizzard wants visible while we keep them hidden
local minimapButton

local function suppressed()
  return db and db.hidden and not typing
end

local function managedFrames()
  local list, seen = {}, {}
  local function add(name)
    local frame = _G[name]
    if frame and not seen[frame] then
      seen[frame] = true
      list[#list + 1] = frame
    end
  end
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    add("ChatFrame" .. i)
    add("ChatFrame" .. i .. "Tab")
  end
  if CHAT_FRAMES then
    for _, name in ipairs(CHAT_FRAMES) do
      add(name)
      add(name .. "Tab")
    end
  end
  for _, name in ipairs(EXTRA_FRAMES) do
    add(name)
  end
  return list
end

-- Keep Blizzard's own Show/Hide calls from undoing ours, and remember what
-- it wanted so we can restore exactly that.
local function hookFrame(frame)
  if hooked[frame] then return end
  hooked[frame] = true
  hooksecurefunc(frame, "Show", function(self)
    if applying or not suppressed() then return end
    wantShown[self] = true
    applying = true
    self:Hide()
    applying = false
  end)
  hooksecurefunc(frame, "Hide", function(self)
    if applying or not suppressed() then return end
    wantShown[self] = nil
  end)
  if frame.SetShown then
    hooksecurefunc(frame, "SetShown", function(self, shown)
      if applying or not suppressed() then return end
      if shown then
        wantShown[self] = true
        applying = true
        self:Hide()
        applying = false
      else
        wantShown[self] = nil
      end
    end)
  end
end

local function updateMinimapIcon()
  if not minimapButton then return end
  minimapButton.icon:SetDesaturated(db.hidden)
  minimapButton.icon:SetAlpha(db.hidden and 0.6 or 1)
end

local function apply()
  if not db then return end
  if suppressed() then
    for _, frame in ipairs(managedFrames()) do
      hookFrame(frame)
      if frame:IsShown() then
        wantShown[frame] = true
        applying = true
        frame:Hide()
        applying = false
      end
    end
  else
    applying = true
    for frame in pairs(wantShown) do
      frame:Show()
    end
    applying = false
    wipe(wantShown)
  end
  updateMinimapIcon()
end

local function notify(text)
  -- Chat may be hidden, so give feedback on screen instead.
  UIErrorsFrame:AddMessage("HideChat: " .. text, 1, 0.82, 0)
end

local function setHidden(hidden)
  db.hidden = hidden
  apply()
  notify(hidden and "chat hidden (press Enter to type)" or "chat shown")
end

function HideChat_Toggle()
  if db then setHidden(not db.hidden) end
end

-- Minimap button -------------------------------------------------------------

local function positionMinimapButton()
  local angle = math.rad(db.minimapAngle or 210)
  local radius = (Minimap:GetWidth() / 2) + 10
  minimapButton:ClearAllPoints()
  minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function onDragUpdate()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  px, py = px / scale, py / scale
  db.minimapAngle = math.deg(math.atan2(py - my, px - mx))
  positionMinimapButton()
end

local function createMinimapButton()
  local button = CreateFrame("Button", "HideChatMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(20, 20)
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetPoint("TOPLEFT", 7, -5)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
  icon:SetPoint("TOPLEFT", 7, -6)
  button.icon = icon

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", HideChat_Toggle)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", onDragUpdate)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("HideChat")
    GameTooltip:AddLine(db.hidden and "Chat is hidden" or "Chat is visible", 1, 1, 1)
    GameTooltip:AddLine("Click to toggle, drag to move", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  minimapButton = button
  positionMinimapButton()
  button:SetShown(db.showMinimap)
end

-- Show chat while typing ------------------------------------------------------

hooksecurefunc("ChatEdit_ActivateChat", function(editBox)
  if not (db and db.hidden) or typing then return end
  typing = true
  apply()
  if editBox and not editBox:HasFocus() then
    editBox:SetFocus()
  end
end)

hooksecurefunc("ChatEdit_DeactivateChat", function()
  if not typing then return end
  typing = false
  apply()
end)

-- New whisper/temporary windows get hidden too.
for _, fn in ipairs({ "FCF_OpenTemporaryWindow", "FCF_OpenNewWindow" }) do
  if _G[fn] then hooksecurefunc(fn, apply) end
end

-- Slash command ---------------------------------------------------------------

SLASH_HIDECHAT1 = "/hidechat"
SlashCmdList.HIDECHAT = function(msg)
  msg = strlower(strtrim(msg or ""))
  if msg == "on" then
    setHidden(true)
  elseif msg == "off" then
    setHidden(false)
  elseif msg == "minimap" then
    db.showMinimap = not db.showMinimap
    minimapButton:SetShown(db.showMinimap)
    notify(db.showMinimap and "minimap button shown" or "minimap button hidden")
  else
    HideChat_Toggle()
  end
end

-- Startup ---------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    HideChatDB = HideChatDB or {}
    db = HideChatDB
    if db.hidden == nil then db.hidden = true end
    if db.showMinimap == nil then db.showMinimap = true end
    createMinimapButton()
    self:UnregisterEvent("ADDON_LOADED")
  elseif event == "PLAYER_ENTERING_WORLD" then
    apply()
  end
end)

BINDING_HEADER_HIDECHAT = "HideChat"
BINDING_NAME_HIDECHAT_TOGGLE = "Toggle chat"
