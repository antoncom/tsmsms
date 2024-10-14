-- Преобразвание номера абонента
function PhoneNumberToPDU(PhoneNumber)
  local TempStr = PhoneNumber
  if string.sub(TempStr, 1, 1) == '+' then
    TempStr = string.sub(TempStr, 2)
  end
  local Result = ''
  if #TempStr % 2 == 1 then
    TempStr = TempStr .. 'F'
  end
  for I = 1, #TempStr do
    if I % 2 == 1 then
      Result = Result .. string.sub(TempStr, I + 1, I + 1) .. string.sub(TempStr, I, I)
    end
  end
  print("PhoneNumberToPDU: " .. tostring(Result))
  return Result
end

-- Перекодирование текста
function UTF8Codes(str)
  local codePoints = {}
  local i = 1
  while i <= #str do
    local char = string.byte(str, i)
    if char <= 127 then -- ASCII
      table.insert(codePoints, char)
      i = i + 1
    elseif char >= 192 and char <= 223 then -- 2 байта
      table.insert(codePoints, ((char - 192) * 64) + (string.byte(str, i + 1) - 128))
      i = i + 2
    elseif char >= 224 and char <= 239 then -- 3 байта
      table.insert(codePoints, ((char - 224) * 4096) + ((string.byte(str, i + 1) - 128) * 64) + (string.byte(str, i + 2) - 128))
      i = i + 3
    elseif char >= 240 and char <= 247 then -- 4 байта
      table.insert(codePoints, ((char - 240) * 262144) + ((string.byte(str, i + 1) - 128) * 4096) + ((string.byte(str, i + 2) - 128) * 64) + (string.byte(str, i + 3) - 128))
      i = i + 4
    elseif char >= 248 and char <= 251 then -- 5 байт
      table.insert(codePoints, ((char - 248) * 16777216) + ((string.byte(str, i + 1) - 128) * 262144) + ((string.byte(str, i + 2) - 128) * 4096) + ((string.byte(str, i + 3) - 128) * 64) + (string.byte(str, i + 4) - 128))
      i = i + 5
    elseif char >= 252 and char <= 253 then -- 6 байт
      table.insert(codePoints, ((char - 252) * 1073741824) + ((string.byte(str, i + 1) - 128) * 16777216) + ((string.byte(str, i + 2) - 128) * 262144) + ((string.byte(str, i + 3) - 128) * 4096) + ((string.byte(str, i + 4) - 128) * 64) + (string.byte(str, i + 5) - 128))
      i = i + 6
    elseif char >= 254 and char <= 255 then -- 7 байт (редкое)
      table.insert(codePoints, ((char - 254) * 68719476736) + ((string.byte(str, i + 1) - 128) * 1073741824) + ((string.byte(str, i + 2) - 128) * 16777216) + ((string.byte(str, i + 3) - 128) * 262144) + ((string.byte(str, i + 4) - 128) * 4096) + ((string.byte(str, i + 5) - 128) * 64) + (string.byte(str, i + 6) - 128))
      i = i + 7
    else
      error("Неподдерживаемый символ: " .. string.char(char))
    end
  end
  -- Преобразоваие из таблицы в сроку в HEX формате
  local result = {}
  for _, codePoint in ipairs(codePoints) do
    table.insert(result, string.format("%04X", codePoint))
  end
  return table.concat(result, "")
end

-- Определение длинны тела смс сообщения
function LengthUtf8Mess(message_in_utf8_code)
  local Result = string.format("%02X", #message_in_utf8_code / 2) -- '0D' - 2 элемента в строке
  print("LengthUtf8Mess: " .. tostring(Result))
  return Result
end

-- Определение длинны pdu данных
function LengthPduMess(pdu)
    local length = #pdu -- Получаем длину строки в байтах
    return tostring(math.floor(length / 2) - 1) -- Делим на 2, отнимаем 1 и преобразуем в строку
end

function EncoderPDU(recipient_number, sms_text)
  local pdu_head = "0011000C91"
  local pdu_middle = "00080B"
  local pdu_send_mess = pdu_head .. PhoneNumberToPDU(recipient_number) .. pdu_middle .. 
    LengthUtf8Mess(UTF8Codes(sms_text)) .. UTF8Codes(sms_text)
  local cmgs_len = LengthPduMess(pdu_send_mess)
  return cmgs_len, pdu_send_mess
end

return EncoderPDU
  
-- Тесты
--local num = "+79170660867"
--local sms = "абв"
--local len, pdu_send_mess = PduEncoder(num, sms)
--print(pdu_send_mess)
--print("Len PDU " .. len)