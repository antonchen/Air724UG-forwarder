------------------------------------------------- Config --------------------------------------------------

-- 音量配置
audio.setCallVolume(7)
audio.setMicVolume(15)

------------------------------------------------- 初始化及状态记录 --------------------------------------------------

CALL_IN = false
CALL_NUMBER = ""

local CALL_CONNECTED_TIME = 0
local CALL_DISCONNECTED_TIME = 0

------------------------------------------------- TTS 相关 --------------------------------------------------

-- TTS 播放结束回调
local function ttsCallback(result)
    log.info("handler_call.ttsCallback", "result:", result)

    -- 判断来电动作是否为接听后挂断
    if nvm.get("CALL_IN_ACTION") == 1 then
        log.info("handler_call.callIncomingCallback", "来电动作", "接听后挂断")
        cc.hangUp(CALL_NUMBER)
    end
end

-- 播放 TTS，播放结束后开始录音
local function tts()
    log.info("handler_call.tts", "TTS 播放开始")

    if config.TTS_TEXT and config.TTS_TEXT ~= "" then
        -- 播放 TTS
        audio.setTTSSpeed(60)
        audio.play(7, "TTS", config.TTS_TEXT, 7, ttsCallback)
    else
        -- 播放音频文件
        if nvm.get("CALL_IN_ACTION") == 1 then
            util_audio.audioStream("/lua/audio_pickup_hangup.amr", ttsCallback)
        end
    end
end

------------------------------------------------- 电话回调函数 --------------------------------------------------

-- 电话拨入回调
-- 设备主叫时, 不会触发此回调
local function callIncomingCallback(num)
    -- 来电号码
    CALL_NUMBER = num or "unknown"

    -- 来电动作, 挂断
    if nvm.get("CALL_IN_ACTION") == 2 then
        log.info("handler_call.callIncomingCallback", "来电动作", "挂断")
        cc.hangUp(num)
        -- 发通知
        util_notify.add({"来电号码: " .. num, "来电动作: 挂断", "", "#CALL #CALL_IN"})
        return
    end

    -- CALL_IN 从电话接入到挂断都是 true, 用于判断是否为来电中, 本函数会被多次触发
    if CALL_IN then
        return
    end

    -- 来电动作, 无操作 or 接听
    if nvm.get("CALL_IN_ACTION") == 0 then
        log.info("handler_call.callIncomingCallback", "来电动作", "无操作")
    else
        log.info("handler_call.callIncomingCallback", "来电动作", "接听")
        -- 接听电话
        sys.timerStart(
            function()
                -- 标记接听来电中
                CALL_IN = true
                -- 接听电话
                cc.accept(num)
            end,
            1000 * 2
        )
    end
    
    -- 发送除了 来电动作为挂断 之外的通知
    -- 0：无操作，1：接听后挂断，2：挂断
    local action_desc = {[0] = "无操作", [1] = "接听后挂断", [2] = "挂断"}
    util_notify.add({"来电号码: " .. num, "来电动作: " .. action_desc[nvm.get("CALL_IN_ACTION")], "", "#CALL #CALL_IN"})
end

-- 电话接通回调
local function callConnectedCallback(num)
    -- 再次标记接听来电中, 防止设备主叫时, 不触发 `CALL_INCOMING` 回调, 导致 CALL_IN 为 false
    CALL_IN = true
    -- 接通时间
    CALL_CONNECTED_TIME = rtos.tick() * 5
    -- 来电号码
    CALL_NUMBER = num or "unknown"

    CALL_DISCONNECTED_TIME = 0

    log.info("handler_call.callConnectedCallback", num)

    -- 停止之前的播放
    audio.stop()
    -- 向对方播放留言提醒 TTS
    sys.timerStart(tts, 1000 * 1)

    -- 定时结束通话
    sys.timerStart(cc.hangUp, 1000 * 60 * 2, num)
end

-- 电话挂断回调
-- 设备主叫时, 被叫方主动挂断电话或者未接, 也会触发此回调
local function callDisconnectedCallback(discReason)
    -- 标记来电结束
    CALL_IN = false
    -- 通话结束时间
    CALL_DISCONNECTED_TIME = rtos.tick() * 5
    -- 清除所有挂断通话定时器, 防止多次触发挂断回调
    sys.timerStopAll(cc.hangUp)

    log.info("handler_call.callDisconnectedCallback", "挂断原因:", discReason)

    -- TTS 结束
    -- tts(util_audio.audioStream播放的音频文件) 播放中通话被挂断，然后在 callDisconnectedCallback 中调用 audio.stop()
    -- 调用 audiocore.stop() 可以解决这个问题
    audio.stop(function(result)
        log.info("handler_call.callDisconnectedCallback", "audio.stop() callback result:", result)
    end)
    audiocore.stop()


    -- 切换音频输出为 2:喇叭, 音频输入为 0:主mic
    audio.setChannel(2, 0)
end

-- 注册电话回调
sys.subscribe("CALL_INCOMING", callIncomingCallback)
sys.subscribe("CALL_CONNECTED", callConnectedCallback)
sys.subscribe("CALL_DISCONNECTED", callDisconnectedCallback)

ril.regUrc(
    "RING",
    function()
        -- 来电铃声
        local vol = nvm.get("AUDIO_VOLUME") or 0
        if vol == 0 then
            return
        end
        audio.play(4, "FILE", "/lua/audio_ring.mp3", vol)
    end
)
