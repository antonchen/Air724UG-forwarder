module(..., package.seeall)

-- 消息队列
local msg_queue = {}

--- 将 table 转换成 URL 编码字符串
-- @param params (table) 需要转换的 table
-- @return (string) 转换后的 URL 编码字符串
local function urlencodeTab(params)
    local msg = {}
    for k, v in pairs(params) do
        if type(v) ~= "string" then
            v = tostring(v)
        end
        table.insert(msg, string.urlEncode(k) .. "=" .. string.urlEncode(v))
        table.insert(msg, "&")
    end
    table.remove(msg)
    return table.concat(msg)
end

--- 判断 table 变量是否存在键值对
-- @param tbl (table)
-- @return (boolean)
local function is_kv_table(tbl)
    -- 检查是否有键值对的键和值
    for key, value in pairs(tbl) do
        if type(key) ~= "number" and type(key) ~= "string" then
            return false
        end
        if type(value) == "table" then
            return false
        end
    end
    return true
end

--- key 对照表
local msg_key = {
    localNumber = "本机号码",
    uptime = "开机时长",
    MNO = "运营商",
    signal = "信号",
    band = "频段",
    voltage = "电压",
    temp = "温度",
    smsContent = "内容",
    senderNumber = "发信号码",
    senderTime = "发信时间"
}

--- table 转换成字符串
-- @param tbl (table)
-- @return (string)
local function msg_to_string(tbl)
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end

    -- key 为数字时, 只取值
    local msg = {}
    for key, value in pairs(tbl) do
        if type(key) == "number" then
            table.insert(msg, value)
        else
            if value == "" then
                table.insert(msg, "")
            elseif key == "type" then
                table.insert(msg, "#" .. value)
            else
                table.insert(msg, msg_key[key] .. ": " .. value)
            end
        end
    end
    return table.concat(msg, "\n")
end
--- 通知渠道
local notify = {
    -- 发送到 telegram
    ["telegram"] = function(msg)
        if msg["type"] == "SMS" then
            return
        end
        local str_msg = msg_to_string(msg)
        if config.TELEGRAM_API == nil or config.TELEGRAM_API == "" then
            log.error("util_notify", "未配置 `config.TELEGRAM_API`")
            return
        end
        if config.TELEGRAM_CHAT_ID == nil or config.TELEGRAM_CHAT_ID == "" then
            log.error("util_notify", "未配置 `config.TELEGRAM_CHAT_ID`")
            return
        end

        local header = {
            ["content-type"] = "application/json"
        }
        local body = {
            ["chat_id"] = config.TELEGRAM_CHAT_ID,
            ["disable_web_page_preview"] = true,
            ["text"] = str_msg
        }
        local json_data = json.encode(body)

        log.info("util_notify", "POST", config.TELEGRAM_API)
        return util_http.fetch(nil, "POST", config.TELEGRAM_API, header, json_data)
    end,

    -- 发送到 API
    ["api"] = function(msg)
        if config.API == nil or config.API == "" then
            log.error("util_notify", "未配置 `config.API`")
            return
        end
        if config.TOKEN == nil or config.TOKEN == "" then
            log.error("util_notify", "未配置 `config.TOKEN`")
            return
        end
        if msg["type"] ~= "SMS" then
            return
        end

        local url = config.API
        local header = {
            ["Content-Type"] = "application/json; charset=utf-8",
            ["Authorization"] = "Bearer " .. config.TOKEN
        }

        local json_data = json.encode(msg)

        log.info("util_notify", "POST", config.API)
        return util_http.fetch(nil, "POST", config.API, header, json_data)
    end
}

