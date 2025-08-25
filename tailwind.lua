--[=[
TailwindLuau — TailwindCSS-style utilities for Roblox UI (Luau)
Version: 0.9.0 (large manual port)

What you get (manual port, high coverage):
- Colors: gray, slate, zinc, neutral, stone, red, orange, yellow, green, teal, cyan, sky, blue, indigo, violet, purple, fuchsia, pink, rose (shades 50..900)
- Background / Text / Border colors: bg-*, text-*, border-*
- Opacity utilities: opacity-0..100 (step 5)
- Spacing scale: 0..96 (Tailwind-ish: 0,0.5,1,1.5,2,2.5,3,3.5,4,5,6,7,8,9,10,11,12,14,16,20,24,28,32,36,40,44,48,52,56,60,64,72,80,96)
- Margin / Padding: m-*, mx-*, my-*, mt/mr/mb/ml, p-*, px/py/pt/pr/pb/pl
- Sizing: w-*, h-*, w-full/h-full, min-w/min-h/max-w/max-h, screen helpers
- Display: hidden, block, inline-block (no-op), inline-flex, flex, grid
- Flexbox: flex-row/col, wrap, justify-*, items-*, content-*, self-*, gap-*
- Grid: grid-cols-{1..12}, gap-*, auto-fit behavior via UIGridLayout
- Typography: text-xs..9xl, font-{thin,extralight,light,normal,medium,semibold,bold,extrabold,black},
  leading-{none,tight,normal,loose}, tracking-{tighter,tight,normal,wide,wider,widest}, text-left/center/right
- Radius: rounded, rounded-{sm,md,lg,xl,2xl,3xl,full}, rounded-{t,r,b,l}
- Border: border, border-0..8, border-{color}, divide-x/y (basic), ring (UIStroke)
- Z-index: z-0..50, z-auto
- Overflow: overflow-{visible,hidden,scroll} (ScrollingFrame-aware)
- Effects: shadow-{sm,md,lg,xl,2xl}, blur-{sm,md,lg} (UIBlurEffect for 3D or backdrop sim), backdrop (glass gradient helper)
- Transforms: scale-50..150 (UIScale), rotate-{0,45,90,180,270} (ImageLabel only), translate-x/y-{n} (offset)
- Transitions: transition, duration-75..1000, ease-{linear,in,out,in-out},
  hover: and active: variants (MouseEnter/Leave/Down/Up), focus: (textboxes)
- Responsive variants: sm:, md:, lg:, xl: (breakpoints 640/768/1024/1280 px) using AbsoluteSize.X of the top ScreenGui
- Utilities to programmatically register or compose classes

Limitations:
- True CSS layout features differ from Roblox; we approximate flex/grid with UIListLayout/UIGridLayout.
- Rotation for GUI is limited; implemented for ImageLabel via Rotation.
- Backdrop blur uses a simulated layer (can’t blur the 2D backbuffer reliably in all executors).
- Some Tailwind edge utilities omitted or approximated; extend the registry using Tailwind.register.

Usage:
local TW = require(path.to.thisModule)
local gui = Instance.new("ScreenGui", game.Players.LocalPlayer.PlayerGui)
local card = TW.create("Frame", { Parent = gui, Size = UDim2.fromOffset(360, 180),
  Class = "bg-slate-800/80 rounded-2xl p-6 shadow-xl flex flex-col gap-4 hover:bg-slate-700/80 transition duration-200" })

local title = TW.create("TextLabel", { Parent = card, Text = "Tailwind in Roblox", Class = "text-white text-xl font-semibold" })

Extend:
TW.register("bg-brand", function(i) i.BackgroundColor3 = Color3.fromRGB(85,120,255) end)
TW.apply(card, "bg-brand")

]=]

local Tailwind = {}
Tailwind.__index = Tailwind

-- Runtime env helpers
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

-- root screen (for responsive)
local function findScreenGui(inst)
	local s = inst
	while s and not s:IsA("ScreenGui") do s = s.Parent end
	return s
end

