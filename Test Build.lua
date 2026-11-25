local function service(name)
	local ok, s = pcall(function()
		return game:GetService(name)
	end)
	return ok and s or nil
end

local Players = service("Players")
local TweenService = service("TweenService")
local UserInputService = service("UserInputService")
local CoreGui = service("CoreGui")
local Workspace = service("Workspace")

local Sodium = {}

local function font(name, fallback)
	local ok, f = pcall(function()
		return Enum.Font[name]
	end)
	return (ok and f) or fallback
end

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Theme = {
	Accent = rgb(153, 255, 87),
	AccentDark = rgb(46, 70, 32),
	Stroke = rgb(30, 30, 30),
	Content = rgb(20, 20, 20),
	Text = rgb(235, 235, 235),
	SubText = rgb(150, 150, 150),
	Dark = rgb(15, 15, 15),
	AccentGrad = { rgb(176, 255, 70), rgb(60, 235, 160) },
	WindowGrad = { rgb(66, 66, 66), rgb(40, 40, 40) },
	TitleGrad = { rgb(48, 48, 48), rgb(26, 26, 26) },
	ContentGrad = { rgb(27, 27, 27), rgb(13, 13, 13) },
	ElementGrad = { rgb(46, 46, 46), rgb(31, 31, 31) },
	InputGrad = { rgb(28, 28, 28), rgb(17, 17, 17) },
	TitleFont = font("GothamBlack", Enum.Font.SourceSansBold),
	Font = font("GothamBold", Enum.Font.SourceSansBold),
	BodyFont = font("GothamMedium", Enum.Font.SourceSans),
}

local function warnf(...)
	warn("[Sodium]", ...)
end

local Dummy
Dummy = setmetatable({}, {
	__index = function()
		return function()
			return Dummy
		end
	end,
})

local function isTable(v)
	return type(v) == "table"
end

local function str(v, default)
	if v == nil then
		return default or ""
	end
	local ok, s = pcall(tostring, v)
	return ok and s or (default or "")
end

local function num(v, default)
	local n = tonumber(v)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return default
	end
	return n
end

local function new(class, props, children)
	local ok, inst = pcall(Instance.new, class)
	if not ok then
		error("cannot create " .. tostring(class))
	end
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			local pok, perr = pcall(function()
				inst[k] = v
			end)
			if not pok then
				warnf("property " .. tostring(k) .. " failed on " .. class .. ": " .. tostring(perr))
			end
		end
	end
	for _, c in ipairs(children or {}) do
		pcall(function()
			c.Parent = inst
		end)
	end
	if props and props.Parent then
		pcall(function()
			inst.Parent = props.Parent
		end)
	end
	return inst
end

local function sequence(colors)
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keys = {}
	for i, c in ipairs(colors) do
		keys[i] = ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c)
	end
	return ColorSequence.new(keys)
end

local function paint(inst, colors, rotation, prop)
	prop = prop or "BackgroundColor3"
	local ok = pcall(function()
		local g = Instance.new("UIGradient")
		g.Color = sequence(colors)
		g.Rotation = rotation or 90
		inst[prop] = Color3.new(1, 1, 1)
		g.Parent = inst
	end)
	if not ok then
		pcall(function()
			inst[prop] = colors[1]
		end)
	end
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color, thickness, colors)
	local s = new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	if colors then
		paint(s, colors, 0, "Color")
	end
	return s
end

local noopTween = { Completed = { Connect = function() end, Wait = function() end } }

local function tween(inst, props, t)
	if not TweenService or not inst or not inst.Parent then
		if inst then
			for k, v in pairs(props) do
				pcall(function()
					inst[k] = v
				end)
			end
		end
		return noopTween
	end
	local ok, tw = pcall(function()
		local x = TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
		x:Play()
		return x
	end)
	if ok and tw then
		return tw
	end
	for k, v in pairs(props) do
		pcall(function()
			inst[k] = v
		end)
	end
	return noopTween
end

