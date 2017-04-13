local gears = gears or require("gears")
local awful = awful or require("awful")
local wibox = wibox or require("wibox")
local naughty = naughty or require("naughty")
local beautiful = beautiful or require("beautiful")

local updateRate = 2
local memText = ""
local memTextFont = "sans 11"
--local memText = "⚙"

memoryWidget = wibox.widget {
   -- todo: instead of putting a space, center the text and shift it a little bit
   {
      id              = "memoryText",
      markup          = memText,
      font            = memTextFont,
      widget          = wibox.widget.textbox,
      align           = 'center',
      forced_width    = 15,
   },
   {
      {
         id           = "memoryProgressbar",
         max_value    = 100,
         value        = 0,
         ticks        = true,
         ticks_size   = 1,
         ticks_gap    = 1,
         border_width = 1,
         color        = "#fe560d",
         background_color = "#000000aa",
         border_color = beautiful.widget_border_color,
         shape        = gears.shape.rounded_bar,
         widget       = wibox.widget.progressbar,
      },
	   id              = "memoryContainer",
      forced_height   = 19,
      forced_width    = 8,
      direction       = 'east',
      layout          = wibox.container.rotate,
   },
   layout  = wibox.layout.align.horizontal
}

function updateMemoryWidget(w)
  awful.spawn.easy_async(
    [[sh -c "free | grep Mem | awk '{print $3/$2 * 100.0}'"]],
    function(stdout)
      w.memoryContainer.memoryProgressbar.value = math.floor(stdout)
    end)
end

updateMemoryWidget(memoryWidget)

gears.timer {
    timeout   = updateRate,
    autostart = true,
    callback  = function() updateMemoryWidget(memoryWidget) end
}

memoryWidget:connect_signal("button::press", function() updateMemoryWidget(memoryWidget) end) 
