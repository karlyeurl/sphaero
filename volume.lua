local gears = gears or require("gears")
local awful = awful or require("awful")
local wibox = wibox or require("wibox")
local naughty = naughty or require("naughty")
local beautiful = beautiful or require("beautiful")

local updateRate = 2
local volumeWidgetNotificationID = -1

--local volBackText = "♪"
--local volOnText = ""
--local volOffText = "="
--local textWidgetFont = "sans 8"
local volBackText = ""
local volOnText = ""
local volOffText = ""
local textWidgetFont = "sans 12"

volumeWidget = wibox.widget {
   {  
      {
         id              = "volumeTextBack",
         font            = textWidgetFont,
         markup          = volBackText,
         widget          = wibox.widget.textbox,
         align           = 'center',
         forced_width    = 15,
      },
      {
         id              = "volumeTextFront",
         font            = textWidgetFont,
         markup          = volOnText,
         widget          = wibox.widget.textbox,
         align           = 'center',
         forced_width    = 15,
      },
      id              = "volumeText",
      layout = wibox.layout.stack
   },
   {
      {
         id           = "volumeProgressbar",
         max_value    = 100,
         value        = 0,
         ticks        = true,
         ticks_size   = 1,
         ticks_gap    = 1,
         border_width = 1,
         background_color = "#000000aa",
         border_color = beautiful.widget_border_color,
         shape        = gears.shape.rounded_bar,
         widget       = wibox.widget.progressbar,
      },
      id              = "volumeContainer",
      forced_height   = 19,
      forced_width    = 8,
      direction       = 'east',
      layout          = wibox.container.rotate,
   },

   layout  = wibox.layout.align.horizontal
}

function updateVolumeWidget(w, notify)
  local function meanChannels(alsaOut)
    local channels = 0
    local totalVolume = 0
    for i in string.gmatch(alsaOut, "%d+") do
      channels = channels + 1
      totalVolume = totalVolume + tonumber(i)
    end
    return math.floor(totalVolume/channels)
  end
  -- this sh command 
  -- sh -c "amixer get 'Master' | sed -n 's/.*\\[\\([[:digit:]]*\\)%].*\\[\\([[:alpha:]]*\\)\\].*/\\1|\\2/p'"
  awful.spawn.easy_async(
    [[sh -c "amixer get 'Master' | sed -n 's/.*\\[\\(.*\\)%].*/\\1/p'"]],
    function(stdout)
      local soundVolume = meanChannels(stdout)
      w.volumeContainer.volumeProgressbar.value = soundVolume
      awful.spawn.easy_async(
      [[sh -c "amixer get 'Master' | sed -n 's/.*\\[\\(\\w*\\)].*/\\1/p' | head -1"]],
      function(sound)
        sound = string.gsub(sound, "\n", "")
        if sound == "off" then
          w.volumeText.volumeTextFront.markup = volOffText
          w.volumeContainer.volumeProgressbar.color = "#ff0000"
          w.volumeContainer.volumeProgressbar.background_color = "#000000aa"
        else
          w.volumeText.volumeTextFront.markup = volOnText
          w.volumeContainer.volumeProgressbar.color = "#4444ff"
          w.volumeContainer.volumeProgressbar.background_color = "#000000aa"
        end
        if notify then
          if sound == "off" then
            naughty.notify({text = "Muted. Volume level: " .. soundVolume .. "%", icon = "/usr/share/icons/Mint-X/status/scalable/audio-volume-muted-symbolic.svg", timeout = 2, replaces_id = volumeWidgetNotificationID})
          elseif soundVolume > 66 then
            naughty.notify({text = "Volume level: " .. soundVolume .. "%", icon = "/usr/share/icons/Mint-X/status/scalable/audio-volume-high-symbolic.svg", timeout = 2, replaces_id = volumeWidgetNotificationID})
          elseif soundVolume > 33 then
            naughty.notify({text = "Volume level: " .. soundVolume .. "%", icon = "/usr/share/icons/Mint-X/status/scalable/audio-volume-medium-symbolic.svg", timeout = 2, replaces_id = volumeWidgetNotificationID})
          elseif soundVolume > 0 then
            naughty.notify({text = "Volume level: " .. soundVolume .. "%", icon = "/usr/share/icons/Mint-X/status/scalable/audio-volume-low-symbolic.svg", timeout = 2, replaces_id = volumeWidgetNotificationID})
          else
            naughty.notify({text = "Volume level: " .. soundVolume .. "%", icon = "/usr/share/icons/Mint-X/status/scalable/audio-volume-muted-symbolic.svg", timeout = 2, replaces_id = volumeWidgetNotificationID})
         end
        end
      end)
    end)
end

updateVolumeWidget(volumeWidget, false)

gears.timer {
    timeout   = updateRate,
    autostart = true,
    callback  = function() updateVolumeWidget(volumeWidget, false) end
}

volumeWidget:connect_signal("button::press", function() updateVolumeWidget(volumeWidget, true) end) 
