local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

type TimerReturn = {
	elapsedSeconds: number,
	start: () -> (),
	stop: () -> (),
	reset: () -> (),
	restore: (seconds: number) -> (),
	isRunning: boolean,
}

local function useTimer(): TimerReturn
	local elapsedSeconds, setElapsedSeconds = React.useState(0)
	local isRunning, setIsRunning = React.useState(false)
	local connectionRef = React.useRef(nil :: RBXScriptConnection?)
	local startTimeRef = React.useRef(0)
	local accumulatedRef = React.useRef(0)

	local start = React.useCallback(function()
		setIsRunning(true)
		startTimeRef.current = os.clock()
	end, {})

	local stop = React.useCallback(function()
		setIsRunning(false)
		if startTimeRef.current > 0 then
			accumulatedRef.current = accumulatedRef.current + (os.clock() - startTimeRef.current)
			startTimeRef.current = 0
		end
	end, {})

	local reset = React.useCallback(function()
		setIsRunning(false)
		setElapsedSeconds(0)
		accumulatedRef.current = 0
		startTimeRef.current = 0
		if connectionRef.current then
			connectionRef.current:Disconnect()
			connectionRef.current = nil
		end
	end, {})

	local restore = React.useCallback(function(seconds: number)
		accumulatedRef.current = seconds
		setElapsedSeconds(seconds)
	end, {})

	React.useEffect(function()
		if isRunning then
			connectionRef.current = RunService.Heartbeat:Connect(function()
				if startTimeRef.current > 0 then
					local total = accumulatedRef.current + (os.clock() - startTimeRef.current)
					setElapsedSeconds(total)
				end
			end)
		else
			if connectionRef.current then
				connectionRef.current:Disconnect()
				connectionRef.current = nil
			end
		end

		return function()
			if connectionRef.current then
				connectionRef.current:Disconnect()
				connectionRef.current = nil
			end
		end
	end, { isRunning } :: { any })

	return {
		elapsedSeconds = elapsedSeconds,
		start = start,
		stop = stop,
		reset = reset,
		restore = restore,
		isRunning = isRunning,
	}
end

return useTimer
