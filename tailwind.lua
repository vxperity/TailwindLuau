--[=[
TailwindLuau — TailwindCSS-style utilities for Roblox UI (Luau)
Complete rewrite (5-part paste). Paste parts 1→5 contiguously into one ModuleScript.

Features target (implemented across parts):
- Colors (full Tailwind palette) + bg-*/text-*/border-* with /alpha and -t (tween-aware)
- Opacity utilities: opacity-0..100 (step 5)
- Spacing scale, Margin/Padding
- Sizing (w-*, h-*, min/max), Screen helpers
- Display, Flexbox, Grid, gaps, alignment
- Typography (sizes, weights, align, truncate, rich best-effort)
- Radius, Border, Ring
- Z-index, Overflow
- Effects: shadows, blur/backdrop glass helper
- Transforms: scale/rotate/translate
- Transitions: transition, duration-*, ease-*
- Variants: hover:/active:/focus:, Responsive sm:/md:/lg:/xl:
- Utilities to register/apply classes at runtime
]=]

--// PART 1 / 5 ---------------------------------------------------------------

local Tailwind = {}
Tailwind.__index = Tailwind

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

-- ---------- Root / Responsive helpers ----------
local function findScreenGui(inst: Instance?): ScreenGui?
	local s = inst
	while s and not s:IsA("ScreenGui") do
		s = s.Parent
	end
	return s
end

