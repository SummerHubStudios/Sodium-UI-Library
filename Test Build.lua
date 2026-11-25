--[[
    SODIUM UI LIBRARY
    Dark window, lime accent, hexagon close button, side toggle tab.

    local Sodium = loadstring(...)()   -- or require(module)
    local Window = Sodium:CreateWindow({ Title = "SODIUM", ToggleKey = Enum.KeyCode.RightShift })
    local Tab = Window:CreateTab("Main")
    Tab:AddSection("Combat")
    Tab:AddButton({ Name = "Hello", Callback = function() print("hi") end })
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local Sodium = {}
Sodium.__index = Sodium

local Theme = {
	Accent = Color3.fromRGB(153, 255, 87),
	AccentDark = Color3.fromRGB(46, 70, 32),
	Window = Color3.fromRGB(50, 50, 50),
	TitleBar = Color3.fromRGB(34, 34, 34),
	Content = Color3.fromRGB(20, 20, 20),
	Element = Color3.fromRGB(36, 36, 36),
	ElementHover = Color3.fromRGB(48, 48, 48),
	Stroke = Color3.fromRGB(30, 30, 30),
	Text = Color3.fromRGB(235, 235, 235),
	SubText = Color3.fromRGB(150, 150, 150),
	Dark = Color3.fromRGB(15, 15, 15),
	TitleFont = Enum.Font.GothamBlack,
	Font = Enum.Font.GothamBold,
	BodyFont = Enum.Font.GothamMedium,
}

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------
local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color, thickness)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function tween(inst, props, t)
	local tw = TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function safe(cb, ...)
	if typeof(cb) == "function" then
		local ok, err = pcall(cb, ...)
		if not ok then
			warn("[Sodium] callback error: " .. tostring(err))
		end
	end
end

local function getParent()
	local ok, ui = pcall(function()
		return gethui and gethui()
	end)
	if ok and ui then
		return ui
	end
	local ok2 = pcall(function()
		return CoreGui.Name
	end)
	if ok2 then
		return CoreGui
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- hexagon built from 3 rotated rectangles (no image assets needed)
local function hexagon(parent, size, color, pos, anchor)
	local holder = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Position = pos or UDim2.new(),
		AnchorPoint = anchor or Vector2.zero,
		Rotation = 90, -- pointy top like the design
		Parent = parent,
	})
	for _, rot in ipairs({ 0, 60, 120 }) do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size * 0.5774),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Rotation = rot,
			Parent = holder,
		})
	end
	return holder
end

local function setHexColor(hex, color)
	for _, f in ipairs(hex:GetChildren()) do
		if f:IsA("Frame") then
			f.BackgroundColor3 = color
		end
	end
end

