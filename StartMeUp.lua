-- StartMeUp for Farming Simulator 17
-- @description: see modDesc.xml for description and change log
-- @author: Slivicon
--

StartMeUp = {};
StartMeUp.isEnabled = true;
StartMeUp.isInitialized = false;

local modItem = ModsUtil.findModItemByModName(g_currentModName);
StartMeUp.version = (modItem and modItem.version) and modItem.version or "?.?.?";

function StartMeUp:deleteMap()
end

function StartMeUp:draw()
end

function StartMeUp:keyEvent(unicode, sym, modifier, isDown)
end

function StartMeUp:loadMap(name)
end

function StartMeUp:mouseEvent(posX, posY, isDown, isUp, button)
end;

function StartMeUp:update(dt)
  if not StartMeUp.isInitialized then
    StartMeUp.isEnabled = g_currentMission.missionInfo.automaticMotorStartEnabled;
    StartMeUp.isInitialized = true;
  end;
  if g_dedicatedServerInfo ~= nil or g_currentMission.missionInfo.automaticMotorStartEnabled then
    return;
  end;
  if InputBinding.hasEvent(InputBinding.TOGGLE_AMS) then
    if StartMeUp.isEnabled then
      StartMeUp.isEnabled = false;
    else
      StartMeUp.isEnabled = true;
    end;
  end;
  if not g_currentMission.missionInfo.automaticMotorStartEnabled then
    if StartMeUp.isEnabled then
      g_currentMission:addHelpButtonText(g_i18n:getText("smu_disable"), InputBinding.TOGGLE_AMS);
    else
      g_currentMission:addHelpButtonText(g_i18n:getText("smu_enable"), InputBinding.TOGGLE_AMS);
    end;
  end;
end

function StartMeUp.MotorizedOnEnter(self, isControlling)
  if not g_currentMission.missionInfo.automaticMotorStartEnabled then
    if StartMeUp.isEnabled then
      self:startMotor();
    end;
  end;
end

function StartMeUp.MotorizedOnLeave(self)
  if not g_currentMission.missionInfo.automaticMotorStartEnabled then
    if self.stopMotorOnLeave and StartMeUp.isEnabled then
      self:stopMotor();
    end;
  end;
end

if g_dedicatedServerInfo == nil then
  Motorized.onEnter = Utils.prependedFunction(Motorized.onEnter, StartMeUp.MotorizedOnEnter);
  Motorized.onLeave = Utils.prependedFunction(Motorized.onLeave, StartMeUp.MotorizedOnLeave);
end;

addModEventListener(StartMeUp);

print(string.format("Script loaded: StartMeUp.lua (v%s)", StartMeUp.version));
