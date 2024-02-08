module(...)

-------------------------------------------------- 通知相关配置 --------------------------------------------------

-- 通知类型, 支持配置多个
-- NOTIFY_TYPE = {"api", "telegram"}
NOTIFY_TYPE = {"api", "telegram"}

API = "https://api.example.com/sms"
TOKEN = "kkkkkkkkkkkkkkk"

-- telegram 通知配置
TELEGRAM_API = "https://api.telegram.org/bot<Token>/sendMessage"
TELEGRAM_CHAT_ID = "111111"

-- 定时查询流量间隔, 单位毫秒, 设置为 0 关闭 (建议检查 util_mobile.lua 文件中运营商号码和查询流量代码是否正确, 以免发错短信导致扣费, 收到查询结果短信发送通知会消耗流量)
QUERY_TRAFFIC_INTERVAL = 0

-- 开机通知 (会消耗流量)
BOOT_NOTIFY = true

-- 通知内容追加更多信息 (通知内容增加会导致流量消耗增加)
NOTIFY_APPEND_MORE_INFO = true

-- 通知最大重发次数
NOTIFY_RETRY_MAX = 20

-------------------------------------------------- 短信来电配置 --------------------------------------------------
LOCAL_NUMBER = 13813813813

-- 允许发短信控制设备的号码, 如果注释掉或者为空, 则允许所有号码
-- SMS_CONTROL_WHITELIST_NUMBERS = {"18xxxxxxx", "18xxxxxxx", "18xxxxxxx", "18xxxxxxx"},
SMS_CONTROL_WHITELIST_NUMBERS = {"13813813813"}

-- 电话接通后 TTS 语音内容, 在播放完后开始录音, 如果注释掉或者为空则播放 audio_pickup_hangup.amr 文件
-- TTS_TEXT = "您好，此号不接电话，请通过其它方式联系。"

-- 来电动作, 0：无操作，1：接听后挂断，2：挂断
CALL_IN_ACTION = 1

-------------------------------------------------- 其他配置 --------------------------------------------------

-- 扬声器音量, 0-7
AUDIO_VOLUME = 1

-- 开启 RNDIS 网卡
RNDIS_ENABLE = false