--- 构建设备信息字符串, 用于追加到通知消息中
-- @param msg (table) 通知消息
-- @return (table) 通知消息+设备信息
local function buildDeviceInfo(msg)
    -- 本机号码
    local number = sim.getNumber()
    if (number and number ~= "") or config.LOCAL_NUMBER then
        if number ~= "" then
            msg["localNumber"] = number
        else
            msg["localNumber"] = tostring(config.LOCAL_NUMBER)
        end
    end

    -- -- IMEI
    -- local imei = misc.getImei()
    -- if imei ~= "" then
    --     msg = msg .. "\nIMEI: " .. imei
    -- end

    -- 开机时长
    -- rtos.tick() 系统启动后的计数个数 单位为5ms 0-5d638865→-5d638865-0
    local ms = rtos.tick() * 5
    local seconds = math.floor(ms / 1000)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    seconds = seconds % 60
    minutes = minutes % 60
    local boot_time = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    if ms >= 0 then msg["uptime"] = boot_time end

    -- 运营商
    local oper = util_mobile.getOper(true)
    if oper ~= "" then
        msg["MNO"] = oper
    end

    -- 信号
    local rsrp = net.getRsrp() - 140
    if rsrp ~= 0 then
        msg["signal"] = rsrp .. "dBm"
    end

    -- 频段
    local band = net.getBand()
    if band ~= "" then
        msg["band"] = "B" .. band
    end

    -- -- 板卡
    -- local board_version = misc.getModelType()
    -- if board_version ~= "" then
    --     msg = msg .. "\n板卡: " .. board_version
    -- end

    -- -- 系统版本
    -- local os_version = misc.getVersion()
    -- if os_version ~= "" then
    --     msg = msg .. "\n系统版本: " .. os_version
    -- end

    -- 电压
    local adcval, voltval = adc.read(5)
    if adcval ~= 0xffff then
        msg["voltage"] = voltval / 1000 .. "v"
    end

    -- 温度
    local temperature = util_temperature.get()
    if temperature ~= "-99" then
        msg["temp"] = temperature .. "℃"
    end

    return msg
end

--- 发送通知
-- @param msg (table) 通知内容
-- @param channel (string) 通知渠道
-- @return (boolean) 是否需要重发
function send(msg, channel)
    log.info("util_notify.send", "发送通知", channel)
    
    -- 判断消息内容 msg
    if type(msg) ~= "table" then
        log.error("util_notify.send", "发送通知失败", "参数类型错误", type(msg))
        return true
    end
    if msg == {} then
        log.error("util_notify.send", "发送通知失败", "消息为空")
        return true
    end

    -- 判断通知渠道 channel
    if channel and notify[channel] == nil then
        log.error("util_notify.send", "发送通知失败", "未知通知渠道", channel)
        return true
    end

    -- 通知内容追加设备信息
    if config.NOTIFY_APPEND_MORE_INFO then
        if is_kv_table(msg) then
            msg = buildDeviceInfo(msg)
        else
            msg = msg .. buildDeviceInfo({})
        end
    end

    -- 发送通知
    local code, headers, body = notify[channel](msg)
    if code == nil or code == -99 then
        log.info("util_notify.send", "跳过发送", "channel: ", channel)
        return nil
    end
    if code >= 200 and code < 500 then
        -- http 2xx 成功
        -- http 3xx 重定向, 重发也不会成功
        -- http 4xx 客户端错误, 重发也不会成功
        log.info("util_notify.send", "发送通知成功", "code:", code, "body:", body)
        return true
    end
    log.error("util_notify.send", "发送通知失败, 等待重发", "code:", code, "body:", body)
    return false
end

--- 添加到消息队列
-- @param msg 消息内容
-- @param channels 通知渠道
function add(msg, channels)
    channels = channels or config.NOTIFY_TYPE

    if type(channels) ~= "table" then
        channels = {channels}
    end

    for _, channel in ipairs(channels) do
        table.insert(msg_queue, {channel = channel, msg = msg, retry = 0})
    end
    sys.publish("NEW_MSG")
    log.info("util_notify.add", "添加到消息队列, 当前队列长度:", #msg_queue)
end

--- 轮询消息队列
--- 发送成功则从消息队列中删除
--- 发送失败则等待下次轮询
local function poll()
    local item, result
    while true do
        -- 消息队列非空, 且网络已注册
        if next(msg_queue) ~= nil and net.getState() == "REGISTERED" then
            log.info("util_notify.poll", "轮询消息队列中, 当前队列长度:", #msg_queue)

            item = msg_queue[1]
            table.remove(msg_queue, 1)

            if item.retry > (config.NOTIFY_RETRY_MAX or 100) then
                log.error("util_notify.poll", "超过最大重发次数", "msg:", item.msg)
            else
                result = send(item.msg, item.channel)
                item.retry = item.retry + 1

                if result then
                    -- 发送成功提示音
                    util_audio.play(3, "FILE", "/lua/audio_http_success.mp3")
                elseif result == false then
                    -- 发送失败, 移到队尾
                    table.insert(msg_queue, item)
                    sys.wait(5000)
                end
            end
            sys.wait(50)
        else
            sys.waitUntil("NEW_MSG", 1000 * 10)
        end
    end
end

sys.taskInit(poll)