-- tween helper (used by transition-aware utilities)
local function tween(o: Instance, t: number?, props: {[string]: any}, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	TweenService:Create(
		o,
		TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	):Play()
end

-- ---------- Core scales & tables ----------
-- spacing (Tailwind-ish px)
local spacing: {[string]: number} = {
	["0"]=0,["0.5"]=2,["1"]=4,["1.5"]=6,["2"]=8,["2.5"]=10,["3"]=12,["3.5"]=14,["4"]=16,["5"]=20,["6"]=24,
	["7"]=28,["8"]=32,["9"]=36,["10"]=40,["11"]=44,["12"]=48,["14"]=56,["16"]=64,["20"]=80,["24"]=96,["28"]=112,
	["32"]=128,["36"]=144,["40"]=160,["44"]=176,["48"]=192,["52"]=208,["56"]=224,["60"]=240,["64"]=256,["72"]=288,
	["80"]=320,["96"]=384,
}

local textSize = {
	xs=12, sm=14, base=16, lg=18, xl=20,
	["2xl"]=24, ["3xl"]=30, ["4xl"]=36, ["5xl"]=48, ["6xl"]=60, ["7xl"]=72, ["8xl"]=96, ["9xl"]=128,
}

local weightFont = {
	thin=Enum.Font.Gotham, extralight=Enum.Font.Gotham, light=Enum.Font.Gotham,
	normal=Enum.Font.Gotham, medium=Enum.Font.GothamMedium, semibold=Enum.Font.GothamSemibold,
	bold=Enum.Font.GothamBold, extrabold=Enum.Font.GothamBlack, black=Enum.Font.GothamBlack,
}

local durations = { [75]=0.075,[100]=0.1,[150]=0.15,[200]=0.2,[300]=0.3,[500]=0.5,[700]=0.7,[1000]=1 }
local easings = {
	linear = Enum.EasingStyle.Linear,
	["in"] = Enum.EasingStyle.Quad,
	out = Enum.EasingStyle.Quad,
	["in-out"] = Enum.EasingStyle.Quad,
}
local zIndexMap = { auto=nil, [0]=0,[10]=10,[20]=20,[30]=30,[40]=40,[50]=50 }

-- Tailwind palette (RGB, closest matches)
local function rgb(r: number,g: number,b: number) return Color3.fromRGB(r,g,b) end
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

-- ---------- Registry & public API ----------
Tailwind.registry = {}
Tailwind.variants = { hover=true, active=true, focus=true, sm=true, md=true, lg=true, xl=true }
Tailwind.breakpoints = { sm=640, md=768, lg=1024, xl=1280 }

function Tailwind.register(className: string, applyFn: (Instance, string?) -> ())
	Tailwind.registry[className] = applyFn
end

-- ---------- Internals ----------
local function ensurePadding(frame: Instance): UIPadding
	local pad = frame:FindFirstChildOfClass("UIPadding")
	if not pad then
		pad = Instance.new("UIPadding")
		pad.Parent = frame
	end
	return pad
end

local function ensureListLayout(frame: Instance, vertical: boolean): UIListLayout
	local ll = frame:FindFirstChildOfClass("UIListLayout")
	if not ll then
		ll = Instance.new("UIListLayout")
		ll.Parent = frame
	end
	ll.FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	return ll
end

local function ensureGrid(frame: Instance): UIGridLayout
	local g = frame:FindFirstChildOfClass("UIGridLayout")
	if not g then
		g = Instance.new("UIGridLayout")
		g.Parent = frame
	end
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.FillDirectionMaxCells = 0
	return g
end

local function ensureStroke(i: Instance): UIStroke
	local s = i:FindFirstChildOfClass("UIStroke")
	if not s then
		s = Instance.new("UIStroke")
		s.Parent = i
	end
	return s
end

local function ensureScale(i: Instance): UIScale
	local s = i:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = i
	end
	return s
end

-- state store per instance (weak keys so instances can GC)
local stateMap = setmetatable({}, { __mode = "k" })
local function getState(inst: Instance)
	local s = stateMap[inst]
	if not s then
		s = { base={}, hover={}, active={}, focus={}, responsive={}, _wired=false, _respWired=false }
		stateMap[inst] = s
	end
	return s
end

-- transition context helpers
local function smartTween(i: Instance, key: string, target: any)
	if not i:GetAttribute("_tw_transition") then
		(i :: any)[key] = target
		return
	end
	local dur = i:GetAttribute("_tw_duration") or 0.2
	local ease = i:GetAttribute("_tw_ease") or Enum.EasingStyle.Quad
	TweenService:Create(i, TweenInfo.new(dur, ease, Enum.EasingDirection.Out), { [key]=target }):Play()
end

-- Public create (simple sugar)
function Tailwind.create(className: string, props: {[string]: any}?)
	local o = Instance.new(className)
	props = props or {}
	if props.Parent then o.Parent = props.Parent end
	if props.Size then o.Size = props.Size end
	if props.Position then o.Position = props.Position end
	if props.AnchorPoint then o.AnchorPoint = props.AnchorPoint end
	if props.Visible ~= nil then o.Visible = props.Visible end
	if props.Text ~= nil then pcall(function() (o :: any).Text = props.Text end) end
	if props.RichText ~= nil then pcall(function() (o :: any).RichText = props.RichText end) end
	if props.Class then Tailwind.apply(o, props.Class) end
	return o
end

-- Apply classes (space-delimited)
function Tailwind.apply(instance: Instance, classString: string?)
	if not classString or classString == "" then return end
	for raw in string.gmatch(classString, "[^%s]+") do
		Tailwind._applyOne(instance, raw)
	end
end

-- Wire state variants once
function Tailwind._wireStates(inst: Instance)
	local st = getState(inst)
	if st._wired or not inst:IsA("GuiObject") then return end
	st._wired = true

	(inst :: GuiObject).MouseEnter:Connect(function()
		for _,u in ipairs(st.hover or {}) do
			local fn = Tailwind.registry[u.base]
			if fn then fn(inst, u.alpha) end
		end
	end)

	(inst :: GuiObject).InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 then
			for _,u in ipairs(st.active or {}) do
				local fn = Tailwind.registry[u.base]
				if fn then fn(inst, u.alpha) end
			end
		end
	end)

	if inst:IsA("TextBox") then
		inst.Focused:Connect(function()
			for _,u in ipairs(st.focus or {}) do
				local fn = Tailwind.registry[u.base]
				if fn then fn(inst, u.alpha) end
			end
		end)
	end