local function safe(cb, ...)
	if type(cb) == "function" then
		local ok, err = pcall(cb, ...)
		if not ok then
			warnf("callback error: " .. tostring(err))
		end
	end
end

local function canParent(p)
	if typeof(p) ~= "Instance" then
		return false
	end
	local ok = pcall(function()
		local t = Instance.new("Folder")
		t.Parent = p
		t:Destroy()
	end)
	return ok
end

local function getParent()
	local ok, ui = pcall(function()
		return gethui and gethui()
	end)
	if ok and canParent(ui) then
		return ui
	end
	if CoreGui and canParent(CoreGui) then
		return CoreGui
	end
	if Players then
		local lp = Players.LocalPlayer
		if not lp then
			local t = os.clock()
			repeat
				task.wait()
				lp = Players.LocalPlayer
			until lp or os.clock() - t > 5
		end
		if lp then
			local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 5)
			if pg then
				return pg
			end
		end
	end
	return nil
end

local function viewport()
	local ok, v = pcall(function()
		local cam = Workspace and Workspace.CurrentCamera
		return cam and cam.ViewportSize
	end)
	if ok and typeof(v) == "Vector2" and v.X > 0 and v.Y > 0 then
		return v
	end
	return Vector2.new(1280, 720)
end

local function isPointer(input)
	local t = input.UserInputType
	return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end

local function guard(tbl, names, fallback)
	for _, n in ipairs(names) do
		local orig = tbl[n]
		if type(orig) == "function" then
			tbl[n] = function(...)
				local res = table.pack(pcall(orig, ...))
				if res[1] then
					return table.unpack(res, 2, res.n)
				end
				warnf(n .. " failed: " .. tostring(res[2]))
				return fallback
			end
		end
	end
end

local function hexagon(parent, size, color, pos, anchor)
	local holder = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Position = pos or UDim2.new(),
		AnchorPoint = anchor or Vector2.zero,
		Rotation = 90,
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

