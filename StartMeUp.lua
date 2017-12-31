-- StartMeUp for Farming Simulator 17
-- @description: This mod provides support for Automatic Motor Start when using the Seasons mod
-- @author: Slivicon
-- Change Log stored in modDesc.xml
--

StartMeUp = {};
StartMeUp.isApplied = false;

local modItem = ModsUtil.findModItemByModName(g_currentModName);
StartMeUp.version = (modItem and modItem.version) and modItem.version or "?.?.?";

function StartMeUp:apply()
  if g_seasons ~= nil then -- This is how the Seasons mod asks to be identified
    g_inGameMenu.motorStartElement:setDisabled(false); -- Seasons disables the Auto Engine Start game settings menu item, so this re-enables it
    if StartMeUp.savedMotorStartEnabled then -- Required for MP compatibility, this checks that a flag has been set indicating the savegame file has Auto Engine Start enabled
      g_inGameMenu.motorStartElement:setIsChecked(true); -- Seasons selects "Off", this selects "On", as per the savegame file
      g_currentMission:setAutomaticMotorStartEnabled(true); -- Seasons turns off Auto Engine Start, this turns it back on, as per the savegame file
    end;
    --Seasons appends a function to set the Auto Engine Start game setting menu item to "Off" and disable it, this is appended after Seasons, to undo that
    InGameMenu.updateGameSettings = Utils.appendedFunction(InGameMenu.updateGameSettings, self.enableAutoMotorStart);
    --BEGIN code to find other mod functions, credit: Decker_MMIV, VehicleGroupsSwitcher mod
    local env = getfenv(0);
    for modName, enabled in pairs(g_modIsLoaded) do
      if env[modName] ~= nil then
        if StartMeUp.refMotorFailure == nil then
          if env[modName].ssMotorFailure ~= nil then
            StartMeUp.refMotorFailure = env[modName].ssMotorFailure;
            --Overwrite the Seasons ssMotorFailure spec update function, to allow engine breakdown function when player has chosen Auto Engine Start
            env[modName].ssMotorFailure.update = Utils.overwrittenFunction(env[modName].ssMotorFailure.update, StartMeUp.ssMotorFailureUpdate);
          end;
        end;
        if StartMeUp.refVehicle == nil then
          if env[modName].ssVehicle ~= nil then
            -- Reference the Seasons ssVehicle class so that the overwritten ssMotorFailure.update function can access its calculateOverdueFactor function
            StartMeUp.refVehicle = env[modName].ssVehicle;
          end;
        end;
      end;
    end;
    --END code to find other mod functions, credit: Decker_MMIV, VehicleGroupsSwitcher mod
  end;
end

function StartMeUp:deleteMap()
end;

function StartMeUp:draw()
end;

function StartMeUp:enableAutoMotorStart()
  -- Seasons disables the Auto Engine Start game setting menu item, this enables it
  self.motorStartElement:setDisabled(false);
  if g_currentMission.missionInfo.automaticMotorStartEnabled then
    self.motorStartElement:setIsChecked(true); -- If Auto Engine Start is enabled, then set the menu item to "On"
  end;
end;

function StartMeUp:keyEvent(unicode, sym, modifier, isDown)
end;

function StartMeUp:loadMap(name)
  if g_seasons ~= nil and g_currentMission:getIsServer() then
    --Get the automaticMotorStartEnabled value from the savegame file
    local xml = g_currentMission.missionInfo.xmlFile;
    if xml ~= nil then
      local key = Utils.getNoNil(g_currentMission.missionInfo.xmlKey, "") .. ".settings.automaticMotorStartEnabled";
      if hasXMLProperty(xml, key) then
        StartMeUp.savedMotorStartEnabled = getXMLBool(xml, key);
      else
        StartMeUp.savedMotorStartEnabled = true;
      end;
    else
      StartMeUp.savedMotorStartEnabled = true;
    end;
  end;
end;

function StartMeUp:mouseEvent(posX, posY, isDown, isUp, button)
end;

function StartMeUp:ssMotorFailure(obj)
  if g_currentMission.missionInfo.automaticMotorStartEnabled then
    g_currentMission:onLeaveVehicle(); -- Simulate the effect of a motor breakdown turning off the engine when Auto Engine Start is enabled, by leaving the vehicle
    g_currentMission:showBlinkingWarning(g_i18n:getText("smu_breakdown")); -- Notify player that an engine breakdown has occurred
  else
    obj:stopMotor(); -- Auto Engine Start is disabled, so simply call the stopMotor function for an engine breakdown as Seasons would do.
  end;
end;

--from Seasons 1.2.1.0 ssMotorFailure.lua, edited to support players who wish to use AutoEngineStart
function StartMeUp:ssMotorFailureUpdate(superFunc, dt)
  if self:getIsMotorStarted() then
    self.ssSmoothLoadPercentage = (self.actualLoadPercentage - self.ssSmoothLoadPercentage) * dt / 5000 + self.ssSmoothLoadPercentage
    if self.isClient and self:getIsActiveForSound() and SoundUtil.isSamplePlaying(self.sampleMotorStart, 1.5 * dt) then
      if self.ssMotorStartSoundTime + self.ssMotorStartFailDuration < g_currentMission.time then
        if self.ssMotorStartTries > 1 then
          SoundUtil.stopSample(self.sampleMotorStart, false);
          SoundUtil.playSample(self.sampleMotorStart, 1, 0, nil);
          self.ssMotorStartTries = self.ssMotorStartTries - 1;
          self.ssMotorStartSoundTime = g_currentMission.time;
        elseif self.ssMotorStartTries == 1 and self.ssMotorStartMustFail then
          StartMeUp:ssMotorFailure(self); -- Seasons simply calls stopMotor, here we call our own function to support AutoEngineStart players
        end;
      end;
    elseif self.isServer and self.motorStartTime < g_currentMission.time and self.refVehicle ~= nil then
      local overdueFactor = self.refVehicle:calculateOverdueFactor(self); -- Here we reference the Seasons ssVehicle class
      local breakdownLoadFactor = Utils.clamp((self.ssSmoothLoadPercentage - 0.5) * 20, 0, 10);
      local p = math.max(2 - overdueFactor ^ 0.001 , 0.2) ^ (1 / 1000 * overdueFactor ^ (2.5 + breakdownLoadFactor));
      if math.random() > p then
        self.ssHasMotorBrokenDown = true;
        if self:getIsHired() then
          self:stopAIVehicle(AIVehicle.STOP_REASON_UNKNOWN); -- Seasons enhancement would be to look into providing an appropriate reason and alert to player
        else
          StartMeUp:ssMotorFailure(self); -- Seasons simply calls stopMotor, here we call our own function to support AutoEngineStart players
        end;
      end;
    end;
  end;
  superFunc(self, dt); --Call the overwritten Seasons function for any further actions, since we have already completed any necessary engine breakdown
end;

function StartMeUp:update(dt)
  if g_seasons ~= nil and not StartMeUp.isApplied then
    StartMeUp:apply(); --Apply settings once during the update function, as it needs to happen after Seasons has completely loaded
    StartMeUp.isApplied = true;
  end;
end;

addModEventListener(StartMeUp);

print(string.format("Script loaded: StartMeUp.lua (v%s)", StartMeUp.version));
