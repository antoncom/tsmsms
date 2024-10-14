local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"

local F = require 'posix.fcntl'
local U = require 'posix.unistd'


file = {}
file.outgoing = "/var/spool/tsmsms/outgoing"
file.sent = "/var/spool/tsmsms/sent"
file.failed = "/var/spool/tsmsms/failed"
file.pdu_text = {} -- array of smpitted sms text
file.pdu_len = {} -- array of lengths of every splitted part of sms text
file.ok_num, ok_sms, pdu_sms_text = true,true,""


function file:findNext()
  local pdu_len
  local filename
  local ok, files = pcall(M.dir, "/root/smsf")
  if not ok then
    print("file.outgoing: " .. files)
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


function file:moveToSent()

end

function file:moveToFailed(file)

	return file
end

function file:removeSent(file)

	return file
end