local function buildWindow(state, opts)
	opts = isTable(opts) and opts or {}
	local title = str(opts.Title, "SODIUM")
	if title == "" then
		title = "SODIUM"
	end
	local minimizeText = str(opts.MinimizeText, title)
	local toggleKey = opts.ToggleKey
	if typeof(toggleKey) ~= "EnumItem" or toggleKey.EnumType ~= Enum.KeyCode then
		toggleKey = Enum.KeyCode.RightShift
	end

	local Window = {}
	Window.Tabs = {}
	Window.Visible = true
	state.Window = Window
	local connections = state.Connections

	local parent = getParent()
	if not parent then
		error("no valid parent for ScreenGui")
	end
	pcall(function()
		local old = parent:FindFirstChild("SodiumUI")
		if old then
			old:Destroy()
		end
	end)

	local gui = new("ScreenGui", {
		Name = "SodiumUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		IgnoreGuiInset = true,
		Parent = parent,
	})
	state.Gui = gui
	Window.Gui = gui

	local minBtn = paint(
		new("TextButton", {
			Name = "Minimized",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 28, 0.5, 0),
			Size = UDim2.fromOffset(66, 46),
			AutoButtonColor = false,
			Text = "",
			Visible = false,
			Parent = gui,
		}, { corner(8), stroke(Theme.Stroke, 2) }),
		Theme.WindowGrad,
		90
	)
	local minLabel = paint(
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = minimizeText,
			TextSize = 13,
			TextScaled = true,
			TextWrapped = true,
			Font = Theme.TitleFont,
			Parent = minBtn,
		}, {
			new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 7 }),
			new("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
		}),
		Theme.AccentGrad,
		0,
		"TextColor3"
	)

	local main = paint(
		new("Frame", {
			Name = "Window",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(976, 614),
			BorderSizePixel = 0,
			Parent = gui,
		}, { corner(24) }),
		Theme.WindowGrad,
		90
	)
	Window.Main = main

	local scale = new("UIScale", { Parent = main })
	local function updateScale()
		local vp = viewport()
		scale.Scale = math.clamp(math.min((vp.X - 160) / 976, (vp.Y - 40) / 614), 0.4, 1)
	end
	updateScale()
	pcall(function()
		local cam = Workspace.CurrentCamera
		if cam then
			table.insert(connections, cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
		end
	end)

	local titleBar = paint(
		new("Frame", {
			Name = "TitleBar",
			Size = UDim2.new(1, 0, 0, 52),
			BorderSizePixel = 0,
			Parent = main,
		}, { corner(24) }),
		Theme.TitleGrad,
		90
	)
	local titleMid = Theme.TitleGrad[1]:Lerp(Theme.TitleGrad[2], 0.5)
	paint(
		new("Frame", {
			Position = UDim2.new(0, 0, 1, -26),
			Size = UDim2.new(1, 0, 0, 26),
			BorderSizePixel = 0,
			Parent = titleBar,
		}),
		{ titleMid, Theme.TitleGrad[2] },
		90
	)
	local titleLabel = paint(
		new("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(0.6, 0, 1, 0),
			Text = title,
			TextSize = 38,
			Font = Theme.TitleFont,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = titleBar,
		}),
		Theme.AccentGrad,
		0,
		"TextColor3"
	)

	local hexOuter = hexagon(titleBar, 38, Theme.AccentDark, UDim2.new(1, -16, 0.5, 0), Vector2.new(1, 0.5))
	local hexInner = hexagon(hexOuter, 32, Theme.Accent, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local closeBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(38, 38),
		BackgroundTransparency = 1,
		Text = "X",
		TextColor3 = rgb(15, 15, 15),
		TextSize = 18,
		Font = Theme.TitleFont,
		Parent = titleBar,
	})
	closeBtn.MouseEnter:Connect(function()
		pcall(setHexColor, hexInner, rgb(190, 255, 140))
	end)
	closeBtn.MouseLeave:Connect(function()
		pcall(setHexColor, hexInner, Theme.Accent)
	end)

	local content = paint(
		new("Frame", {
			Name = "Content",
			Position = UDim2.fromOffset(16, 68),
			Size = UDim2.new(1, -32, 1, -84),
			BorderSizePixel = 0,
			Parent = main,
		}, { corner(24) }),
		Theme.ContentGrad,
		90
	)

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

	paint(
		new("Frame", {
			Position = UDim2.fromOffset(176, 18),
			Size = UDim2.new(0, 2, 1, -36),
			BorderSizePixel = 0,
			Parent = content,
		}, { corner(1) }),
		{ Theme.Stroke, rgb(60, 90, 45), Theme.Stroke },
		90
	)

	local pages = new("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(190, 14),
		Size = UDim2.new(1, -204, 1, -28),
		BackgroundTransparency = 1,
		Parent = content,
	})

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

	function Window:Minimize()
		Window.Visible = false
		main.Visible = false
		minBtn.Visible = true
		minBtn.BackgroundTransparency = 1
		tween(minBtn, { BackgroundTransparency = 0 }, 0.2)
	end

	function Window:Restore()
		Window.Visible = true
		main.Visible = true
		minBtn.Visible = false
	end

	function Window:Toggle()
		if Window.Visible then
			Window.Visible = false
			main.Visible = false
		else
			Window:Restore()
		end
	end

	function Window:SetVisible(v)
		if v then
			Window:Restore()
		else
			Window.Visible = false
			main.Visible = false
		end
	end

	function Window:SetMinimizeText(text)
		text = str(text, "")
		if text == "" then
			text = title
		end
		minimizeText = text
		minLabel.Text = text
	end

	function Window:SetTitle(text)
		text = str(text, "")
		if text ~= "" then
			title = text
			titleLabel.Text = text
		end
	end

	function Window:ResetPosition()
		main.Position = UDim2.fromScale(0.5, 0.5)
	end

	function Window:Destroy()
		for _, c in ipairs(connections) do
			pcall(function()
				c:Disconnect()
			end)
		end
		table.clear(connections)
		pcall(function()
			gui:Destroy()
		end)
	end

	closeBtn.MouseButton1Click:Connect(function()
		Window:Minimize()
	end)
	do
		local dragging, moved, trackedInput, startPos, startMouse = false, false, nil, nil, nil
		local lastGood = minBtn.Position
		minBtn.InputBegan:Connect(function(input)
			if isPointer(input) then
				dragging = true
				moved = false
				startMouse = input.Position
				startPos = minBtn.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						if not moved then
							Window:Restore()
						end
					end
				end)
			end
		end)
		minBtn.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				trackedInput = input
			end
		end)
		if UserInputService then
			table.insert(
				connections,
				UserInputService.InputChanged:Connect(function(input)
					if dragging and input == trackedInput then
						local d = input.Position - startMouse
						if d.Magnitude > 5 then
							moved = true
						end
						if moved then
							minBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
							local vp, ap, as = viewport(), minBtn.AbsolutePosition, minBtn.AbsoluteSize
							if ap.X < 0 or ap.Y < 0 or ap.X + as.X > vp.X or ap.Y + as.Y > vp.Y then
								minBtn.Position = lastGood
							else
								lastGood = minBtn.Position
							end
						end
					end
				end)
			)
		end
	end

	if UserInputService then
		table.insert(
			connections,
			UserInputService.InputBegan:Connect(function(input, gp)
				if not gp and input.KeyCode == toggleKey then
					Window:Toggle()
				end
			end)
		)
	end

	do
		local dragging, trackedInput, startPos, startMouse
		local lastGood = main.Position
		titleBar.InputBegan:Connect(function(input)
			if isPointer(input) then
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
				trackedInput = input
			end
		end)
		if UserInputService then
			table.insert(
				connections,
				UserInputService.InputChanged:Connect(function(input)
					if dragging and input == trackedInput then
						local d = input.Position - startMouse
						main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
						local vp, ap, as = viewport(), main.AbsolutePosition, main.AbsoluteSize
						if ap.X > vp.X - 80 or ap.X + as.X < 80 or ap.Y < -10 or ap.Y > vp.Y - 60 then
							main.Position = lastGood
						else
							lastGood = main.Position
						end
					end
				end)
			)
		end
	end

	function Window:Notify(o)
		o = isTable(o) and o or { Content = str(o) }
		local frame = paint(
			new("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = notifyHolder,
			}, {
				corner(12),
				stroke(Theme.Accent, 1, Theme.AccentGrad),
				new("UIPadding", {
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),
				new("UIListLayout", { Padding = UDim.new(0, 2) }),
			}),
			Theme.WindowGrad,
			90
		)
		paint(
			new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				Text = str(o.Title, "SODIUM"),
				TextSize = 15,
				Font = Theme.TitleFont,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = frame,
			}),
			Theme.AccentGrad,
			0,
			"TextColor3"
		)
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = str(o.Content),
			TextWrapped = true,
			TextColor3 = Theme.Text,
			TextSize = 13,
			Font = Theme.BodyFont,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		tween(frame, { BackgroundTransparency = 0 }, 0.2)
		task.delay(num(o.Duration, 4), function()
			pcall(function()
				if frame.Parent then
					tween(frame, { BackgroundTransparency = 1 }, 0.2)
					task.wait(0.2)
					frame:Destroy()
				end
			end)
		end)
	end

	function Window:CreateTab(name)
		name = str(name, "Tab " .. (#Window.Tabs + 1))
		local Tab = {}

		local btn = paint(
			new("TextButton", {
				Size = UDim2.new(1, 0, 0, 38),
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = #Window.Tabs + 1,
				Parent = sidebar,
			}, { corner(10) }),
			Theme.ElementGrad,
			90
		)
		local fill = paint(
			new("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = btn,
			}, { corner(10) }),
			Theme.AccentGrad,
			0
		)
		local label = new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Text = name,
			TextColor3 = Theme.SubText,
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Font = Theme.Font,
			Parent = btn,
		})

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
		Tab.Fill = fill
		Tab.Label = label
		Tab.Page = page
		table.insert(Window.Tabs, Tab)

		function Tab:Select()
			for _, t in ipairs(Window.Tabs) do
				pcall(function()
					t.Page.Visible = false
					tween(t.Fill, { BackgroundTransparency = 1 })
					tween(t.Label, { TextColor3 = Theme.SubText })
				end)
			end
			page.Visible = true
			tween(fill, { BackgroundTransparency = 0 })
			tween(label, { TextColor3 = Theme.Dark })
		end
		btn.MouseButton1Click:Connect(function()
			pcall(Tab.Select, Tab)
		end)
		if #Window.Tabs == 1 then
			pcall(Tab.Select, Tab)
		end

		local order = 0
		local function row(height)
			order += 1
			return paint(
				new("Frame", {
					Size = UDim2.new(1, 0, 0, height),
					BorderSizePixel = 0,
					LayoutOrder = order,
					ClipsDescendants = true,
					Parent = page,
				}, { corner(10), stroke(Theme.Stroke, 1) }),
				Theme.ElementGrad,
				90
			)
		end

		local function inputBox(parent, width, pos)
			return paint(
				new("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = pos or UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(width, 26),
					BorderSizePixel = 0,
					Parent = parent,
				}, { corner(8), stroke(Theme.Stroke, 1) }),
				Theme.InputGrad,
				90
			)
		end

		local function nameLabel(parent, text)
			return new("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -90, 0, 40),
				Text = text,
				TextColor3 = Theme.Text,
				TextSize = 14,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Font = Theme.Font,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = parent,
			})
		end

		function Tab:AddSection(text)
			order += 1
			paint(
				new("TextLabel", {
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundTransparency = 1,
					Text = string.upper(str(text, "Section")),
					TextSize = 13,
					Font = Theme.TitleFont,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = order,
					Parent = page,
				}),
				Theme.AccentGrad,
				0,
				"TextColor3"
			)
		end

		function Tab:AddLabel(text)
			local r = row(36)
			local l = new("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -24, 1, 0),
				Text = str(text),
				TextColor3 = Theme.SubText,
				TextSize = 13,
				TextWrapped = true,
				Font = Theme.BodyFont,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = r,
			})
			return {
				Set = function(_, t)
					l.Text = str(t)
				end,
			}
		end

		function Tab:AddButton(o)
			o = isTable(o) and o or {}
			local r = row(40)
			local shade = paint(
				new("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = r,
				}, { corner(10) }),
				Theme.AccentGrad,
				0
			)
			nameLabel(r, str(o.Name, "Button"))
			hexagon(r, 16, Theme.Accent, UDim2.new(1, -20, 0.5, 0), Vector2.new(1, 0.5))
			local b = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = r })
			b.MouseEnter:Connect(function()
				tween(shade, { BackgroundTransparency = 0.88 })
			end)
			b.MouseLeave:Connect(function()
				tween(shade, { BackgroundTransparency = 1 })
			end)
			b.MouseButton1Click:Connect(function()
				tween(shade, { BackgroundTransparency = 0.5 }, 0.08)
				task.delay(0.1, function()
					tween(shade, { BackgroundTransparency = 0.88 })
				end)
				safe(o.Callback)
			end)
			return {
				Fire = function()
					safe(o.Callback)
				end,
			}
		end

		function Tab:AddToggle(o)
			o = isTable(o) and o or {}
			local value = o.Default == true
			local r = row(40)
			nameLabel(r, str(o.Name, "Toggle"))
			local pill = new("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(40, 20),
				BackgroundColor3 = Theme.Content,
				Parent = r,
			}, { corner(10), stroke(Theme.Stroke, 1) })
			local pillFill = paint(
				new("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = pill,
				}, { corner(10) }),
				Theme.AccentGrad,
				0
			)
			local knob = new("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 3, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = Theme.SubText,
				ZIndex = 2,
				Parent = pill,
			}, { corner(7) })
			local api = {}
			local function render()
				tween(pillFill, { BackgroundTransparency = value and 0 or 1 })
				tween(knob, {
					Position = value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
					BackgroundColor3 = value and Theme.Dark or Theme.SubText,
				})
			end
			function api:Set(v, silent)
				value = v and true or false
				render()
				if not silent then
					safe(o.Callback, value)
				end
			end
			function api:Get()
				return value
			end
			new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = r }).MouseButton1Click:Connect(function()
				api:Set(not value)
			end)
			render()
			if value then
				safe(o.Callback, value)
			end
			return api
		end

		function Tab:AddSlider(o)
			o = isTable(o) and o or {}
			local min, max = num(o.Min, 0), num(o.Max, 100)
			if max <= min then
				min, max = 0, 100
			end
			local inc = num(o.Increment, 1)
			if inc <= 0 then
				inc = 1
			end
			local value = math.clamp(num(o.Default, min), min, max)
			local r = row(54)
			nameLabel(r, str(o.Name, "Slider")).Size = UDim2.new(1, -90, 0, 32)
			local valLabel = paint(
				new("TextLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -12, 0, 0),
					Size = UDim2.fromOffset(70, 32),
					Text = tostring(value),
					TextSize = 14,
					Font = Theme.Font,
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = r,
				}),
				Theme.AccentGrad,
				0,
				"TextColor3"
			)
			local bar = new("Frame", {
				Position = UDim2.new(0, 12, 1, -16),
				Size = UDim2.new(1, -24, 0, 6),
				BackgroundColor3 = Theme.Content,
				Parent = r,
			}, { corner(3) })
			local fill = paint(
				new("Frame", {
					Size = UDim2.fromScale(0, 1),
					BorderSizePixel = 0,
					Parent = bar,
				}, { corner(3) }),
				Theme.AccentGrad,
				0
			)

			local api = {}
			function api:Set(v, silent)
				v = num(v, value)
				v = math.clamp(math.round(v / inc) * inc, min, max)
				v = tonumber(string.format("%.3f", v)) or v
				value = v
				fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
				valLabel.Text = tostring(v)
				if not silent then
					safe(o.Callback, v)
				end
			end
			function api:Get()
				return value
			end

			local dragging = false
			local function fromInput(input)
				local w = bar.AbsoluteSize.X
				if w <= 0 then
					return
				end
				api:Set(min + (max - min) * math.clamp((input.Position.X - bar.AbsolutePosition.X) / w, 0, 1))
			end
			local hit = new("TextButton", {
				Position = UDim2.new(0, 0, 1, -30),
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Text = "",
				Parent = r,
			})
			hit.InputBegan:Connect(function(input)
				if isPointer(input) then
					dragging = true
					fromInput(input)
				end
			end)
			if UserInputService then
				table.insert(
					connections,
					UserInputService.InputEnded:Connect(function(input)
						if isPointer(input) then
							dragging = false
						end
					end)
				)
				table.insert(
					connections,
					UserInputService.InputChanged:Connect(function(input)
						if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							fromInput(input)
						end
					end)
				)
			end
			api:Set(value, true)
			return api
		end

		function Tab:AddTextBox(o)
			o = isTable(o) and o or {}
			local r = row(40)
			nameLabel(r, str(o.Name, "TextBox"))
			local holder = inputBox(r, 140)
			local box = new("TextBox", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = str(o.Default),
				PlaceholderText = str(o.Placeholder, "..."),
				PlaceholderColor3 = Theme.SubText,
				TextColor3 = Theme.Text,
				TextSize = 13,
				ClearTextOnFocus = false,
				Font = Theme.BodyFont,
				Parent = holder,
			}, { new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
			box.FocusLost:Connect(function(enter)
				safe(o.Callback, box.Text, enter)
			end)
			return {
				Set = function(_, t)
					box.Text = str(t)
				end,
				Get = function()
					return box.Text
				end,
			}
		end

		function Tab:AddKeybind(o)
			o = isTable(o) and o or {}
			local key = o.Default
			if typeof(key) ~= "EnumItem" or key.EnumType ~= Enum.KeyCode then
				key = Enum.KeyCode.Unknown
			end
			local listening = false
			local r = row(40)
			nameLabel(r, str(o.Name, "Keybind"))
			local holder = inputBox(r, 90)
			local b = new("TextButton", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = key.Name,
				TextColor3 = Theme.Accent,
				TextSize = 13,
				Font = Theme.Font,
				AutoButtonColor = false,
				Parent = holder,
			})
			b.MouseButton1Click:Connect(function()
				listening = true
				b.Text = "..."
			end)
			if UserInputService then
				table.insert(
					connections,
					UserInputService.InputBegan:Connect(function(input, gp)
						if listening and input.UserInputType == Enum.UserInputType.Keyboard then
							listening = false
							key = input.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or input.KeyCode
							b.Text = key.Name
							safe(o.ChangedCallback, key)
						elseif not gp and not listening and key ~= Enum.KeyCode.Unknown and input.KeyCode == key then
							safe(o.Callback, key)
						end
					end)
				)
			end
			return {
				Get = function()
					return key
				end,
			}
		end

		function Tab:AddDropdown(o)
			o = isTable(o) and o or {}
			local options = {}
			if isTable(o.Options) then
				for _, v in ipairs(o.Options) do
					table.insert(options, str(v))
				end
			end
			local selected = o.Default ~= nil and str(o.Default) or nil
			if selected and not table.find(options, selected) then
				selected = nil
			end
			local open = false
			local HEAD = 40
			local r = row(HEAD)
			nameLabel(r, str(o.Name, "Dropdown"))
			local current = new("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 0),
				Size = UDim2.fromOffset(140, HEAD),
				Text = "Select",
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
				current.Text = (selected or "Select") .. (open and "  ^" or "  v")
				for opt, ob in pairs(buttons) do
					ob.TextColor3 = (opt == selected) and Theme.Accent or Theme.Text
				end
			end
			function api:Set(v, silent)
				v = v ~= nil and str(v) or nil
				if v and not table.find(options, v) then
					return
				end
				selected = v
				refresh()
				if not silent then
					safe(o.Callback, v)
				end
			end
			function api:Get()
				return selected
			end
			for _, opt in ipairs(options) do
				local ob = paint(
					new("TextButton", {
						Size = UDim2.new(1, 0, 0, 28),
						BorderSizePixel = 0,
						Text = opt,
						TextColor3 = Theme.Text,
						TextSize = 13,
						Font = Theme.BodyFont,
						AutoButtonColor = false,
						Parent = list,
					}, { corner(8) }),
					Theme.InputGrad,
					90
				)
				buttons[opt] = ob
				ob.MouseButton1Click:Connect(function()
					api:Set(opt)
					open = false
					tween(r, { Size = UDim2.new(1, 0, 0, HEAD) })
					refresh()
				end)
			end
			new("TextButton", { Size = UDim2.new(1, 0, 0, HEAD), BackgroundTransparency = 1, Text = "", Parent = r }).MouseButton1Click:Connect(function()
				if #options == 0 then
					return
				end
				open = not open
				tween(r, { Size = UDim2.new(1, 0, 0, open and (HEAD + #options * 30 + 8) or HEAD) })
				refresh()
			end)
			refresh()
			return api
		end

		guard(Tab, { "AddSection", "AddLabel", "AddButton", "AddToggle", "AddSlider", "AddTextBox", "AddKeybind", "AddDropdown", "Select" }, Dummy)
		return Tab
	end

	guard(Window, { "Minimize", "Restore", "Toggle", "SetVisible", "SetMinimizeText", "SetTitle", "ResetPosition", "Destroy", "Notify", "CreateTab" }, Dummy)
	return Window
end

function Sodium:CreateWindow(opts)
	local state = { Connections = {} }
	local ok, result = pcall(buildWindow, state, opts)
	if ok then
		return result
	end
	warnf("CreateWindow failed: " .. tostring(result))
	for _, c in ipairs(state.Connections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	if state.Gui then
		pcall(function()
			state.Gui:Destroy()
		end)
	end
	return Dummy
end

return Sodium
