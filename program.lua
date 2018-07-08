shield_gate_addr = 'flux_gate_0'
out_gate_addr = 'flux_gate_2'
in_gate_addr = 'flux_gate_1'

function updateInfo()
return reactor.getReactorInfo()
end

function drawTable()

info = updateInfo()
term.clear()
adds = {}
adds['Power Order']=outputSetpoint
adds['Flow to Shield']=shield_gate.getFlow()
adds['Flow to Storage']=out_gate.getFlow()
adds['Flow from Storage']=in_gate.getFlow()
--[[
for k,v in pairs(info) do
if not string.match(k, 'max') then
standard_column_length=20
diff = standard_column_length - string.len(k)
for i=1,diff do
k = k..' '
end
diff = standard_column_length - string.len(v)
for i=1,diff do
v = v..' '
end
print(k..v)
end
end]]--
for k,v in pairs(adds) do
if not string.match(k, 'max') then
standard_column_length=20
local diff = standard_column_length - string.len(k)
for i=1,diff do
k = k..' '
end
local diff = standard_column_length - string.len(v)
for i=1,diff do
v = v..' '
end
print(k..v)
end
end
end

function dumpPower()
out_gate.setFlowOverride(0)
curr_flow = shield_gate.getFlow()
in_gate.setFlowOverride(curr_flow*5)
shield_gate.setFlowOverride(curr_flow*5)
end

function mapKeys()
--add in keybinds
	A=30
	S=31
	C=46
	T=20
end

function keyHandler(id)
	event, id = os.pullEvent('key')
	os.sleep(.1) --basically debouncing
	if id == 28 then
		print('Closing')
		shutdownReactor()
		continue=false
		shield_gate.setOverrideEnabled(false)
		out_gate.setOverrideEnabled(false)
		in_gate.setOverrideEnabled(false)
		func_code = -1
	end
	if id == 200 then
		outputSetpoint = outputSetpoint + 1000
	end
	if id == 208 then
		outputSetpoint = outputSetpoint - 1000
	end
	
	if id == S then
		func_code =  4
	end
	if id == A then
		func_code =  2
	end
	if id == C then
		func_code =  1
	end
	if id == T then
		waitFor = true
		waitFunc = typeSetpoint
	end
	return 10
end

function typeSetpoint()
outputSetpoint = read()
end

function getNextFrame()
	os.sleep(1)
	drawTable()
	if func_code ~= -1 then
	op_funcs[func_code]()
	end
end

function loadSettings()
	local file = fs.open('DEReactor/settings','r')
	local mode_code = file.readLine()+0 --Offline, Charged, Charging, Online
	local shield_gate_addr = file.readLine()
	local out_gate_addr = file.readLine()
	local in_gate_addr = file.readLine()
	local shield_flow = file.readLine()
	local out_flow = file.readLine()+0
	local in_flow = file.readLine()+0
	local setpoint = file.readLine()+0
	local shield_setpoint = file.readLine()+0
	file.close()
	return {mode_code, shield_gate_addr, out_gate_addr, in_gate_addr, shield_flow, out_flow, in_flow, setpoint, shield_setpoint}
end
	
function saveSettings()
	local file = fs.open('DEReactor/settings', 'w')
	file.writeLine(func_code)
	file.writeLine(shield_gate_addr)
	file.writeLine(out_gate_addr)
	file.writeLine(in_gate_addr)
	file.writeLine(shield_gate.getFlow())
	file.writeLine(out_gate.getFlow())
	file.writeLine(in_gate.getFlow())
	file.writeLine(outputSetpoint)
	file.writeLine(shieldSetpoint)
	file.close()
	os.sleep(2)
end

function reactor_resume(settings)
	reactor = peripheral.wrap('bottom')
	func_code = settings[1]
	shield_gate = peripheral.wrap(settings[2])
	out_gate = peripheral.wrap(settings[3])
	in_gate = peripheral.wrap(settings[4])
	shield_gate.setOverrideEnabled(true)
	out_gate.setOverrideEnabled(true)
	in_gate.setOverrideEnabled(true)
	
	shield_gate.setFlowOverride(settings[5]+0)
	out_gate.setFlowOverride(settings[6]+0)
	in_gate.setFlowOverride(settings[7]+0)

	TEMP_LIMIT = 8000
	SHIELD_LIMIT = .05
	SAT_LIMIT = .2

	SCALE_FACTOR = reactor.getReactorInfo().maxFieldStrength/100000000

	MAX_DELTA_P = 1000*100/5.5*SCALE_FACTOR
	MAX_DELTA_S = 1000
	MIN_DELTA_S = -500

	TEMP_CLAMP_FACTOR = 1 --play with these values
	SHIELD_CLAMP_FACTOR = 1
	SAT_CLAMP_FACTOR = 1

	PO_GAIN = 1
	SH_GAIN = 1
	outputSetpoint = settings[8]
	shieldSetpoint = settings[9]
end