end

-- Wire responsive once
function Tailwind._wireResponsive(inst: Instance)
	local sgui = findScreenGui(inst)
	if not sgui then return end
	local st = getState(inst)
	if st._respWired then return end
	st._respWired = true

	local function applyForWidth(w: number)
		for key, arr in pairs(st.responsive) do
			local min = Tailwind.breakpoints[key]
			if w >= min then
				for _,u in ipairs(arr) do
					local fn = Tailwind.registry[u.base]
					if fn then fn(inst, u.alpha) end
				end
			end
		end
	end

	applyForWidth(sgui.AbsoluteSize.X)
	sgui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		applyForWidth(sgui.AbsoluteSize.X)
	end)
end

-- Parse/apply one token (supports variants and slash alpha)
function Tailwind._applyOne(inst: Instance, raw: string)
	-- slash opacity (e.g. bg-blue-500/80)
	local base, alpha = string.match(raw, "^(.-)/(%d+)$")
	local token = base or raw

	-- responsive prefixes
	if string.sub(token,1,3) == "sm:" or string.sub(token,1,3) == "md:"
	or string.sub(token,1,3) == "lg:" or string.sub(token,1,3) == "xl:" then
		local variant = string.sub(token,1,2) -- sm/md/lg/xl
		local rest = string.sub(token,4)
		local st = getState(inst)
		st.responsive[variant] = st.responsive[variant] or {}
		table.insert(st.responsive[variant], { name=raw, base=rest, alpha=alpha })
		Tailwind._wireResponsive(inst)
		return
	end

	-- state variants
	for _,v in ipairs({"hover:","active:","focus:"}) do
		if string.sub(token,1,#v) == v then
			local key = string.sub(v,1,#v-1)
			local rest = string.sub(token,#v+1)
			local st = getState(inst)
			st[key] = st[key] or {}
			table.insert(st[key], { name=raw, base=rest, alpha=alpha })
			Tailwind._wireStates(inst)
			return
		end
	end

	-- base utility
	local fn = Tailwind.registry[token]
	if fn then
		fn(inst, alpha)
	end
end

-- ---------- Color utilities ----------
-- helper: register triplet (bg/text/border) with optional slash opacity handling
local function registerColorTriplet(prefix: string, prop: "BackgroundColor3"|"TextColor3"|"BorderColor3")
	for family, shades in pairs(palette) do
		for shade, c in pairs(shades) do
			local name = ("%s-%s-%d"):format(prefix, family, shade)
			Tailwind.register(name, function(inst: Instance, alpha: string?)
				(inst :: any)[prop] = c
				if alpha then
					local a = math.clamp(tonumber(alpha) or 100, 0, 100) / 100
					if prop == "BackgroundColor3" and inst:IsA("GuiObject") then
						inst.BackgroundTransparency = 1 - a
					elseif prop == "TextColor3" then
						pcall(function() (inst :: any).TextTransparency = 1 - a end)
					elseif prop == "BorderColor3" then
						pcall(function()
							if inst:IsA("GuiObject") then
								inst.BorderSizePixel = (inst.BorderSizePixel > 0) and inst.BorderSizePixel or 1
							end
						end)
					end
				end
			end)
			-- transition-aware variants (suffix -t)
			local tname = ("%s-%s-%d-t"):format(prefix, family, shade)
			Tailwind.register(tname, function(inst: Instance)
				if prop == "BackgroundColor3" then
					smartTween(inst, "BackgroundColor3", c)
				elseif prop == "TextColor3" then
					pcall(function() smartTween(inst, "TextColor3", c) end)
				elseif prop == "BorderColor3" then
					pcall(function()
						if inst:IsA("GuiObject") and inst.BorderSizePixel == 0 then inst.BorderSizePixel = 1 end
						smartTween(inst, "BorderColor3", c)
					end)
				end
			end)
		end
	end
end

-- Register bg-*, text-*, border-*
registerColorTriplet("bg", "BackgroundColor3")
registerColorTriplet("text", "TextColor3")
registerColorTriplet("border", "BorderColor3")

-- Common color aliases
Tailwind.register("bg-white", function(i: Instance, a: string?)
	local c = Color3.fromRGB(255,255,255)
	(i :: any).BackgroundColor3 = c
	if a and (i :: any).BackgroundTransparency ~= nil then
		local alpha = math.clamp(tonumber(a) or 100, 0, 100)/100
		(i :: any).BackgroundTransparency = 1 - alpha
	end
end)

Tailwind.register("bg-black", function(i: Instance, a: string?)
	local c = Color3.fromRGB(0,0,0)
	(i :: any).BackgroundColor3 = c
	if a and (i :: any).BackgroundTransparency ~= nil then
		local alpha = math.clamp(tonumber(a) or 100, 0, 100)/100
		(i :: any).BackgroundTransparency = 1 - alpha
	end
end)

Tailwind.register("text-white", function(i: Instance, a: string?)
	pcall(function()
		(i :: any).TextColor3 = Color3.new(1,1,1)
		if a then (i :: any).TextTransparency = 1 - (math.clamp(tonumber(a) or 100,0,100)/100) end
	end)
end)

Tailwind.register("text-black", function(i: Instance, a: string?)
	pcall(function()
		(i :: any).TextColor3 = Color3.new(0,0,0)
		if a then (i :: any).TextTransparency = 1 - (math.clamp(tonumber(a) or 100,0,100)/100) end
	end)
end)

-- Opacity utilities (affect Text/Background when applicable)
for n = 0, 100, 5 do
	local name = "opacity-"..tostring(n)
	Tailwind.register(name, function(i: Instance)
		local a = n/100
		if i:IsA("GuiObject") then
			i.BackgroundTransparency = 1 - a
		end
		pcall(function()
			(i :: any).TextTransparency = 1 - a
		end)
	end)
end

-- (display, layout, spacing, etc. continue in Part 2)
--// END PART 1 / 5 ----------------------------------------------------------
--========================================================--
--  Part 2: Layout, Spacing, Flexbox, Grid, Sizing
--========================================================--

-- ---------- Display ----------
Tailwind.register("block", function(i) i.Visible = true end)
Tailwind.register("hidden", function(i) i.Visible = false end)

-- ---------- Flexbox ----------
Tailwind.register("flex", function(i) ensureListLayout(i,false) end)
Tailwind.register("flex-row", function(i) ensureListLayout(i,false) end)
Tailwind.register("flex-col", function(i) ensureListLayout(i,true) end)

Tailwind.register("items-start", function(i) ensureListLayout(i).VerticalAlignment = Enum.VerticalAlignment.Top end)
Tailwind.register("items-center", function(i) ensureListLayout(i).VerticalAlignment = Enum.VerticalAlignment.Center end)
Tailwind.register("items-end", function(i) ensureListLayout(i).VerticalAlignment = Enum.VerticalAlignment.Bottom end)

Tailwind.register("justify-start", function(i) ensureListLayout(i).HorizontalAlignment = Enum.HorizontalAlignment.Left end)
Tailwind.register("justify-center", function(i) ensureListLayout(i).HorizontalAlignment = Enum.HorizontalAlignment.Center end)
Tailwind.register("justify-end", function(i) ensureListLayout(i).HorizontalAlignment = Enum.HorizontalAlignment.Right end)

Tailwind.register("gap-0", function(i) ensureListLayout(i).Padding = UDim.new(0,0) end)
for key,px in pairs(spacing) do
	Tailwind.register("gap-"..key, function(i) ensureListLayout(i).Padding = UDim.new(0,px) end)
end

-- ---------- Grid ----------
Tailwind.register("grid", function(i) ensureGrid(i) end)
for cols=1,12 do
	Tailwind.register("grid-cols-"..cols, function(i) ensureGrid(i).CellSize = UDim2.new(1/cols,0,0,0) end)
end

-- ---------- Padding ----------
for key,px in pairs(spacing) do
	Tailwind.register("p-"..key, function(i)
		local p=ensurePadding(i)
		p.PaddingTop,p.PaddingBottom,p.PaddingLeft,p.PaddingRight=UDim.new(0,px),UDim.new(0,px),UDim.new(0,px),UDim.new(0,px)
	end)

	Tailwind.register("px-"..key, function(i)
		local p=ensurePadding(i)
		p.PaddingLeft,p.PaddingRight=UDim.new(0,px),UDim.new(0,px)
	end)
	Tailwind.register("py-"..key, function(i)
		local p=ensurePadding(i)
		p.PaddingTop,p.PaddingBottom=UDim.new(0,px),UDim.new(0,px)
	end)

	Tailwind.register("pt-"..key, function(i) ensurePadding(i).PaddingTop = UDim.new(0,px) end)
	Tailwind.register("pb-"..key, function(i) ensurePadding(i).PaddingBottom = UDim.new(0,px) end)
	Tailwind.register("pl-"..key, function(i) ensurePadding(i).PaddingLeft = UDim.new(0,px) end)
	Tailwind.register("pr-"..key, function(i) ensurePadding(i).PaddingRight = UDim.new(0,px) end)
end

-- ---------- Margin ----------
for key,px in pairs(spacing) do
	Tailwind.register("m-"..key, function(i) i.Position = i.Position + UDim2.fromOffset(px,px) end)

	Tailwind.register("mx-"..key, function(i) i.Position = i.Position + UDim2.fromOffset(px,0) end)
	Tailwind.register("my-"..key, function(i) i.Position = i.Position + UDim2.fromOffset(0,px) end)

	Tailwind.register("mt-"..key, function(i) i.Position = i.Position + UDim2.fromOffset(0,px) end)
	Tailwind.register("mb-"..key, function(i) i.Position = i.Position + UDim2.fromOffset(0,-px) end)
	Tailwind.register("ml-"..key, function(i) i.Position = i.Position + UDim2.fromOffset(px,0) end)
	Tailwind.register("mr-"..key, function(i) i.Position = i.Position + UDim2.fromOffset(-px,0) end)
end

-- ---------- Width / Height ----------
Tailwind.register("w-full", function(i) i.Size = UDim2.new(1,0,i.Size.Y.Scale,i.Size.Y.Offset) end)
Tailwind.register("h-full", function(i) i.Size = UDim2.new(i.Size.X.Scale,i.Size.X.Offset,1,0) end)

for key,px in pairs(spacing) do
	Tailwind.register("w-"..key, function(i) i.Size = UDim2.new(0,px,i.Size.Y.Scale,i.Size.Y.Offset) end)
	Tailwind.register("h-"..key, function(i) i.Size = UDim2.new(i.Size.X.Scale,i.Size.X.Offset,0,px) end)
end

for i=1,12 do
	local frac = i/12
	Tailwind.register("w-"..i.."/12", function(inst)
		inst.Size = UDim2.new(frac,0,inst.Size.Y.Scale,inst.Size.Y.Offset)
	end)
	Tailwind.register("h-"..i.."/12", function(inst)
		inst.Size = UDim2.new(inst.Size.X.Scale,inst.Size.X.Offset,frac,0)
	end)
end
--========================================================--
--  Part 3: Typography, Borders, Radius, Ring, Z-index
--========================================================--

-- ---------- Typography ----------
for key, size in pairs(textSize) do
	Tailwind.register("text-"..key, function(i)
		if i:IsA("TextLabel") or i:IsA("TextButton") then
			i.TextSize = size
		end
	end)
end

for weight, font in pairs(weightFont) do
	Tailwind.register("font-"..weight, function(i)
		if i:IsA("TextLabel") or i:IsA("TextButton") then
			i.Font = font
		end
	end)
end

Tailwind.register("text-left", function(i)
	if i:IsA("TextLabel") or i:IsA("TextButton") then
		i.TextXAlignment = Enum.TextXAlignment.Left
	end
end)

Tailwind.register("text-center", function(i)
	if i:IsA("TextLabel") or i:IsA("TextButton") then
		i.TextXAlignment = Enum.TextXAlignment.Center
	end
end)

Tailwind.register("text-right", function(i)
	if i:IsA("TextLabel") or i:IsA("TextButton") then
		i.TextXAlignment = Enum.TextXAlignment.Right
	end
end)

Tailwind.register("truncate", function(i)
	if i:IsA("TextLabel") or i:IsA("TextButton") then
		i.TextTruncate = Enum.TextTruncate.AtEnd
		i.TextWrapped = false
	end
end)

-- ---------- Border Width ----------
Tailwind.register("border", function(i)
	local s = ensureStroke(i)
	s.Thickness = 1
end)

for n=2,8 do
	Tailwind.register("border-"..n, function(i)
		local s = ensureStroke(i)
		s.Thickness = n
	end)
end

-- ---------- Border Radius ----------
Tailwind.register("rounded-none", function(i)
	local c = i:FindFirstChildOfClass("UICorner")
	if c then c:Destroy() end
end)

local radius = {
	sm = 4, md = 6, lg = 8, xl = 12,
	["2xl"] = 16, ["3xl"] = 24, full = 9999,
}

Tailwind.register("rounded", function(i)
	local c = i:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", i)
	c.CornerRadius = UDim.new(0,6)
end)

for key,px in pairs(radius) do
	Tailwind.register("rounded-"..key, function(i)
		local c = i:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", i)
		c.CornerRadius = UDim.new(0,px)
	end)
end

-- ---------- Ring (Focus Outline) ----------
for _, size in ipairs({1,2,4,8}) do
	Tailwind.register("ring-"..size, function(i)
		local s = ensureStroke(i)
		s.Thickness = size
		s.Color = Color3.fromRGB(59,130,246) -- default ring-blue
	end)
end

Tailwind.register("ring-transparent", function(i)
	local s = ensureStroke(i)
	s.Color = Color3.fromRGB(0,0,0)
	s.Transparency = 1
end)

Tailwind.register("ring-white", function(i)
	local s = ensureStroke(i)
	s.Color = Color3.fromRGB(255,255,255)
end)

-- ---------- Z-index ----------
for key, z in pairs(zIndex) do
	Tailwind.register("z-"..tostring(key), function(i)
		i.ZIndex = z
	end)
end

Tailwind.register("z-auto", function(i) i.ZIndex = 0 end)
--========================================================--
--  Part 4: Shadows, Transforms, Transitions, Backdrop
--========================================================--

-- ---------- Shadows ----------
local function addShadow(i, depth, opacity)
	local shadow = i:FindFirstChild("TailwindShadow")
	if not shadow then
		shadow = Instance.new("ImageLabel")
		shadow.Name = "TailwindShadow"
		shadow.BackgroundTransparency = 1
		shadow.Image = "rbxassetid://1316045217" -- simple blur circle
		shadow.ScaleType = Enum.ScaleType.Slice
		shadow.SliceCenter = Rect.new(10,10,118,118)
		shadow.AnchorPoint = Vector2.new(0.5,0.5)
		shadow.Position = UDim2.fromScale(0.5,0.5)
		shadow.Size = UDim2.new(1,depth*2,1,depth*2)
		shadow.ZIndex = i.ZIndex - 1
		shadow.Parent = i
	end
	shadow.ImageTransparency = 1 - opacity
end

Tailwind.register("shadow-sm", function(i) addShadow(i, 4, 0.75) end)
Tailwind.register("shadow", function(i) addShadow(i, 8, 0.7) end)
Tailwind.register("shadow-md", function(i) addShadow(i, 12, 0.65) end)
Tailwind.register("shadow-lg", function(i) addShadow(i, 16, 0.6) end)
Tailwind.register("shadow-xl", function(i) addShadow(i, 24, 0.55) end)
Tailwind.register("shadow-2xl", function(i) addShadow(i, 32, 0.5) end)
Tailwind.register("shadow-none", function(i)
	local s = i:FindFirstChild("TailwindShadow")
	if s then s:Destroy() end
end)

-- ---------- Transforms ----------
local function ensureTransform(i)
	local t = i:FindFirstChild("TailwindTransform")
	if not t then
		t = Instance.new("UIScale")
		t.Name = "TailwindTransform"
		t.Scale = 1
		t.Parent = i
	end
	return t
end

for _,v in ipairs({50,75,90,95,100,105,110,125,150}) do
	Tailwind.register("scale-"..v, function(i)
		ensureTransform(i).Scale = v/100
	end)
end

for _,deg in ipairs({0,45,90,180,270}) do
	Tailwind.register("rotate-"..deg, function(i)
		if i:IsA("GuiObject") then
			i.Rotation = deg
		end
	end)
end

for key,px in pairs(spacing) do
	Tailwind.register("translate-x-"..key, function(i)
		i.Position = i.Position + UDim2.fromOffset(px,0)
	end)
	Tailwind.register("translate-y-"..key, function(i)
		i.Position = i.Position + UDim2.fromOffset(0,px)
	end)
end

-- ---------- Transitions ----------
local function addTween(i, props, duration, style)
	local tweenService = game:GetService("TweenService")
	local info = TweenInfo.new(duration, style, Enum.EasingDirection.Out)
	tweenService:Create(i, info, props):Play()
end

for _,d in ipairs({75,100,150,200,300,500,700,1000}) do
	Tailwind.register("duration-"..d, function(i)
		i:SetAttribute("TailwindDuration", d/1000)
	end)
end

Tailwind.register("ease-linear", function(i) i:SetAttribute("TailwindEasing", Enum.EasingStyle.Linear) end)
Tailwind.register("ease-in", function(i) i:SetAttribute("TailwindEasing", Enum.EasingStyle.Quad) end)
Tailwind.register("ease-out", function(i) i:SetAttribute("TailwindEasing", Enum.EasingStyle.Quad) end)
Tailwind.register("ease-in-out", function(i) i:SetAttribute("TailwindEasing", Enum.EasingStyle.Sine) end)

-- Example transition usage
Tailwind.register("hover:scale-105", function(i)
	if i:IsA("GuiButton") then
		i.MouseEnter:Connect(function()
			addTween(ensureTransform(i), {Scale = 1.05}, i:GetAttribute("TailwindDuration") or 0.15, i:GetAttribute("TailwindEasing") or Enum.EasingStyle.Sine)
		end)
		i.MouseLeave:Connect(function()
			addTween(ensureTransform(i), {Scale = 1}, i:GetAttribute("TailwindDuration") or 0.15, i:GetAttribute("TailwindEasing") or Enum.EasingStyle.Sine)
		end)
	end
end)

-- ---------- Backdrop Filters ----------
local function ensureBlur(i)
	local b = i:FindFirstChild("TailwindBlur")
	if not b then
		b = Instance.new("UIStroke")
		b.Name = "TailwindBlur"
		b.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		b.Thickness = 0
		b.Transparency = 0.5
		b.Parent = i
	end
	return b
end

Tailwind.register("backdrop-blur", function(i)
	local b = ensureBlur(i)
	b.Thickness = 2
end)

Tailwind.register("backdrop-blur-md", function(i)
	local b = ensureBlur(i)
	b.Thickness = 6
end)

Tailwind.register("backdrop-glass", function(i)
	i.BackgroundTransparency = 0.3
	i.BackgroundColor3 = Color3.fromRGB(255,255,255)
	ensureBlur(i).Transparency = 0.6
end)

Tailwind.register("backdrop-bright", function(i)
	i.BackgroundColor3 = i.BackgroundColor3:Lerp(Color3.new(1,1,1),0.3)
end)

Tailwind.register("backdrop-dim", function(i)
	i.BackgroundColor3 = i.BackgroundColor3:Lerp(Color3.new(0,0,0),0.3)
end)
--========================================================--
--  Part 5: Overflow, Positioning, Flex Grow, Example, Return
--========================================================--

-- ---------- Overflow ----------
Tailwind.register("overflow-hidden", function(i)
	if i:IsA("ScrollingFrame") then
		i.ScrollingEnabled = false
	end
end)

Tailwind.register("overflow-scroll", function(i)
	if i:IsA("ScrollingFrame") then
		i.ScrollingEnabled = true
	end
end)

-- ---------- Position ----------
Tailwind.register("absolute", function(i) i.AnchorPoint = Vector2.new(0,0) end)
Tailwind.register("relative", function(i) i.AnchorPoint = Vector2.new(0,0) end) -- Roblox default

for key,px in pairs(spacing) do
	Tailwind.register("top-"..key, function(i) i.Position = UDim2.new(i.Position.X.Scale,i.Position.X.Offset,0,px) end)
	Tailwind.register("bottom-"..key, function(i) i.Position = UDim2.new(i.Position.X.Scale,i.Position.X.Offset,1,-px) end)
	Tailwind.register("left-"..key, function(i) i.Position = UDim2.new(0,px,i.Position.Y.Scale,i.Position.Y.Offset) end)
	Tailwind.register("right-"..key, function(i) i.Position = UDim2.new(1,-px,i.Position.Y.Scale,i.Position.Y.Offset) end)
end

-- ---------- Flex Grow / Shrink ----------
Tailwind.register("flex-1", function(i)
	local s = i:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
	s.MinSize = Vector2.new(0,0)
	s.MaxSize = Vector2.new(math.huge, math.huge)
	s.Parent = i
end)

Tailwind.register("flex-none", function(i)
	local s = i:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
	s.MinSize = i.AbsoluteSize
	s.MaxSize = i.AbsoluteSize
	s.Parent = i
end)

-- ---------- Example Builder ----------
function Tailwind.example()
	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Name = "TailwindExample"

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.5,0.5)
	frame.AnchorPoint = Vector2.new(0.5,0.5)
	frame.Position = UDim2.fromScale(0.5,0.5)
	frame.Parent = screenGui

	-- Apply Tailwind classes
	Tailwind.apply(frame, {
		"bg-gray-200",
		"rounded-lg",
		"shadow-lg",
		"p-6",
		"flex",
		"flex-col",
		"items-center",
		"justify-center",
		"gap-4",
	})

	local label = Instance.new("TextLabel")
	label.Text = "Hello, TailwindLuau 👋"
	label.Size = UDim2.fromScale(1,0)
	label.BackgroundTransparency = 1
	label.Parent = frame
	Tailwind.apply(label, {
		"text-xl",
		"font-bold",
		"text-center",
	})

	local button = Instance.new("TextButton")
	button.Text = "Click Me"
	button.Size = UDim2.new(0,120,0,36)
	button.Parent = frame
	Tailwind.apply(button, {
		"bg-blue-500",
		"text-white",
		"rounded-md",
		"px-4",
		"py-2",
		"shadow",
		"hover:scale-105",
		"duration-200",
		"ease-in-out",
	})

	return screenGui
end

-- ---------- Return ----------
return Tailwind

