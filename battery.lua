local gears = gears or require("gears")
local awful = awful or require("awful")
local wibox = wibox or require("wibox")
local naughty = naughty or require("naughty")
local beautiful = beautiful or require("beautiful")

local updateRate = 5
local gcStep = 85

local batteryAlert = true
local batteryCritical = 15

batteryWidget = wibox.widget {
   -- todo: instead of putting a space, center the text and shift it a little bit
   {
      id              = "batteryText",
      markup          = "⚡",
      widget          = wibox.widget.textbox,
      align           = 'center',
      forced_width    = 15,
   },
   {
      {
         id           = "batteryProgressbar",
         max_value    = 100,
         value        = 100,
         ticks        = true,
         ticks_size   = 1,
         ticks_gap    = 1,
         border_width = 1,
         border_color = beautiful.widget_border_color,
         shape        = gears.shape.rounded_bar,
         widget       = wibox.widget.progressbar,
      },
      id              = "batteryContainer",
      forced_height   = 19,
      forced_width    = 9,
      direction       = 'east',
      layout          = wibox.container.rotate,
   },
   layout  = wibox.layout.align.horizontal
}

local batteryLevel = 0
local batteryStatus = "Unknown"

-- meant to be run once at load of the rc.lua
function batteryUpdaterSync(w)
  file = io.open("/sys/class/power_supply/BAT0/status", "r")
  -- Discharging, Unknown (plugged but not charging?), Charging (?? fully charged) --
  batteryStatus = file:read()
  file:close()
  file = io.open("/sys/class/power_supply/BAT0/capacity", "r")
  batteryLevel = tonumber(file:read())
  file:close()
end

batteryUpdaterSync(batteryWidget)

local lastBatteryAlertID = -1

function showBatteryLevel()
  local status = batteryStatus
  local capa = batteryLevel
  local batteryAlertIcon = ""
  local batteryAlertText = ""
  if status == "Discharging" then
    if capa > 50 then
      batteryAlertIcon = beautiful.battery_good or awful.util.get_configuration_dir() .. "sphaero/notification_icons/battery/battery-good-symbolic.svg"
      batteryAlertText = "Battery remaining is: " .. math.min(capa, 100) .. "%"
    elseif capa > 20 then
      batteryAlertIcon = beautiful.battery_low or awful.util.get_configuration_dir() .. "sphaero/notification_icons/battery/battery-low-symbolic.svg"
      batteryAlertText = "Battery low: " .. capa .. "%"
    else
      batteryAlertIcon = beautiful.battery_critical or awful.util.get_configuration_dir() .. "sphaero/notification_icons/battery/battery-caution-symbolic.svg"
      batteryAlertText = "Battery critically low: " .. capa .. "%"
    end
  elseif status == "Charging" then
    if capa > 99 then
      batteryAlertIcon = beautiful.battery_full_charging or awful.util.get_configuration_dir() .. "sphaero/notification_icons/battery/battery-full-charging-symbolic.svg"
      batteryAlertText = "Battery is full: 100%"
    elseif capa > 50 then
      batteryAlertIcon = beautiful.battery_good_charging or awful.util.get_configuration_dir() .. "sphaero/notification_icons/battery/battery-good-charging-symbolic.svg"
      batteryAlertText = "Battery charging level: " .. capa .. "%"
    elseif capa > 20 then
      batteryAlertIcon = beautiful.battery_low_charging or awful.util.get_configuration_dir() .. "sphaero/notification_icons/battery/battery-low-charging-symbolic.svg"
      batteryAlertText = "Battery low, charging: " .. capa .. "%"
    else
      batteryAlertIcon = beautiful.battery_critical_charging or awful.util.get_configuration_dir() .. "sphaero/notification_icons/battery/battery-caution-charging-symbolic.svg"
      batteryAlertText = "Battery critically low, charging: " .. capa .. "%"
    end
  else
    batteryAlertIcon = beautiful.battery_full_charged or awful.util.get_configuration_dir() .. "sphaero/notification_icons/battery/battery-full-charged-symbolic.svg"
    batteryAlertText = "Battery is full: " .. math.min(capa, 100) .. "%"
  end
  local notification = naughty.notify({ icon = batteryAlertIcon, text = batteryAlertText, timeout = 2, replaces_id = lastBatteryAlertID})
  lastBatteryAlertID = notification.id
end

-- async update for the battery values
function batteryUpdater(w)
  collectgarbage("step", gcStep)
  awful.spawn.easy_async("cat /sys/class/power_supply/BAT0/status", function(stdout, stderr, reason, exit_code)
    batteryStatus = string.gsub(stdout, "\n", "")
    awful.spawn.easy_async("cat /sys/class/power_supply/BAT0/capacity", function(stdout, stderr, reason, exit_code)
      batteryLevel = tonumber(stdout)
      batteryWidgetUpdate(w)
    end)
  end)
end


batteryWidget:connect_signal("button::press", function() batteryUpdater(batteryWidget) end)
batteryWidget:connect_signal("button::press", function() showBatteryLevel() end)

function batteryWidgetUpdate(w)
   local status = batteryStatus
   local value = math.min(tonumber(batteryLevel), 100)
   if value > 50 then -- green to yellow
      -- from [0x00ff00 → 0xffff00[
      charge = 0xffff00 - (math.floor((value-50)*(0xff)/50))*0x10000
      -- from [0x008000 → 0x808000[
      back_charge = (math.floor(charge / 2) & 0xff0000) + (math.floor((charge & 0xff00) / 2) & 0xff00)
   elseif value >= 20 then -- yellow to red
      -- from [0xffff00 → 0xff0000[
      charge = 0xff0000 + (math.floor((value-20)*(0xff)/30))*0x100
      -- from [0x808000 → 0x800000[
      back_charge = 0x800000 + (math.floor((value-20)*(0x80)/30))*0x100
   else
      charge = 0xff0000
      back_charge = 0x800000
   end

   if status == "Discharging" then
      if value < 50 then
         w.batteryText.markup = '<span color="red">–</span>'
         if value < 20 and batteryAlert then
            showBatteryLevel()
            batteryAlert = false
         end
         if value <= batteryCritical then
            batteryCritical = batteryCritical - 1
            showBatteryLevel()
         end
      else
         w.batteryText.markup = '<span color="orange">–</span>'
      end
      w.batteryContainer.batteryProgressbar.color = string.format("#%06x", charge)
      w.batteryContainer.batteryProgressbar.background_color = "#000000aa"
   elseif status == "Charging" then
      batteryAlert = true
      w.batteryText.markup = '<span color="green">+</span>'
      w.batteryContainer.batteryProgressbar.color = string.format("#%06x", charge)
      w.batteryContainer.batteryProgressbar.background_color = string.format("#%06x", back_charge) .. "aa"
   else -- it's fully charged or only on power (no battery inserted)
      w.batteryText.markup = '<span color="yellow">⚡</span>'
      charge = 0x00ff00
      w.batteryContainer.batteryProgressbar.color = string.format("#%06x", charge)
      w.batteryContainer.batteryProgressbar.background_color = string.format("#%06x", back_charge) .. "aa"
   end
   w.batteryContainer.batteryProgressbar.value = value
end

-- is run once when awesome starts
batteryWidgetUpdate(batteryWidget)


gears.timer {
    timeout   = updateRate,
    autostart = true,
    callback  = function() batteryUpdater(batteryWidget) end
}
