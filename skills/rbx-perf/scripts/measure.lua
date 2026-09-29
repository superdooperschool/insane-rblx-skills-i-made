-- Client: warm up, then sample RenderStepped dt + FrameRateManager for SECONDS. Returns fps, percentiles, averages.
local SECONDS = __SEC__
local RS = game:GetService("RunService")
local frm = game:GetService("Stats"):FindFirstChild("FrameRateManager")
local function v(n) local c = frm and frm:FindFirstChild(n) return c and c:GetValue() or 0 end
task.wait(2)
local sums, n, dts = {}, 0, {}
local keys = { "PrepareAverage", "PerformAverage", "RenderThreadAverage", "RenderAverage", "Batches", "Indices" }
local conn = RS.RenderStepped:Connect(function(dt) table.insert(dts, dt * 1000) end)
local t0 = os.clock()
while os.clock() - t0 < SECONDS do
	task.wait(0.25)
	n += 1
	for _, k in keys do sums[k] = (sums[k] or 0) + v(k) end
end
conn:Disconnect()
table.sort(dts)
local function pct(p) return #dts > 0 and math.floor(dts[math.max(1, math.ceil(#dts * p))] * 100 + 0.5) / 100 or 0 end
local over16, over33 = 0, 0
for _, d in dts do if d > 16.7 then over16 += 1 end if d > 33.3 then over33 += 1 end end
local o = { fps = math.floor(#dts / (os.clock() - t0) + 0.5), p50 = pct(0.5), p95 = pct(0.95), p99 = pct(0.99), max = pct(1), over16 = over16, over33 = over33, frames = #dts }
for _, k in keys do o[k] = math.floor(sums[k] / math.max(1, n) * 100 + 0.5) / 100 end
local root = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
o.pos = root and tostring(root.Position) or "?"
return o