----------------------------------------------------------------------
-- Library
----------------------------------------------------------------------
function Sodium:CreateWindow(opts)
	opts = opts or {}
	local title = opts.Title or "SODIUM"
	local toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift

	local Window = setmetatable({}, { __index = Sodium })
	Window.Tabs = {}
	Window.Connections = {}
	Window.Visible = true

	local gui = new("ScreenGui", {
		Name = "SodiumUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		IgnoreGuiInset = true,
		Parent = getParent(),
	})
	Window.Gui = gui

	-- side toggle button (the little square on the left)
	local toggleBtn = new("TextButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 28, 0.5, 0),
		Size = UDim2.fromOffset(93, 74),
		BackgroundColor3 = Theme.Window,
		AutoButtonColor = false,
		Text = title,
		TextColor3 = Theme.Accent,
		TextSize = 17,
		Font = Theme.TitleFont,
		Parent = gui,
	}, { corner(8), stroke(Theme.Stroke, 3) })

	-- main window
	local main = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(976, 614),
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0,
		Parent = gui,
	}, { corner(24) })
	Window.Main = main

	local scale = new("UIScale", { Parent = main })
	local function updateScale()
		local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min((vp.X - 160) / 976, (vp.Y - 40) / 614), 0.4, 1)
	end
	updateScale()
	if Workspace.CurrentCamera then
		table.insert(Window.Connections, Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
	end

	-- title bar
	local titleBar = new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.TitleBar,
		BorderSizePixel = 0,
		Parent = main,
	}, { corner(24) })
	new("Frame", { -- squares off the bottom of the title bar
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.TitleBar,
		BorderSizePixel = 0,
		Parent = titleBar,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		Text = title,
		TextColor3 = Theme.Accent,
		TextSize = 38,
		Font = Theme.TitleFont,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = titleBar,
	})

	-- hexagon close button
	local hexOuter = hexagon(titleBar, 38, Theme.AccentDark, UDim2.new(1, -16, 0.5, 0), Vector2.new(1, 0.5))
	local hexInner = hexagon(hexOuter, 32, Theme.Accent, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local closeBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(38, 38),
		BackgroundTransparency = 1,
		Text = "X",
		TextColor3 = Color3.fromRGB(15, 15, 15),
		TextSize = 18,
		Font = Theme.TitleFont,
		Parent = titleBar,
	})
	closeBtn.MouseEnter:Connect(function()
		setHexColor(hexInner, Color3.fromRGB(190, 255, 140))
	end)
	closeBtn.MouseLeave:Connect(function()
		setHexColor(hexInner, Theme.Accent)
	end)

	-- content area
	local content = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(16, 68),
		Size = UDim2.new(1, -32, 1, -84),
		BackgroundColor3 = Theme.Content,
		BorderSizePixel = 0,
		Parent = main,
	}, { corner(24) })

	local sidebar = new("ScrollingFrame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(0, 150, 1, -28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = content,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	new("Frame", {
		Position = UDim2.fromOffset(176, 18),
		Size = UDim2.new(0, 2, 1, -36),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		Parent = content,
	})

	local pages = new("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(190, 14),
		Size = UDim2.new(1, -204, 1, -28),
		BackgroundTransparency = 1,
		Parent = content,
	})

	-- notifications
	local notifyHolder = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(280, 400),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	----------------------------------------------------------------
	-- window behaviour
	----------------------------------------------------------------
	function Window:SetVisible(v)
		Window.Visible = v
		main.Visible = v
		tween(toggleBtn, { BackgroundColor3 = v and Theme.Window or Theme.ElementHover })
	end

	function Window:Toggle()
		Window:SetVisible(not Window.Visible)
	end

	function Window:Destroy()
		for _, c in ipairs(Window.Connections) do
			c:Disconnect()
		end
		gui:Destroy()
	end

	toggleBtn.MouseButton1Click:Connect(function()
		Window:Toggle()
	end)
	closeBtn.MouseButton1Click:Connect(function()
		Window:SetVisible(false)
	end)
	table.insert(
		Window.Connections,
		UserInputService.InputBegan:Connect(function(input, gp)
			if not gp and input.KeyCode == toggleKey then
				Window:Toggle()
			end
		end)
	)

	-- dragging (title bar)
	do
		local dragging, startInput, startPos, startMouse
		titleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				startMouse = input.Position
				startPos = main.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		titleBar.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				startInput = input
			end
		end)
		table.insert(
			Window.Connections,
			UserInputService.InputChanged:Connect(function(input)
				if dragging and input == startInput then
					local d = input.Position - startMouse
					main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
				end
			end)
		)
	end

	----------------------------------------------------------------
	-- notify
	----------------------------------------------------------------
	function Window:Notify(o)
		o = o or {}
		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Window,
			BackgroundTransparency = 1,
			Parent = notifyHolder,
		}, {
			corner(12),
			stroke(Theme.Accent, 1),
			new("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			new("UIListLayout", { Padding = UDim.new(0, 2) }),
		})
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			Text = o.Title or "SODIUM",
			TextColor3 = Theme.Accent,
			TextSize = 15,
			Font = Theme.TitleFont,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = o.Content or "",
			TextWrapped = true,
			TextColor3 = Theme.Text,
			TextSize = 13,
			Font = Theme.BodyFont,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		tween(frame, { BackgroundTransparency = 0 }, 0.2)
		task.delay(o.Duration or 4, function()
			if frame.Parent then
				tween(frame, { BackgroundTransparency = 1 }, 0.2).Completed:Wait()
				frame:Destroy()
			end
		end)
	end

	----------------------------------------------------------------
	-- tabs
	----------------------------------------------------------------
	function Window:CreateTab(name)
		local Tab = {}
		Tab.__index = Tab

		local btn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = Theme.Element,
			AutoButtonColor = false,
			Text = name,
			TextColor3 = Theme.SubText,
			TextSize = 15,
			Font = Theme.Font,
			LayoutOrder = #Window.Tabs + 1,
			Parent = sidebar,
		}, { corner(10) })

		local page = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.Accent,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = pages,
		}, {
			new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			new("UIPadding", { PaddingRight = UDim.new(0, 8) }),
		})

		Tab.Button = btn
		Tab.Page = page
		table.insert(Window.Tabs, Tab)

		local function select()
			for _, t in ipairs(Window.Tabs) do
				t.Page.Visible = false
				tween(t.Button, { BackgroundColor3 = Theme.Element, TextColor3 = Theme.SubText })
			end
			page.Visible = true
			tween(btn, { BackgroundColor3 = Theme.Accent, TextColor3 = Theme.Dark })
		end
		Tab.Select = select
		btn.MouseButton1Click:Connect(select)
		if #Window.Tabs == 1 then
			select()
		end

		local order = 0
		local function row(height)
			order += 1
			return new("Frame", {
				Size = UDim2.new(1, 0, 0, height),
				BackgroundColor3 = Theme.Element,
				BorderSizePixel = 0,
				LayoutOrder = order,
				ClipsDescendants = true,
				Parent = page,
			}, { corner(10), stroke(Theme.Stroke, 1) })
		end

		local function nameLabel(parent, text)
			return new("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -90, 0, 40),
				Text = text,
				TextColor3 = Theme.Text,
				TextSize = 14,
				Font = Theme.Font,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = parent,
			})
		end

		function Tab:AddSection(text)
			order += 1
			new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				Text = string.upper(text),
				TextColor3 = Theme.Accent,
				TextSize = 13,
				Font = Theme.TitleFont,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = order,
				Parent = page,
			})
		end

		function Tab:AddLabel(text)
			local r = row(36)
			local l = new("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -24, 1, 0),
				Text = text,
				TextColor3 = Theme.SubText,
				TextSize = 13,
				Font = Theme.BodyFont,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = r,
			})
			return { Set = function(_, t) l.Text = t end }
		end

		function Tab:AddButton(o)
			local r = row(40)
			local b = new("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				Parent = r,
			})
			nameLabel(r, o.Name or "Button")
			hexagon(r, 16, Theme.Accent, UDim2.new(1, -20, 0.5, 0), Vector2.new(1, 0.5))
			b.MouseEnter:Connect(function() tween(r, { BackgroundColor3 = Theme.ElementHover }) end)
			b.MouseLeave:Connect(function() tween(r, { BackgroundColor3 = Theme.Element }) end)
			b.MouseButton1Click:Connect(function()
				tween(r, { BackgroundColor3 = Theme.AccentDark }, 0.08).Completed:Connect(function()
					tween(r, { BackgroundColor3 = Theme.ElementHover })
				end)
				safe(o.Callback)
			end)
		end

		function Tab:AddToggle(o)
			local r = row(40)
			local state = o.Default == true
			nameLabel(r, o.Name or "Toggle")
			local pill = new("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(40, 20),
				BackgroundColor3 = Theme.Content,
				Parent = r,
			}, { corner(10), stroke(Theme.Stroke, 1) })
			local knob = new("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 3, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = Theme.SubText,
				Parent = pill,
			}, { corner(7) })
			local api = {}
			local function render()
				tween(pill, { BackgroundColor3 = state and Theme.Accent or Theme.Content })
				tween(knob, {
					Position = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
					BackgroundColor3 = state and Theme.Dark or Theme.SubText,
				})
			end
			function api:Set(v, silent)
				state = v and true or false
				render()
				if not silent then safe(o.Callback, state) end
			end
			function api:Get() return state end
			new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = r }).MouseButton1Click:Connect(function()
				api:Set(not state)
			end)
			render()
			if state then safe(o.Callback, state) end
			return api
		end

		function Tab:AddSlider(o)
			local min, max, inc = o.Min or 0, o.Max or 100, o.Increment or 1
			local value = math.clamp(o.Default or min, min, max)
			local r = row(54)
			nameLabel(r, o.Name or "Slider").Size = UDim2.new(1, -90, 0, 32)
			local valLabel = new("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 0),
				Size = UDim2.fromOffset(70, 32),
				Text = tostring(value),
				TextColor3 = Theme.Accent,
				TextSize = 14,
				Font = Theme.Font,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = r,
			})
			local bar = new("Frame", {
				Position = UDim2.new(0, 12, 1, -16),
				Size = UDim2.new(1, -24, 0, 6),
				BackgroundColor3 = Theme.Content,
				Parent = r,
			}, { corner(3) })
			local fill = new("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
				Parent = bar,
			}, { corner(3) })

			local api = {}
			function api:Set(v, silent)
				v = math.clamp(math.round(v / inc) * inc, min, max)
				v = tonumber(string.format("%.3f", v))
				value = v
				fill.Size = UDim2.fromScale((v - min) / math.max(max - min, 1e-9), 1)
				valLabel.Text = tostring(v)
				if not silent then safe(o.Callback, v) end
			end
			function api:Get() return value end

			local dragging = false
			local function fromInput(input)
				local a = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
				api:Set(min + (max - min) * a)
			end
			local hit = new("TextButton", {
				Position = UDim2.new(0, 0, 1, -30),
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Text = "",
				Parent = r,
			})
			hit.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					fromInput(input)
				end
			end)
			table.insert(Window.Connections, UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end))
			table.insert(Window.Connections, UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					fromInput(input)
				end
			end))
			api:Set(value, true)
			return api
		end

		function Tab:AddTextBox(o)
			local r = row(40)
			nameLabel(r, o.Name or "TextBox")
			local box = new("TextBox", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(140, 26),
				BackgroundColor3 = Theme.Content,
				Text = o.Default or "",
				PlaceholderText = o.Placeholder or "...",
				PlaceholderColor3 = Theme.SubText,
				TextColor3 = Theme.Text,
				TextSize = 13,
				Font = Theme.BodyFont,
				ClearTextOnFocus = false,
				Parent = r,
			}, { corner(8), stroke(Theme.Stroke, 1) })
			box.FocusLost:Connect(function(enter)
				safe(o.Callback, box.Text, enter)
			end)
			return { Set = function(_, t) box.Text = t end, Get = function() return box.Text end }
		end

		function Tab:AddKeybind(o)
			local r = row(40)
			nameLabel(r, o.Name or "Keybind")
			local key = o.Default or Enum.KeyCode.Unknown
			local listening = false
			local b = new("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(90, 26),
				BackgroundColor3 = Theme.Content,
				Text = key.Name,
				TextColor3 = Theme.Accent,
				TextSize = 13,
				Font = Theme.Font,
				AutoButtonColor = false,
				Parent = r,
			}, { corner(8), stroke(Theme.Stroke, 1) })
			b.MouseButton1Click:Connect(function()
				listening = true
				b.Text = "..."
			end)
			table.insert(Window.Connections, UserInputService.InputBegan:Connect(function(input, gp)
				if listening and input.UserInputType == Enum.UserInputType.Keyboard then
					listening = false
					key = input.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or input.KeyCode
					b.Text = key.Name
					safe(o.ChangedCallback, key)
				elseif not gp and not listening and key ~= Enum.KeyCode.Unknown and input.KeyCode == key then
					safe(o.Callback, key)
				end
			end))
			return { Get = function() return key end }
		end

		function Tab:AddDropdown(o)
			local options = o.Options or {}
			local selected = o.Default
			local open = false
			local HEAD = 40
			local r = row(HEAD)
			nameLabel(r, o.Name or "Dropdown")
			local current = new("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 0),
				Size = UDim2.fromOffset(140, HEAD),
				Text = tostring(selected or "Select") .. "  ▾",
				TextColor3 = Theme.Accent,
				TextSize = 13,
				Font = Theme.Font,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = r,
			})
			local list = new("Frame", {
				Position = UDim2.fromOffset(8, HEAD),
				Size = UDim2.new(1, -16, 0, #options * 30),
				BackgroundTransparency = 1,
				Parent = r,
			}, { new("UIListLayout", { Padding = UDim.new(0, 2) }) })

			local api = {}
			local buttons = {}
			local function refresh()
				current.Text = tostring(selected or "Select") .. (open and "  ▴" or "  ▾")
				for opt, ob in pairs(buttons) do
					ob.TextColor3 = (opt == selected) and Theme.Accent or Theme.Text
				end
			end
			function api:Set(v, silent)
				selected = v
				refresh()
				if not silent then safe(o.Callback, v) end
			end
			function api:Get() return selected end

			for _, opt in ipairs(options) do
				local ob = new("TextButton", {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundColor3 = Theme.Content,
					Text = tostring(opt),
					TextColor3 = Theme.Text,
					TextSize = 13,
					Font = Theme.BodyFont,
					AutoButtonColor = false,
					Parent = list,
				}, { corner(8) })
				buttons[opt] = ob
				ob.MouseButton1Click:Connect(function()
					api:Set(opt)
					open = false
					tween(r, { Size = UDim2.new(1, 0, 0, HEAD) })
					refresh()
				end)
			end
			new("TextButton", {
				Size = UDim2.new(1, 0, 0, HEAD),
				BackgroundTransparency = 1,
				Text = "",
				Parent = r,
			}).MouseButton1Click:Connect(function()
				open = not open
				tween(r, { Size = UDim2.new(1, 0, 0, open and (HEAD + #options * 30 + 8) or HEAD) })
				refresh()
			end)
			refresh()
			return api
		end

		return setmetatable(Tab, Tab)
	end

	return Window
end

return Sodium
