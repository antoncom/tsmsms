--[[ Характеристика модуля smsd

Один раз в 3 секунды модуль проверят содержимое каталога /var/sppon/tsmsms/outgoing
Если есть файлы с текстом смс, то берётся первый файл (самый старый по дате)
и запускается пошаговый процесс отправки.

Шаг 1: Перевести модем в режим PDU
Шаг 2: Указать модему длину смс-сообшения (согласно pdu)
Шаг 3: Отправить смс
Шаг 4: Перевести модем в режим TEXT

Если на каком-то шаге модем вернул ошибку, 
то прервать выполнение остльных шагов и венуть ошибку в Веб-UI (если смс отправлена из веб-консоли)
либо вернуть ошибку по Email (если смс отправлена в ответ на sms-команду).
Записать ошибку в Журнал событий.

Весь процесс (шаги выше и вывод ошибок) продолжается 5 минут.
Если через 5 минут не получилось отправть смс, то перемещаем данный файл
в каталог /var/sppon/tsmsms/failed

Повторяем всё с начала для следующего файла.

]]

local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"

local F = require 'posix.fcntl'
local U = require 'posix.unistd'

--[[ Operate Ctrl-C for normal exiting the program]]
local signal = require("posix.signal")
signal.signal(signal.SIGINT, function(signum)

  io.write("\n")
  print("-----------------------")
  print("Smsd debug stopped.")
  print("-----------------------")
  io.write("\n")
  os.exit(128 + signum)
end)

smsd.status = {
	inprogress = false,
	file = ""				-- путь к файлу, обрабатываемому на данной итерации
}

smsd.body = {
	text = "",				-- текущий текст смс-сообщения
	phone = "",				-- телефон получателя
	pdu_len = 0,
	pdu_text = ""
}


function smsd:init()
	smsd.conn = ubus.connect()
	if not smsd.conn then
		error("Failed to connect to ubus from Smsd")
	end
end


function smsd:make_ubus()
	local ubus_methods = {
		["tsmodem.smsd"] = {
			send_sms = {
				function(req, msg)
					local resp = {
						["send_sms_resp"] = "Empty response",
					}
					if msg["phone_number"] then 
						-- Выполнить АТ-команду для отправки смс
						--util.ubus("tsmodem.driver", "send_at", {"command":"AT+CMGS=+79170660867"})
						resp["send_sms_resp"] = "SMS Send"
					end
					smsd.conn:reply(req, resp);
				end, {phone = ubus.STRING, msg = ubus.STRING }
			},
		}
	}
	smsd.conn:add( ubus_methods )
end


function smsd:start()
	smsd.status.inprogress = true
	local ubus_response = util.ubus("tsmodem.driver", "automation", { ["mode"] = "run" })
end

function smsd:stop()
	smsd.status.inprogress = false
	local ubus_response = util.ubus("tsmodem.driver", "automation", { ["mode"] = "stop" })
end

function smsd:goPDU()
	local ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=0" })
end

function smsd:goTEXT()
		local ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = "AT+CMGF=1" })
end

function smsd:prepareFile(phone, text)
	local pdu_len = 0
	local pdu_text = ""

	local filename, fpath = "", ""
    local parts = smsd:split_message(text, 70)

	for n, part in ipairs(parts) do
	    pdu_len, pdu_text = EncoderPDU(phone, part)

		filename = string.format("%s_sms_%s-part_[%s]", tostring(os.time()), tostring(n), tostring(pdu_len))

		fpath = smsd.outoging .. "/" .. filename

	    local file = io.open(fpath, "w")
		file:write(pdu_text)
		file:close()
	end

	return string.format("SMS text prepared, splitted to %s parts.", tostring(#parts))
end

function smsd:setPduLength()
	local ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = string.format("AT+CMGF=%s", tostring(smsd.pdu_len)) })
end

function smsd:sendPduText(pdu)
	local ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = string.format("AT+CMGS=%s\26", tostring(pdu)) })
end

function smsd:findNext()
  local pdu_len
  local filename
  local ok, files = pcall(M.dir, "/root/smsf")
  if not ok then
    print("smsd.outgoing: " .. files)
  elseif #files > 0 then
    for _, fname in ipairs(files) do
      if not fname:find("[%.]+") then
        filename = fname
        break
      end
    end
    local spos = filename:find("%d+",20)
    pdu_len = filename:sub(spos,-2)
  end
  return filename, pdu_len
end


-- Загружаем текст смс из очередного файла
-- Сплитим текст на куски, сохраняем в таблицы для дальнейших действий
function smsd:load()

end

-- Разбивает длинный текст на куски, для отправки по смс
function smsd:split_message(text, max_length)
  local chunks = {}
  local start = 1
  local chunk_size = max_length

  while start <= #text do
    chunks[#chunks + 1] = string.sub(text, start, start + chunk_size - 1)
    start = start + chunk_size
  end

  return chunks
end




-- [[ Initialize ]]
local metatable = {
	__call = function(smsd, timer)
    smsd.timer = timer

    smsd.init(timer)
    smsd.timer.init(smsd)

    smsd:make_ubus()

		uloop.init()

		-- Запускаем периодический опрос на проверку
		-- появился ли новый файл с текстом для отправки по SMS

    timer.general:set(timer.steps["0_GENERAL"])


		uloop.run()


		smsd.conn:close()

		return table
	end
}
setmetatable(smsd, metatable)

return smsd