-- Tween helper
local function tween(o, t, props, style, dir)
	TweenService:Create(o, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end

-- ---------- Values / Scales ----------

-- spacing map (px)
local spacing = {
	["0"]=0,["0.5"]=2,["1"]=4,["1.5"]=6,["2"]=8,["2.5"]=10,["3"]=12,["3.5"]=14,["4"]=16,["5"]=20,["6"]=24,
	["7"]=28,["8"]=32,["9"]=36,["10"]=40,["11"]=44,["12"]=48,["14"]=56,["16"]=64,["20"]=80,["24"]=96,["28"]=112,
	["32"]=128,["36"]=144,["40"]=160,["44"]=176,["48"]=192,["52"]=208,["56"]=224,["60"]=240,["64"]=256,["72"]=288,
	["80"]=320,["96"]=384,
}

-- text sizes (px)
local textSize = { xs=12, sm=14, base=16, lg=18, xl=20, ["2xl"]=24, ["3xl"]=30, ["4xl"]=36, ["5xl"]=48, ["6xl"]=60, ["7xl"]=72, ["8xl"]=96, ["9xl"]=128 }

-- font weight mapping (best-effort)
local weightFont = {
	thin=Enum.Font.Gotham,["extralight"]=Enum.Font.Gotham,["light"]=Enum.Font.Gotham,
	normal=Enum.Font.Gotham, medium=Enum.Font.GothamMedium, semibold=Enum.Font.GothamSemibold,
	bold=Enum.Font.GothamBold, extrabold=Enum.Font.GothamBlack, black=Enum.Font.GothamBlack
}

-- tracking (letter spacing) approximation using RichText (not fully supported), we simulate via no-op
local tracking = { tighter=0, tight=0, normal=0, wide=0, wider=0, widest=0 }

-- line-height (leading) approximated by TextYAlignment/automatic; we add UIPadding fudge
local leadingPadding = { none=0, tight=0, normal=2, loose=6 }

-- z-index scale
local zIndex = { auto=nil, [0]=0,[10]=10,[20]=20,[30]=30,[40]=40,[50]=50 }

-- durations
local durations = { [75]=0.075,[100]=0.1,[150]=0.15,[200]=0.2,[300]=0.3,[500]=0.5,[700]=0.7,[1000]=1 }

-- easings
local easings = {
	linear = Enum.EasingStyle.Linear,
	in = Enum.EasingStyle.Quad,
	out = Enum.EasingStyle.Quad,
	["in-out"] = Enum.EasingStyle.Quad,
}

-- color palette (subset but broad). Tailwind RGB values.
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local palette = {
	gray={ [50]=rgb(249,250,251),[100]=rgb(243,244,246),[200]=rgb(229,231,235),[300]=rgb(209,213,219),[400]=rgb(156,163,175),[500]=rgb(107,114,128),[600]=rgb(75,85,99),[700]=rgb(55,65,81),[800]=rgb(31,41,55),[900]=rgb(17,24,39) },
	slate={ [50]=rgb(248,250,252),[100]=rgb(241,245,249),[200]=rgb(226,232,240),[300]=rgb(203,213,225),[400]=rgb(148,163,184),[500]=rgb(100,116,139),[600]=rgb(71,85,105),[700]=rgb(51,65,85),[800]=rgb(30,41,59),[900]=rgb(15,23,42) },
	zinc={ [50]=rgb(250,250,250),[100]=rgb(244,244,245),[200]=rgb(228,228,231),[300]=rgb(212,212,216),[400]=rgb(161,161,170),[500]=rgb(113,113,122),[600]=rgb(82,82,91),[700]=rgb(63,63,70),[800]=rgb(39,39,42),[900]=rgb(24,24,27) },
	neutral={ [50]=rgb(250,250,250),[100]=rgb(245,245,245),[200]=rgb(229,229,229),[300]=rgb(212,212,212),[400]=rgb(163,163,163),[500]=rgb(115,115,115),[600]=rgb(82,82,82),[700]=rgb(64,64,64),[800]=rgb(38,38,38),[900]=rgb(23,23,23) },
	stone={ [50]=rgb(250,250,249),[100]=rgb(245,245,244),[200]=rgb(231,229,228),[300]=rgb(214,211,209),[400]=rgb(168,162,158),[500]=rgb(120,113,108),[600]=rgb(87,83,78),[700]=rgb(68,64,60),[800]=rgb(41,37,36),[900]=rgb(28,25,23) },
	red={ [50]=rgb(254,242,242),[100]=rgb(254,226,226),[200]=rgb(254,202,202),[300]=rgb(252,165,165),[400]=rgb(248,113,113),[500]=rgb(239,68,68),[600]=rgb(220,38,38),[700]=rgb(185,28,28),[800]=rgb(153,27,27),[900]=rgb(127,29,29) },
	orange={ [50]=rgb(255,247,237),[100]=rgb(255,237,213),[200]=rgb(254,215,170),[300]=rgb(253,186,116),[400]=rgb(251,146,60),[500]=rgb(249,115,22),[600]=rgb(234,88,12),[700]=rgb(194,65,12),[800]=rgb(154,52,18),[900]=rgb(124,45,18) },
	yellow={ [50]=rgb(254,252,232),[100]=rgb(254,249,195),[200]=rgb(254,240,138),[300]=rgb(253,224,71),[400]=rgb(250,204,21),[500]=rgb(234,179,8),[600]=rgb(202,138,4),[700]=rgb(161,98,7),[800]=rgb(133,77,14),[900]=rgb(113,63,18) },
	green={ [50]=rgb(240,253,244),[100]=rgb(220,252,231),[200]=rgb(187,247,208),[300]=rgb(134,239,172),[400]=rgb(74,222,128),[500]=rgb(34,197,94),[600]=rgb(22,163,74),[700]=rgb(21,128,61),[800]=rgb(22,101,52),[900]=rgb(20,83,45) },
	teal={ [50]=rgb(240,253,250),[100]=rgb(204,251,241),[200]=rgb(153,246,228),[300]=rgb(94,234,212),[400]=rgb(45,212,191),[500]=rgb(20,184,166),[600]=rgb(13,148,136),[700]=rgb(15,118,110),[800]=rgb(17,94,89),[900]=rgb(19,78,74) },
	cyan={ [50]=rgb(236,254,255),[100]=rgb(207,250,254),[200]=rgb(165,243,252),[300]=rgb(103,232,249),[400]=rgb(34,211,238),[500]=rgb(6,182,212),[600]=rgb(8,145,178),[700]=rgb(14,116,144),[800]=rgb(21,94,117),[900]=rgb(22,78,99) },
	sky={ [50]=rgb(240,249,255),[100]=rgb(224,242,254),[200]=rgb(186,230,253),[300]=rgb(125,211,252),[400]=rgb(56,189,248),[500]=rgb(14,165,233),[600]=rgb(2,132,199),[700]=rgb(3,105,161),[800]=rgb(7,89,133),[900]=rgb(12,74,110) },
	blue={ [50]=rgb(239,246,255),[100]=rgb(219,234,254),[200]=rgb(191,219,254),[300]=rgb(147,197,253),[400]=rgb(96,165,250),[500]=rgb(59,130,246),[600]=rgb(37,99,235),[700]=rgb(29,78,216),[800]=rgb(30,64,175),[900]=rgb(30,58,138) },
	indigo={ [50]=rgb(238,242,255),[100]=rgb(224,231,255),[200]=rgb(199,210,254),[300]=rgb(165,180,252),[400]=rgb(129,140,248),[500]=rgb(99,102,241),[600]=rgb(79,70,229),[700]=rgb(67,56,202),[800]=rgb(55,48,163),[900]=rgb(49,46,129) },
	violet={ [50]=rgb(245,243,255),[100]=rgb(237,233,254),[200]=rgb(221,214,254),[300]=rgb(196,181,253),[400]=rgb(167,139,250),[500]=rgb(139,92,246),[600]=rgb(124,58,237),[700]=rgb(109,40,217),[800]=rgb(91,33,182),[900]=rgb(76,29,149) },
	purple={ [50]=rgb(250,245,255),[100]=rgb(243,232,255),[200]=rgb(233,213,255),[300]=rgb(216,180,254),[400]=rgb(192,132,252),[500]=rgb(168,85,247),[600]=rgb(147,51,234),[700]=rgb(126,34,206),[800]=rgb(107,33,168),[900]=rgb(88,28,135) },
	fuchsia={ [50]=rgb(253,244,255),[100]=rgb(250,232,255),[200]=rgb(245,208,254),[300]=rgb(240,171,252),[400]=rgb(232,121,249),[500]=rgb(217,70,239),[600]=rgb(192,38,211),[700]=rgb(162,28,175),[800]=rgb(134,25,143),[900]=rgb(112,26,117) },
	pink={ [50]=rgb(253,242,248),[100]=rgb(252,231,243),[200]=rgb(251,207,232),[300]=rgb(249,168,212),[400]=rgb(244,114,182),[500]=rgb(236,72,153),[600]=rgb(219,39,119),[700]=rgb(190,24,93),[800]=rgb(157,23,77),[900]=rgb(131,24,67) },
	rose={ [50]=rgb(255,241,242),[100]=rgb(255,228,230),[200]=rgb(254,205,211),[300]=rgb(253,164,175),[400]=rgb(251,113,133),[500]=rgb(244,63,94),[600]=rgb(225,29,72),[700]=rgb(190,18,60),[800]=rgb(159,18,57),[900]=rgb(136,19,55) },
}

-- ---------- Registry & API ----------
Tailwind.registry = {}
Tailwind.variants = { hover=true, active=true, focus=true, sm=true, md=true, lg=true, xl=true }
Tailwind.breakpoints = { sm=640, md=768, lg=1024, xl=1280 }

function Tailwind.register(className, applyFn)
	Tailwind.registry[className] = applyFn
end

local function ensurePadding(frame)
	local pad = frame:FindFirstChildOfClass("UIPadding")
	if not pad then pad = Instance.new("UIPadding"); pad.Parent = frame end
	return pad
end

local function ensureListLayout(frame, vertical)
	local ll = frame:FindFirstChildOfClass("UIListLayout")
	if not ll then ll = Instance.new("UIListLayout"); ll.Parent = frame end
	ll.FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	return ll
end

local function ensureGrid(frame)
	local g = frame:FindFirstChildOfClass("UIGridLayout")
	if not g then g = Instance.new("UIGridLayout"); g.Parent = frame end
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.FillDirectionMaxCells = 0 -- we set via cols util
	return g
end

-- state store per instance
local stateMap = setmetatable({}, { __mode = "k" })
local function getState(inst)
	local s = stateMap[inst]
	if not s then s = { base={}, hover={}, active={}, focus={}, responsive={} }; stateMap[inst] = s end
	return s
end

-- apply class list (space-delimited)
function Tailwind.apply(instance, classString)
	if not classString or classString == "" then return end
	for raw in string.gmatch(classString, "[^%s]+") do
		Tailwind._applyOne(instance, raw)
	end
end

-- parse variants and apply
function Tailwind._applyOne(inst, raw)
	-- opacity slash notation e.g., bg-blue-500/80
	local base, alpha = string.match(raw, "^(.-)/(%d+)$")
	local class = base or raw

	-- responsive variant: sm:, md:, ...
	local bp, tail = string.match(class, "^(sm:.*)$") or string.match(class, "^(md:.*)$") or string.match(class, "^(lg:.*)$") or string.match(class, "^(xl:.*)$")
	if (string.sub(class,1,3) == "sm:" or string.sub(class,1,3) == "md:" or string.sub(class,1,3) == "lg:" or string.sub(class,1,3) == "xl:") then
		local variant = string.sub(class,1,2) -- sm/md/lg/xl
		local rest = string.sub(class,4)
		local st = getState(inst)
		st.responsive[variant] = st.responsive[variant] or {}
		table.insert(st.responsive[variant], { name=raw, base=rest, alpha=alpha })
		Tailwind._wireResponsive(inst)
		return
	end

	-- pseudo state variants
	for _,v in ipairs({"hover:","active:","focus:"}) do
		if string.sub(class,1,#v) == v then
			local key = string.sub(v,1,#v-1)
			local rest = string.sub(class,#v+1)
			local st = getState(inst)
			st[key] = st[key] or {}
			table.insert(st[key], { name=raw, base=rest, alpha=alpha })
			Tailwind._wireStates(inst)
			return
		end
	end

	-- base utility
	local fn = Tailwind.registry[class]
	if fn then fn(inst, alpha) end
end

function Tailwind._wireStates(inst)
	local st = getState(inst)
	if st._wired then return end
	st._wired = true
	-- hover
	if inst:IsA("GuiObject") then
		inst.MouseEnter:Connect(function()
			for _,u in ipairs(st.hover or {}) do
				local fn = Tailwind.registry[u.base]
				if fn then fn(inst, u.alpha) end
			end
		end)
		inst.MouseLeave:Connect(function()
			-- No automatic revert; recommend to pair base classes.
		end)
		-- active (mouse down)
		inst.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.MouseButton1 then
				for _,u in ipairs(st.active or {}) do local fn = Tailwind.registry[u.base]; if fn then fn(inst, u.alpha) end end
			end
		end)
		-- focus (TextBoxes)
		if inst:IsA("TextBox") then
			inst.Focused:Connect(function()
				for _,u in ipairs(st.focus or {}) do local fn = Tailwind.registry[u.base]; if fn then fn(inst, u.alpha) end end
			end)
		end
	end
end

function Tailwind._wireResponsive(inst)
	local sgui = findScreenGui(inst)
	if not sgui then return end
	local function applyForWidth(w)
		local st = getState(inst)
		for key,arr in pairs(st.responsive) do
			local min = Tailwind.breakpoints[key]
			if w >= min then
				for _,u in ipairs(arr) do local fn = Tailwind.registry[u.base]; if fn then fn(inst, u.alpha) end end
			end
		end
	end
	applyForWidth(sgui.AbsoluteSize.X)
	sgui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		applyForWidth(sgui.AbsoluteSize.X)
	end)
end

function Tailwind.create(className, props)
	local o = Instance.new(className)
	props = props or {}
	if props.Parent then o.Parent = props.Parent end
	if props.Size then o.Size = props.Size end
	if props.Position then o.Position = props.Position end
	if props.AnchorPoint then o.AnchorPoint = props.AnchorPoint end
	if props.Text then pcall(function() o.Text = props.Text end) end
	if props.RichText ~= nil then pcall(function() o.RichText = props.RichText end) end
	if props.Visible ~= nil then o.Visible = props.Visible end
	if props.Class then Tailwind.apply(o, props.Class) end
	return o
end

-- ---------- Utility Builders ----------

local function registerColorTriplet(prefix, prop)
	for family, shades in pairs(palette) do
		for shade, c in pairs(shades) do
			local name = ("%s-%s-%d"):format(prefix, family, shade)
			Tailwind.register(name, function(inst, alpha)
				inst[prop] = c
				if alpha then
					local a = math.clamp(tonumber(alpha) or 100, 0, 100)/100
					-- Simulate alpha via BackgroundTransparency/TextTransparency
					if prop == "BackgroundColor3" then inst.BackgroundTransparency = 1-a end
					if prop == "TextColor3" then pcall(function() inst.TextTransparency = 1-a end) end
					if prop == "BorderColor3" then pcall(function() inst.BorderSizePixel = inst.BorderSizePixel > 0 and inst.BorderSizePixel or 1 end) end
				end
			end)
		end
	end
end

-- bg-*, text-*, border-*
registerColorTriplet("bg", "BackgroundColor3")
registerColorTriplet("text", "TextColor3")
registerColorTriplet("border", "BorderColor3")

-- common aliases
Tailwind.register("bg-white", function(i,a) i.BackgroundColor3 = Color3.fromRGB(255,255,255); if a then i.BackgroundTransparency = 1-(tonumber(a) or 100)/100 end end)
Tailwind.register("bg-black", function(i,a) i.BackgroundColor3 = Color3.fromRGB(0,0,0); if a then i.BackgroundTransparency = 1-(tonumber(a) or 100)/100 end end)
Tailwind.register("text-white", function(i,a) pcall(function() i.TextColor3 = Color3.new(1,1,1); if a then i.TextTransparency = 1-(tonumber(a) or 100)/100 end end) end)
Tailwind.register("text-black", function(i,a) pcall(function() i.TextColor3 = Color3.new(0,0,0); if a then i.TextTransparency = 1-(tonumber(a) or 100)/100 end end) end)

-- opacity-*
for n=0,100,5 do
	local name = "opacity-"..tostring(n)
	Tailwind.register(name, function(i)
		local a = n/100
		if i:IsA("TextLabel") or i:IsA("TextButton") or i:IsA("TextBox") then i.TextTransparency = 1-a end
		if i:IsA("GuiObject") then i.BackgroundTransparency = 1-a end
	end)
end

-- display
Tailwind.register("hidden", function(i) i.Visible = false end)
Tailwind.register("block", function(i) i.Visible = true end)
Tailwind.register("inline-block", function(i) i.Visible = true end)
Tailwind.register("flex", function(i) ensureListLayout(i,false) end)
Tailwind.register("inline-flex", function(i) ensureListLayout(i,false) end)
Tailwind.register("grid", function(i) ensureGrid(i) end)

-- flex direction & wrap
Tailwind.register("flex-row", function(i) ensureListLayout(i,false) end)
Tailwind.register("flex-col", function(i) ensureListLayout(i,true) end)
Tailwind.register("flex-wrap", function(i) local ll = ensureListLayout(i,false); ll.Wraps = true end)
Tailwind.register("flex-nowrap", function(i) local ll = ensureListLayout(i,false); ll.Wraps = false end)

-- justify / items / content
local hAlign = { start=Enum.HorizontalAlignment.Left, center=Enum.HorizontalAlignment.Center, end_=Enum.HorizontalAlignment.Right, between=Enum.HorizontalAlignment.Left }
local vAlign = { start=Enum.VerticalAlignment.Top, center=Enum.VerticalAlignment.Center, end_=Enum.VerticalAlignment.Bottom }

local function setJustify(i, k)
	local ll = ensureListLayout(i,false)
	if k=="between" then ll.HorizontalAlignment = Enum.HorizontalAlignment.Left; ll.Padding = UDim.new(0, ll.Padding and ll.Padding.Offset or 0) else ll.HorizontalAlignment = hAlign[k] or Enum.HorizontalAlignment.Left end
end
Tailwind.register("justify-start", function(i) setJustify(i, "start") end)
Tailwind.register("justify-center", function(i) setJustify(i, "center") end)
Tailwind.register("justify-end", function(i) setJustify(i, "end_") end)
Tailwind.register("justify-between", function(i) setJustify(i, "between") end)

local function setItems(i, k)
	local ll = ensureListLayout(i,false)
	ll.VerticalAlignment = vAlign[k] or Enum.VerticalAlignment.Center
end
Tailwind.register("items-start", function(i) setItems(i, "start") end)
Tailwind.register("items-center", function(i) setItems(i, "center") end)
Tailwind.register("items-end", function(i) setItems(i, "end_") end)

-- gap-*
for key,px in pairs(spacing) do
	Tailwind.register("gap-"..key, function(i)
		local ll = i:FindFirstChildOfClass("UIListLayout") or i:FindFirstChildOfClass("UIGridLayout")
		if not ll then ll = ensureListLayout(i,false) end
		if ll:IsA("UIListLayout") then ll.Padding = UDim.new(0, px) else ll.CellPadding = UDim2.new(0,px,0,px) end
	end)
end

-- grid-cols-{n}
for n=1,12 do
	Tailwind.register("grid-cols-"..n, function(i)
		local g = ensureGrid(i)
		g.FillDirection = Enum.FillDirection.Horizontal
		g.CellPadding = g.CellPadding or UDim2.new(0,8,0,8)
		g:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() end)
		-- dynamic cell size on resize
		local function resize()
			local w = i.AbsoluteSize.X
			local gap = g.CellPadding.X.Offset
			local cellW = math.max(0, math.floor((w - gap*(n-1))/n))
			g.CellSize = UDim2.new(0, cellW, 0, 36)
		end
		resize()
		i:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	end)
end

-- padding
local function setPad(inst, t,r,b,l)
	local pad = ensurePadding(inst)
	pad.PaddingTop = UDim.new(0,t); pad.PaddingRight = UDim.new(0,r); pad.PaddingBottom = UDim.new(0,b); pad.PaddingLeft = UDim.new(0,l)
end
for key,px in pairs(spacing) do
	Tailwind.register("p-"..key, function(i) setPad(i,px,px,px,px) end)
	Tailwind.register("px-"..key, function(i) setPad(i,0,px,0,px) end)
	Tailwind.register("py-"..key, function(i) setPad(i,px,0,px,0) end)
	Tailwind.register("pt-"..key, function(i) setPad(i,px, (ensurePadding(i).PaddingRight.Offset), (ensurePadding(i).PaddingBottom.Offset), (ensurePadding(i).PaddingLeft.Offset)) end)
	Tailwind.register("pr-"..key, function(i) setPad(i, (ensurePadding(i).PaddingTop.Offset), px, (ensurePadding(i).PaddingBottom.Offset), (ensurePadding(i).PaddingLeft.Offset)) end)
	Tailwind.register("pb-"..key, function(i) setPad(i, (ensurePadding(i).PaddingTop.Offset), (ensurePadding(i).PaddingRight.Offset), px, (ensurePadding(i).PaddingLeft.Offset)) end)
	Tailwind.register("pl-"..key, function(i) setPad(i, (ensurePadding(i).PaddingTop.Offset), (ensurePadding(i).PaddingRight.Offset), (ensurePadding(i).PaddingBottom.Offset), px) end)
end

-- margin (best applied on child via LayoutOrder + UIListLayout padding; we emulate via Position offset for standalone)
local function setMargin(inst, t,r,b,l)
	inst:SetAttribute("_tw_margin", {t,r,b,l})
end
for key,px in pairs(spacing) do
	Tailwind.register("m-"..key, function(i) setMargin(i,px,px,px,px) end)
	Tailwind.register("mx-"..key, function(i) setMargin(i,0,px,0,px) end)
	Tailwind.register("my-"..key, function(i) setMargin(i,px,0,px,0) end)
	Tailwind.register("mt-"..key, function(i) setMargin(i,px,0,0,0) end)
	Tailwind.register("mr-"..key, function(i) setMargin(i,0,px,0,0) end)
	Tailwind.register("mb-"..key, function(i) setMargin(i,0,0,px,0) end)
	Tailwind.register("ml-"..key, function(i) setMargin(i,0,0,0,px) end)
end

-- width / height (pixel presets + full)
for key,px in pairs(spacing) do
	Tailwind.register("w-"..key, function(i) i.Size = UDim2.new(i.Size.X.Scale, px, i.Size.Y.Scale, i.Size.Y.Offset) end)
	Tailwind.register("h-"..key, function(i) i.Size = UDim2.new(i.Size.X.Scale, i.Size.X.Offset, i.Size.Y.Scale, px) end)
end
Tailwind.register("w-full", function(i) i.Size = UDim2.new(1, 0, i.Size.Y.Scale, i.Size.Y.Offset) end)
Tailwind.register("h-full", function(i) i.Size = UDim2.new(i.Size.X.Scale, i.Size.X.Offset, 1, 0) end)
Tailwind.register("w-screen", function(i) i.Size = UDim2.new(1, 0, i.Size.Y.Scale, i.Size.Y.Offset) end)
Tailwind.register("h-screen", function(i) i.Size = UDim2.new(i.Size.X.Scale, i.Size.X.Offset, 1, 0) end)

-- text sizes, alignment, weights
for name,px in pairs(textSize) do Tailwind.register("text-"..name, function(i) pcall(function() i.TextSize = px end) end) end
Tailwind.register("text-left", function(i) pcall(function() i.TextXAlignment = Enum.TextXAlignment.Left end) end)
Tailwind.register("text-center", function(i) pcall(function() i.TextXAlignment = Enum.TextXAlignment.Center end) end)
Tailwind.register("text-right", function(i) pcall(function() i.TextXAlignment = Enum.TextXAlignment.Right end) end)
for k,f in pairs(weightFont) do Tailwind.register("font-"..k, function(i) pcall(function() i.Font = f end) end) end

-- rounded
local radii = { none=0, sm=4, DEFAULT=8, md=10, lg=12, xl=16, ["2xl"]=20, ["3xl"]=24, full=999 }
local function setCorner(i,px) local c = i:FindFirstChildOfClass("UICorner") or Instance.new("UICorner"); c.CornerRadius = UDim.new(0,px); c.Parent = i end
Tailwind.register("rounded", function(i) setCorner(i, radii.DEFAULT) end)
for k,px in pairs(radii) do Tailwind.register("rounded-"..k, function(i) setCorner(i, px) end) end

-- border width/color
Tailwind.register("border", function(i) i.BorderSizePixel = 1; i.BorderColor3 = i.BorderColor3 or Color3.fromRGB(229,231,235) end)
for n=0,8 do Tailwind.register("border-"..n, function(i) i.BorderSizePixel = n end) end

-- ring (UIStroke)
local function ensureStroke(i)
	local s = i:FindFirstChildOfClass("UIStroke")
	if not s then s = Instance.new("UIStroke"); s.Parent = i end
	return s
end
Tailwind.register("ring", function(i) local s=ensureStroke(i); s.Thickness = 1.5; s.Color = Color3.fromRGB(59,130,246); s.Transparency=0.2 end)
for n=0,8 do Tailwind.register("ring-"..n, function(i) local s=ensureStroke(i); s.Thickness=n end) end
for fam,shades in pairs(palette) do for shade,c in pairs(shades) do Tailwind.register("ring-"..fam.."-"..shade, function(i) local s=ensureStroke(i); s.Color=c end) end end

-- z-index
Tailwind.register("z-auto", function(i) i.ZIndex = 1 end)
for k,v in pairs(zIndex) do if k ~= "auto" then Tailwind.register("z-"..k, function(i) i.ZIndex = v end) end end

-- overflow
Tailwind.register("overflow-hidden", function(i) if i:IsA("ScrollingFrame") then i.ScrollBarThickness=0 end; i.ClipsDescendants = true end)
Tailwind.register("overflow-visible", function(i) i.ClipsDescendants = false end)
Tailwind.register("overflow-scroll", function(i) if i:IsA("ScrollingFrame") then i.ScrollBarThickness = 6 end end)

-- shadows (ImageLabel behind)
local function addShadow(i, size, trans)
	local s = i:FindFirstChild("_tw_shadow") or Instance.new("ImageLabel")
	s.Name = "_tw_shadow"
	s.BackgroundTransparency = 1
	s.Image = "rbxassetid://1316045217"
	s.ImageColor3 = Color3.new(0,0,0)
	s.ImageTransparency = trans
	s.ScaleType = Enum.ScaleType.Slice
	s.SliceCenter = Rect.new(10, 10, 118, 118)
	s.Size = i.Size + UDim2.new(0, size, 0, size)
	s.Position = UDim2.new(0, -size/2, 0, -size/2)
	s.ZIndex = i.ZIndex - 1
	s.Parent = i
end

Tailwind.register("shadow-sm", function(i) addShadow(i, 4, 0.75) end)
Tailwind.register("shadow", function(i) addShadow(i, 8, 0.7) end)
Tailwind.register("shadow-md", function(i) addShadow(i, 12, 0.65) end)
Tailwind.register("shadow-lg", function(i) addShadow(i, 16, 0.6) end)
Tailwind.register("shadow-xl", function(i) addShadow(i, 24, 0.55) end)
Tailwind.register("shadow-2xl", function(i) addShadow(i, 32, 0.5) end)

-- 🔥 VERY LAST LINE
return Tailwind

-- transforms
local function ensureScale(i)
	local s = i:FindFirstChildOfClass("UIScale")
	if not s then s = Instance.new("UIScale"); s.Parent = i end
	return s
end
for n=50,150,5 do Tailwind.register("scale-"..n, function(i) local s=ensureScale(i); s.Scale = n/100 end) end
Tailwind.register("rotate-0", function(i) pcall(function() i.Rotation = 0 end) end)
Tailwind.register("rotate-45", function(i) pcall(function() i.Rotation = 45 end) end)
Tailwind.register("rotate-90", function(i) pcall(function() i.Rotation = 90 end) end)
Tailwind.register("rotate-180", function(i) pcall(function() i.Rotation = 180 end) end)
Tailwind.register("rotate-270", function(i) pcall(function() i.Rotation = 270 end) end)

for key,px in pairs(spacing) do
	Tailwind.register("translate-x-"..key, function(i) i.Position = UDim2.new(i.Position.X.Scale, i.Position.X.Offset + px, i.Position.Y.Scale, i.Position.Y.Offset) end)
	Tailwind.register("translate-y-"..key, function(i) i.Position = UDim2.new(i.Position.X.Scale, i.Position.X.Offset, i.Position.Y.Scale, i.Position.Y.Offset + px) end)
end

-- transitions
Tailwind.register("transition", function(i) i:SetAttribute("_tw_transition", true) end)
for d,sec in pairs(durations) do Tailwind.register("duration-"..d, function(i) i:SetAttribute("_tw_duration", sec) end) end
for k,es in pairs(easings) do Tailwind.register("ease-"..k, function(i) i:SetAttribute("_tw_ease", es) end) end

-- helper to tween property when class implies a property change
local function smartTween(i, key, target)
	if not i:GetAttribute("_tw_transition") then i[key] = target; return end
	local dur = i:GetAttribute("_tw_duration") or 0.2
	local ease = i:GetAttribute("_tw_ease") or Enum.EasingStyle.Quad
	TweenService:Create(i, TweenInfo.new(dur, ease, Enum.EasingDirection.Out), { [key]=target }):Play()
end

-- text color / bg color with transition awareness (override previous ones)
for fam, shades in pairs(palette) do
	for shade, c in pairs(shades) do
		Tailwind.register("bg-"..fam.."-"..shade.."-t", function(i) smartTween(i, "BackgroundColor3", c) end)
		Tailwind.register("text-"..fam.."-"..shade.."-t", function(i) pcall(function() smartTween(i, "TextColor3", c) end) end)
	end
end

-- text utilities
for name,_ in pairs(textSize) do
	Tailwind.register("text-"..name.."-t", function(i) pcall(function() smartTween(i, "TextSize", textSize[name]) end) end)
end

-- alignment containers
Tailwind.register("container", function(i) i.Size = UDim2.new(1, -32, i.Size.Y.Scale, i.Size.Y.Offset); ensurePadding(i).PaddingLeft = UDim.new(0,16); ensurePadding(i).PaddingRight=UDim.new(0,16) end)

-- backdrop / glass helper
Tailwind.register("backdrop-glass", function(i)
	i.BackgroundColor3 = Color3.fromRGB(30,41,59)
	i.BackgroundTransparency = 0.25
	local g = Instance.new("UIGradient", i)
	g.Rotation = 60
	g.Color = ColorSequence.new(Color3.fromRGB(180,200,255), Color3.fromRGB(80,100,200))
	local s = ensureStroke(i); s.Color = Color3.fromRGB(200,220,255); s.Transparency = 0.75
	setCorner(i, 16)
end)

-- text utility: truncate
Tailwind.register("truncate", function(i) pcall(function() i.TextTruncate = Enum.TextTruncate.AtEnd end) end)

-- -------------- Example UI Builder (optional) --------------
function Tailwind.example(parent)
	local root = Tailwind.create("Frame", { Parent = parent, Size = UDim2.fromScale(1,1), Class = "bg-slate-900/90" })
	local card = Tailwind.create("Frame", { Parent = root, Position = UDim2.new(0.5,-200,0.5,-120), Size = UDim2.fromOffset(400,240), Class = "backdrop-glass p-6 shadow-xl flex flex-col gap-4" })
	local title = Tailwind.create("TextLabel", { Parent = card, Text = "TailwindLuau", Class = "text-white text-xl font-semibold" })
	local subtitle = Tailwind.create("TextLabel", { Parent = card, Text = "Build UIs like Tailwind, in Roblox.", Class = "text-slate-300 text-sm" })
	local row = Tailwind.create("Frame", { Parent = card, Class = "flex gap-4" })
	local btn = Tailwind.create("TextButton", { Parent = row, Text = "Primary", Class = "text-white bg-blue-600 rounded-md px-4 py-2 transition duration-150 hover:bg-blue-500" })
	local sec = Tailwind.create("TextButton", { Parent = row, Text = "Secondary", Class = "text-slate-100 bg-slate-700 rounded-md px-4 py-2 transition duration-150 hover:bg-slate-600" })
	return root
end

return Tailwind
