-- 写Echo，联系网络编程

local skynet = require "skynet"
local socket = require "skynet.socket"

skynet.start(function()
    local listenfd = socket.listen("0.0.0.0", 8888)
    socket.start(listenfd, connect)
end)

function connect(fd, addr)
    -- 启用链接
    socket.start(fd)
    print(fd.. " connected addr: " ..addr)
    -- 消息处理
    while true do
        local readdata = socket.read(fd)
        -- 正常接收
        if readdata ~= nil then
            print(fd.. " recv " ..readdata)
            socket.write(fd, readdata)
        -- 断开连接
        else
            print(fd.. " close")
            socket.close(fd)
        end
    end
end