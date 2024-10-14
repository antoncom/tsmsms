local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local uloop = require "uloop"
local nixio = require "nixio"
local D = require 'posix.dirent'

require "tsmsms.util"



local timer = {}
timer.general = nil

--[[ Step-by-step of sending SMS ]]
timer.steps = {
    ["0_GENERAL"] = 3000,
    ["1_GO_PDU"] = 1000,
    ["2_SET_LENGTH"] = 2000,
    ["3_SEND"] = 1000,
    ["4_GO_TEXT"] = 500,
}

function timer:init(app, file, sms)
    timer.app = app
    timer.file = file
    timer.sms = sms
    return timer
end

--
--
-- Проверяем есть ли что-нибудь отправить по SMS
function t_SMSD_STATUS()
    -- Проверять наличие файлов в ./outoging
    local ready, filename, len = timer.file:findNext()
    if ready then
        timer.GO_PDU_1:set(timer.steps["1_GO_PDU"])
        if_debug("New SMS text found, len: " .. len, filename)
    else
        timer.general:set(timer.steps["0_GENERAL"])
        if_debug("0_GENERAL: 3000", "Check new SMS to send")
    end
end
timer.general = uloop.timer(t_SMSD_STATUS)

--
--
-- Переводим модем в режим PDU
function t_GO_PDU_1()
    timer.sms:goPDU()

    -- Delayed next step
    timer.SET_LENGTH_2:set(timer.steps["2_SET_LENGTH"])
end
timer.GO_PDU_1 = uloop.timer(t_GO_PDU_1)

--
--
-- Указываем модему длину PDU текста
function t_SET_LENGTH_2()
    timer.sms:setPduLength()

    -- Delayed next step
    timer.SEND_3:set(timer.steps["3_SEND"])
end
timer.SET_LENGTH_2 = uloop.timer(t_SET_LENGTH_2)

--
--
-- Отпрапвляем модему сам текст в PDU-формате
function t_SEND_3()
    timer.sms:sendPduText()

    -- Delayed next step
    timer.GO_TEXT_4:set(timer.steps["4_GO_TEXT"])
end
timer.SEND_3 = uloop.timer(t_SEND_3)

--
--
-- Переводим модем обратно в режим TEXT
function t_GO_TEXT_4()
    timer.sms:goTEXT()
    timer.file.moveToSent()

    -- Repeate new SMS-file checking
    timer.general:set(timer.steps["0_GENERAL"])
end
timer.GO_TEXT_4 = uloop.timer(t_GO_TEXT_4)


return timer
