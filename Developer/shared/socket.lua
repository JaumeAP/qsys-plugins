-- Generic TcpSocket construction + IPv4 address validation, factored out of
-- Dolby CPSeries Control's own runtime.lua so any future plugin needing a
-- TCP client can reuse it instead of duplicating this boilerplate. Kept as
-- a plain global table with no require/return (PLUGCC.exe inlines
-- #include'd files as plain source, not loadable modules), same pattern as
-- qknob.lua/dolbyfader.lua.

SocketConn = {}
SocketConn.__index = SocketConn

-- IPv4 dotted-quad validator.
function SocketConn.ValidateAddress(ip)
	local chunks = { string.match(ip, "^(%d+)%.(%d+)%.(%d+)%.(%d+)$") }
	if #chunks < 4 then
		return false
	end
	for _, v in pairs(chunks) do
		if tonumber(v) > 255 then
			return false
		end
	end
	return true
end

-- Wraps TcpSocket.New(): sets WriteTimeout (default 2s) and exposes the raw
-- socket as .Socket for the caller to wire event handlers (.Connected,
-- .Closed, .Timeout, .Error, .Reconnect) and to pass to code that needs the
-- raw TcpSocket instance itself (e.g. CPSeries:Start(sock.Socket)). The
-- returned instance must stay global, never local -- same GC-safety
-- convention as a bare TcpSocket (see qsys-plugin-development.md's "Q-SYS
-- runtime globals" section): a local one can be collected once nothing else
-- references it, silently killing the connection.
function SocketConn.New(writeTimeout)
	local self = setmetatable({}, SocketConn)
	self.Socket = TcpSocket.New()
	self.Socket.WriteTimeout = writeTimeout or 2
	return self
end

function SocketConn:Connect(address, port)
	self.Socket:Connect(address, port)
end

function SocketConn:Disconnect()
	self.Socket:Disconnect()
end

function SocketConn:IsConnected()
	return self.Socket.IsConnected
end
