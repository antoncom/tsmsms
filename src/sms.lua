
local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"

local F = require 'posix.fcntl'
local U = require 'posix.unistd'

require "tsmsms.util"


sms = {}
sms.status = {
	inprogress = false,
	file = ""				-- путь к файлу, обрабатываемому на данной итерации
}

sms.body = {
	text = "",				-- текущий текст смс-сообщения
	phone = "",				-- телефон получателя
	pdu_len = 0,
	pdu_text = ""
}


function sms:init(app, file, timer)
    sms.app = app
    sms.file = file
    sms.timer = timer
    return sms
end


function sms:goPDU()
	local ubus_response = util.ubus("tsmodem.driver", "automation", {})
	if_debug("[sms.lua] goPDU()", "AT+CMGF=0", string.format("Automation mode: [%s]", tostring(ubus_response["mode"])))
	local ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=0" })
end

function sms:goTEXT()
		if_debug("[sms.lua] goTEXT()", "AT+CMGF=1")
		local ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=1" })
end

function sms:setPduLength()
	local pdu_len = sms.file.pdu_len
	local ubus_response = util.ubus("tsmodem.driver", "automation", {})
	if_debug("[sms.lua] setPduLength()", pdu_len, string.format("Automation mode: [%s]", tostring(ubus_response["mode"])))
	util.ubus("tsmodem.driver", "send_at", { ["command"] = string.format("AT+CMGS=%s", pdu_len) })
end

function sms:sendPduText(pdu)
	local pdu_text = sms.file.pdu_text
	local ubus_response = util.ubus("tsmodem.driver", "automation", {})
	if_debug("[sms.lua] sendPduText()", pdu_text, string.format("Automation mode: [%s]", tostring(ubus_response["mode"])))
	util.ubus("tsmodem.driver", "send_at", { ["command"] = string.format("%s\26", pdu_text) })
end



return sms