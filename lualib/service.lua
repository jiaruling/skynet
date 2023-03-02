local skynet = require "skynet"
local cluster = require "skynet.cluster"

local M = {
    -- 类型和id
    name = "",
    id = 0,
    -- 回调函数
    exit = nil,
    init = nil,
    -- 分发函数
    resp = {},
}

local traceback = function(err)
    skynet.error(tostring(err))
    skynet.error(debug.traceback())
end

local dispatch = function(session, address, cmd, ...)
    local fun = M.resp[cmd]
    if not fun then
        skynet.ret() -- 返回
        return
    end
    -- table.pack 打包
    local ret = table.pack(xpcall(fun, traceback, address, ...))
    local isok = ret[1]

    if not isok then
        skynet.ret() -- 返回
        return
    end

    -- skynet.retpack 打包返回 table.unpack 解包从第二个参数开始
    skynet.retpack(table.unpack(ret, 2))
end

local init = function()
    skynet.dispatch("lua", dispatch)
    if M.init then
        M.init()
    end
end

function M.start(name, id, ...)
    M.name = name
    M.id = tonumber(id)
    skynet.start(init)
end

function M.call(node, srv, ...)
    local mynode = skynet.getenv("node")
    if node == mynode then
        return skynet.call(srv, "lua", ...)
    else
        return cluster.call(node, srv, ...)
    end
end

function M.send(node, srv, ...)
    local mynode = skynet.getenv("node")
    if node == mynode then
        return skynet.send(srv, "lua", ...)
    else
        return cluster.send(node, srv, ...)
    end
end

return M
