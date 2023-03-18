-- KEVN test / demo launcher for LÖVE 11.x.
-- In LÖVE 12, you can just run the demo files directly.

function love.load(arguments)
	local demo_id = arguments[1] or "ltest"

	require(demo_id)
end
