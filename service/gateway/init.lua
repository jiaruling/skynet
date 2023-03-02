local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local socket = require "skynet.socket"

local conns = {} -- [fd] = conn
local players = {} -- [playerid] = gateplayer

-- 连接类
local conn = function ()
    local m = {
        fd = nil,
        playerid = nil,
    }
    return m
end

-- 玩家类
local gateplayer = function ()
    local m = {
        playerid = nil,
        agent = nil,
        conn = nil,
    }
    return m
end


-- 协议解码
local str_unpack = function (msgstr)
    local msg = {}
    while true do
        local arg, rest = string.match(msgstr, "(.-),(.*)")
        if arg then
            msgstr = rest
            table.insert(msg, arg)
        else
            table.insert(msg, msgstr)
            break
        end
    end
    return msg[1], msg
end

-- 协议编码
local str_pack = function (cmd, msg)
    return table.concat(msg,",").."\r\n"
end

local process_msg = function(fd, msgstr)
    local cmd, msg = str_unpack(msgstr)
    skynet.error("recv "..fd.." ["..cmd.."] {"..table.concat(msg,",").."}")
    local conn = conns[fd]
    local playeid = conn.playerid
    -- 尚未完成登录流程
    if not playeid then
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1, #nodecfg.login)
        local login = "login"..loginid
        skynet.send(login, "lua", "client", fd, cmd, msg)
    -- 完成登录流程
    else
        local gplayer = players[playeid]
        local agent = gplayer.agent
        if cmd == "kick" then
            skynet.send(agent, "lua", cmd)
        elseif cmd == "exit" then
            skynet.send("agentmgr", "lua", "reqkick", playeid, "主动退出")
        else
            skynet.send(agent, "lua", "client", cmd, msg)
        end
    end
end


local process_buff = function(fd, readbuffer)
    while true do
        local msgstr, rest = string.match(readbuffer, "(.-)\r\n(.*)")
        if msgstr then
            readbuffer = rest
            process_msg(fd, msgstr)
        else
            return readbuffer
        end
    end
end

-- 客户端掉线
local disconnect = function (fd)
    local c = conns[fd]
    if not c then
        return
    end

    local playerid = c.playerid
    -- 还没有完成登录
    if not playerid then
        return
    -- 已在游戏中
    else
        players[playerid] = nil
        local reason = " 断线 "
        skynet.call("agentmgr", "lua", "reqkick", playerid, reason)
    end
end

-- 每一条连接接收数据处理
-- 协议格式 cmd,arg1,arg2,...\r\n
local recv_loop = function(fd)
    socket.start(fd)
    skynet.error("socket connected " ..fd)
    local readbuff = ""
    while true do
        local recvstr = socket.read(fd)
        if recvstr then
            readbuff = readbuff..recvstr
            readbuff = process_buff(fd, readbuff)
        else
            skynet.error("socket close" ..fd)
            disconnect(fd)
            socket.close(fd)
            return
        end
    end
end

-- 有新连接时
local connect = function (fd, addr) --fd客户端连接的标识，addr客户端连接的地址
    print("connect from " ..addr.. " " ..fd)
    local c = conn()
    conns[fd] = c
    c.fd = fd
    -- 开启协程,专门接收该连接的数据
    skynet.fork(recv_loop, fd)
end

function s.init()
    skynet.error("[start] " ..s.name.. " "..s.id)
    local node = skynet.getenv("node")
    local nodecfg = runconfig[node]
    local port = nodecfg.gateway[s.id].port

    local listenfd = socket.listen("0.0.0.0", port)
    skynet.error("Listen socket:", "0.0.0.0", port)
    socket.start(listenfd, connect)
end

-- login 服务的消息转发
s.resp.send_by_fd = function (source, fd, msg)
    if not conns[fd] then
        return
    end
    local buff = str_pack(msg[1], msg)
    skynet.error("send "..fd.." [" ..msg[1].. "] {"..table.concat(msg, ",").."}")
    socket.write(fd, buff)
end

-- agent 服务消息转发
s.resp.send = function (source, playerid, msg)
    local gplayer = players[playerid]
    if gplayer == nil then
        return
    end
    local c = gplayer.conn
    if c == nil then
        return
    end

    s.resp.send_by_fd(nil, c.fd, msg)
end

-- 登录确认接口
s.resp.sure_agent = function (source, fd, playerid, agent)
    local conn = conns[fd]
    if not conn then -- 登录过程中已下线
        skynet.call("agentmgr", "lua", "reqkick", playerid, "未完成登录即下线")
        return false
    end

    conn.playerid = playerid

    local gplayer = gateplayer()
    gplayer.playerid = playerid
    gplayer.agent = agent
    gplayer.conn = conn
    players[playerid] = gplayer

    return true
end

s.resp.kick = function (source, playerid)
    local gplayer = players[playerid]
    if not gplayer then
        return
    end

    local c = gplayer.conn
    players[playerid] = nil
    if not c then
        return
    end
    conns[c.fd] = nil
    -- disconnect(c.fd)
    socket.close(c.fd)
end

s.start(...)
