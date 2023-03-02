local skynet = require "skynet"
local s = require "service"

s.client = {}

s.client.login = function (fd, msg, source)
    skynet.error("login recv "..msg[1].. " " ..msg[2])
    local playerid = tonumber(msg[2])
    local pw = tonumber(msg[3])
    local gate = source
    local node = skynet.getenv("node")
    -- 检验用户名密码
    if pw ~= 123 then
        return {"login", 1, "密码错误"}
    end
    -- 发给 agentmgr
    local isok, agent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gate)
    if not isok then
        return {"login", 1, "请求mgr失败"}
    end
    -- 回应 gate
    isok = skynet.call(gate, "lua", "sure_agent", fd, playerid, agent)
    if not isok then
        return {"login", 1, "gate注册失败"}
    end
    skynet.error("login success "..playerid)
    return {"login", 0, "登录成功"}
end


s.resp.client = function(source, fd, cmd, msg)
    if s.client[cmd] then
        local res_msg = s.client[cmd](fd, msg, source)
        skynet.send(source, "lua", "send_by_fd", fd, res_msg)
    else
        skynet.error("s.resp.client fail", cmd)
    end
end

function s.init()
    skynet.error("[start] " ..s.name.. " "..s.id)
end

s.start(...)