function reactorInit()
fs.makeDir('DEReactor')
loaded, settings = pcall(loadSettings)
if loaded then
	reactor_resume(settings)
	else
	reactor = peripheral.wrap('bottom')
	shield_gate = peripheral.wrap(shield_gate_addr)
	out_gate = peripheral.wrap(out_gate_addr)
	in_gate = peripheral.wrap(in_gate_addr)
	shield_gate.setOverrideEnabled(true)
	out_gate.setOverrideEnabled(true)
	in_gate.setOverrideEnabled(true)

	TEMP_LIMIT = 8000
	SHIELD_LIMIT = .05
	SAT_LIMIT = .2

	SCALE_FACTOR = reactor.getReactorInfo().maxFieldStrength/100000000

	MAX_DELTA_P = 1000*100/5.5*SCALE_FACTOR
	MAX_DELTA_S = 1000
	MIN_DELTA_S = -500

	TEMP_CLAMP_FACTOR = 1 --play with these values
	SHIELD_CLAMP_FACTOR = 1
	SAT_CLAMP_FACTOR = 1

	PO_GAIN = 1
	SH_GAIN = 1
	outputSetpoint = 10000
	shieldSetpoint = .1
end
op_funcs = {}
op_funcs[1] = chargeReactor
op_funcs[2] = activateReactor
op_funcs[3] = steadyState
op_funcs[4] = shutdownReactor
mapKeys()
end

function clampPOTemp(temperature, delta_order)
if temperature >= TEMP_LIMIT and delta_order > 0 then
	return 0
else
	return delta_order
end
end

function clampPOShield(shieldPercentage, delta_order)
if shieldPercentage <= SHIELD_LIMIT and delta_order > 0 then
	return 0
else
	return delta_order
end
end

function clampPOSat(satPercentage, delta_order) --review saturation clamp
return delta_order
end

function applyClamps(reactorInfo, powerOrder)
	local po = powerOrder
    local saturation = reactorInfo.energySaturation / reactorInfo.maxEnergySaturation
	local temperature = reactorInfo.temperature
	local shield = reactorInfo.fieldStrength / reactorInfo.maxFieldStrength
	
	local deltaPOrder = math.min (MAX_DELTA_P, PO_GAIN * po) --limit how fast it can increase production (attempt at safety)
	po = clampPOTemp(temperature, po)
	po = clampPOShield(shield, po)
	po = clampPOSat(saturation, po)
	return po
end

function getShieldOrder(reactorInfo)
    local saturation = reactorInfo.energySaturation / reactorInfo.maxEnergySaturation
	local temperature = reactorInfo.temperature
	local shield = reactorInfo.fieldStrength / reactorInfo.maxFieldStrength
	local TOO_LOW = shield < SHIELD_LIMIT
	if TOO_LOW then dumpPower() shutdownReactor() end
	return ((SH_GAIN * (shieldSetpoint - shield)) + shield_gate.getFlow())
end

function chargeReactor() --func_code 1
info = updateInfo()
shield_gate.setFlowOverride(50000*100/5.5*SCALE_FACTOR)
out_gate.setFlowOverride(0)
in_gate.setFlowOverride(60000*100/5.5*SCALE_FACTOR)
--safe startup params
reactor.chargeReactor()
end

function activateReactor() --func_code 2
info = updateInfo()
if info.status == 'charged' then
	reactor.activateReactor()
	in_gate.setFlowOverride(0)
	out_gate.setFlowOverride(0)
	shield_gate.setFlowOverride(15000*100/5.5*SCALE_FACTOR) --it'll be producing net 0, generating 15000
	func_code = 3
elseif info.status == 'online' then
	in_gate.setFlowOverride(0)
	func_code = 3
else
	print('Reactor must be charged!')
	os.sleep(.5)
end
end

function shutdownReactor() --func_code 4
	reactor.stopReactor()
	func_code = -1
	out_gate.setFlowOverride(0)
	in_gate.setFlowOverride(50000*100/5.5*SCALE_FACTOR)
	shield_gate.setFlowOverride(50000*100/5.5*SCALE_FACTOR)
	--TODO adjust these values, maybe we don't need to shutdown off of backup power
	while reactor.getReactorInfo().temperature > 2000 do
	print('Shutting Down...')
		os.sleep(1)
	end
end

function steadyState() --func_code 3
 --math about maintaining set point
	reactorInfo = reactor.getReactorInfo()
	current_out = out_gate.getFlow()
	out_gate.setFlowOverride(current_out + math.min(MAX_DELTA_P, outputSetpoint - current_out))
	--move output by increments of at most 1000 to the desired setpoint
	

	if reactorInfo.fieldStrength > SHIELD_LIMIT * reactorInfo.maxFieldStrength or
	reactorInfo.temperature > TEMP_LIMIT
	then
		shield_gate.setFlowOverride((1/(1-shieldSetpoint)) * reactorInfo.fieldDrainRate)
	else
		dumpPower()
		func_code = 4
	end	
end

function reactorRun()
func_code = -1
continue = true
while continue do
	parallel.waitForAny(getNextFrame,keyHandler, saveSettings)
	if waitFor then
		waitFunc()
		waitFor = false
end
end
end


reactorInit()
reactorRun()