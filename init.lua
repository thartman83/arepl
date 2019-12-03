-------------------------------------------------------------------------------
-- init.lua for arepl                                                        --
-- Copyright (c) 2019 Tom Hartman (thomas.lees.hartman@gmail.com)            --
--                                                                           --
-- This program is free software; you can redistribute it and/or             --
-- modify it under the terms of the GNU General Public License               --
-- as published by the Free Software Foundation; either version 2            --
-- of the License, or the License, or (at your option) any later             --
-- version.                                                                  --
--                                                                           --
-- This program is distributed in the hope that it will be useful,           --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of            --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             --
-- GNU General Public License for more details.                              --
-------------------------------------------------------------------------------

--- Commentary -- {{{
-- arepl is the Awesome Read Eval Print Loop console
-- }}}

--- arepl -- {{{
--- Libraries -- {{{
local awful = require("awful")
local wibox = require("wibox")
local gtable = require("gears.table")
local gstring = require("gears.string")
local gmath = require("gears.math")
local theme = require("beautiful")
--local serpent = require("serpent")
local load = loadstring or load
local pcall = pcall
local capi = {
   client = client,
   mouse = mouse,
   screen = screen
}

local function get_screen(s)
    return s and capi.screen[s]
end

function gtable.cat(t, sep)
   local retval = ""
   for i, v in ipairs(t) do
      if retval == "" then
         retval = v
      else
         retval = retval .. sep .. v
      end
   end

   return retval
end

function gtable.last(t, n)
   local len = table.getn(t)
   local ret = {}
   for i = (len - 10 > 0) and len - 10 or 1,len do
      table.insert(ret,t[i]) 
   end
   return ret
end
-- }}}

local arepl = { }

--- arepl:run_prompt -- {{{
-- 
function arepl:run_prompt ()
   self.prompt_args.active = true
   awful.prompt.run(setmetatable(self.prompt_args, {__index={}}))
end
-- }}}

--- arepl:eval_prompt -- {{{
-- 
function arepl:eval_prompt (command)
   table.insert(self.hist, self.prompt_text .. command)

   local succ, ret = pcall(load(command))

   if not succ then
      print(type(ret))
      print(ret)
   end
   
   if type(ret) == "string" or type(ret) == "number" then
      table.insert(self.hist, "  " .. ret)
   elseif ret ~= nil then
      table.insert(self.hist, "  " .. serpent.block(ret) )
   end
   
   self:refresh()
end
-- }}}

--- arepl:refresh -- {{{
-- 
function arepl:refresh()
   self.msghistory.text = gtable.cat(gtable.last(self.hist, self.line_count), "\n")
end
-- }}}

--- arepl:handle_error -- {{{
-- 
function arepl:handle_error (err)
   -- prevent an infinite loop
   if self.in_error then return end
   self.in_error = true

   table.insert(self.hist, "  " .. err)
   self.in_error = false
   self:refresh()
   self.prompt_args.active = false
   --  self:run_prompt()
   --  self.prompt:run()
end
-- }}}

--- show -- {{{
--
function arepl:show(scr)
   if self.wibox.visible == true then
      self:hide()
      return
   end

   scr = get_screen(src or awful.screen.focused() or 1)

   -- connect to the debug signal and capture the debug errors
   awesome.connect_signal("debug::error", function (err) self:handle_error(err) end)

   self:run_prompt()

   local scrgeom = scr.workarea
   local geom = { x = scrgeom.x,
                  y = scrgeom.y,
                  height = gmath.round(theme.get_font_height() * 1.5) * self.line_count,
                  width = gmath.round(self.line_width * theme.get_font_height()) + (theme.menu_border_width or 0) * 2  }
   self.wibox:geometry(geom)
   self.msghistory.forced_height = gmath.round(theme.get_font_height() * 1.5) * (self.line_count - 2)
   self.msghistory.forced_width = geom.width
   self.msghistory.text = gtable.cat(self.hist, "\n")

   self.wibox.visible = true
end
-- }}}

--- arepl:hide -- {{{
-- 
function arepl:hide ()
   awesome.disconnect_signal("debug::error", function (err) self:handle_error(err) end)
   self.wibox.visible = false
end
-- }}}

--- new -- {{{
local function new(args)
   local obj = {}
   gtable.crush(obj, arepl, true)

   local args = args or {}

   local fg_color = theme.menubar_fg_normal or theme.menu_fg_normal or theme.fg_normal
   local bg_color = theme.menubar_bg_normal or theme.menu_bg_normal or theme.bg_normal
   local border_width = theme.menubar_border_width or theme.menu_border_width or 0
   local border_color = theme.menubar_border_color or theme.menu_border_color
   
   -- Initialize members
   obj.line_count = args.line_count or 20
   obj.line_width = 80
   obj.geometry = { width  = nil,
                   height  = nil,
                   x      = nil,
                   y      = nil }   
   obj.prompt_text = " ▶ "
   obj.prompt = awful.widget.prompt()
   obj.msghistory = wibox.widget {
      align = 'left',
      valign = 'top',
      widget = wibox.widget.textbox()
   }
   obj.wibox =  wibox {
      ontop = true,
      bg = bg_color,
      fg = fg_color,
      opacity = .7,
      border_width = border_width,
      border_color = border_color
   }
   
   local layout = wibox.widget {
      spacing = 10,
      spacing_widget = wibox.widget { orientation = horizontal,
                                      thickness = 2,
                                      color = fg_color,
                                      widget = wibox.widget.seperator
      },
      layout = wibox.layout.fixed.vertical
   }
   layout:add(obj.msghistory)
   layout:add(obj.prompt)
   obj.wibox:set_widget(layout)
   obj.hist = { }

   obj.prompt_args = {
      prompt = obj.prompt_text,
      textbox = obj.prompt.widget,
      exe_callback = function(c) obj:eval_prompt(c) end,
      done_callback = function() if obj.prompt_args.active then obj:run_prompt() else obj:hide() end end,
      hooks = { { { "Mod4"} , "`", function (c) obj.prompt_args.active = false return "", false end } }
   }
   
   return obj
end
-- }}}

return setmetatable(arepl, {__call = function(_,...) return new(...) end})
-- }}}
