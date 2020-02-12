RSystemServer = LibStub("AceAddon-3.0"):NewAddon("RSystemServer", "AceConsole-3.0","AceEvent-3.0")

local receiveRequestList = {}

function RSystemServer:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RSystemServerDB")
    -- Called when the addon is enabled
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    if (self.db.profile.receiveRequestList) then
        receiveRequestList = self.db.profile.receiveRequestList
    end
end

function RSystemServer:OnEnable()
end

function RSystemServer:PLAYER_ENTERING_WORLD()
    RegisterAddonMessagePrefix("RSystemServer")
end

function RSystemServer:CHAT_MSG_ADDON(_ ,channel, message,_,sender)
    --print("channel:",_ ,channel, message)
    if (channel=="RSystemServer") then
        local tab = { strsplit( "_", message) }
        print("接受到来自"..tab[2].."的"..tab[1].."请求")
        if (tab[1] == "PostRequest") then
            --接受发布请求
            RSystemServer:getPostRequest(tab[2],tab[3],tab[4])
        elseif (tab[1] == "GetRequestList") then
            -- 回复任务列表
            RSystemServer:sendRequestList(tab[2])
        elseif (tab[1] == "DropRequest") then
            -- 撤销任务
            RSystemServer:getDropRequest(tab[3],sender)
        elseif (tab[1] == "PullRequest") then
            -- 撤销任务
            RSystemServer:getPullRequest(tab[3])
        end

    end
end

function RSystemServer:getPostRequest(sendUser,name,money)
    -- 数据处理并入库
    print("求购人："..sendUser,"求购物品："..name,"求购价格："..money)
    local requestData = {}
    local itemName, itemLink = GetItemInfo(name);
    if (itemName and itemLink) then
        local itemID = itemLink:match("item:(%d+)")
        local addTime = RSystemServer:getCurTime()
        local requestId = time()..random(1000,9999);
        requestData["itemId"] = itemID
        requestData["requestId"] = requestId
        requestData["userName"] = sendUser
        requestData["addTime"] = addTime
        requestData["money"] = money
        table.insert(receiveRequestList,requestData)
        self.db.profile.receiveRequestList = receiveRequestList
    end
end

function RSystemServer:getDropRequest(requestId,sender)
    for i,request in pairs(receiveRequestList) do
        if(request["requestId"] == requestId and request["userName"] == sender) then
            table.remove(receiveRequestList,i)
        end
    end
    self.db.profile.receiveRequestList = receiveRequestList
end

function RSystemServer:getPullRequest(requestId)
    for i,request in pairs(receiveRequestList) do
        if(request["requestId"] == requestId) then
            table.remove(receiveRequestList,i)
        end
    end
    self.db.profile.receiveRequestList = receiveRequestList
end

function RSystemServer:sendRequestList(receiver)
    print("接受到来自"..receiver.."的获取列表请求")
    for i,request in pairs(receiveRequestList) do
        local requestStr= table2json(request)
        print(i,requestStr)
        SendAddonMessage("RSystemClient", "GetRequestList_"..i.."_"..requestStr, "WHISPER", receiver);
    end
    SendAddonMessage("RSystemClient", "GetRequestListDone_done", "WHISPER", receiver);
end

function RSystemServer:getCurTime()
    local timeText=""
    local _, month, day, year = CalendarGetDate()
    if month<10 then month="0"..month end
    if day<10 then day="0"..day end
    --if year>2000 then year=year-2000 end
    local h,m = GetGameTime()
    if h<10 then h="0"..h end
    if m<10 then m="0"..m end
    local timeText=year.."-"..month.."-"..day.." "..h..":"..m
    return timeText
end

--------------
--json解析

local function json2true(str, from, to)
    return true, from + 3
end

local function json2false(str, from, to)
    return false, from + 4
end

local function json2null(str, from, to)
    return nil, from + 3
end

local function json2nan(str, from, to)
    return nul, from + 2
end

local numberchars = {
    ['-'] = true,
    ['+'] = true,
    ['.'] = true,
    ['0'] = true,
    ['1'] = true,
    ['2'] = true,
    ['3'] = true,
    ['4'] = true,
    ['5'] = true,
    ['6'] = true,
    ['7'] = true,
    ['8'] = true,
    ['9'] = true,
}

local function json2number(str, from, to)
    local i = from + 1
    while (i <= to) do
        local char = string.sub(str, i, i)
        if not numberchars[char] then
            break
        end
        i = i + 1
    end
    local num = tonumber(string.sub(str, from, i - 1))
    if not num then
        Log("red", 'json格式错误，不正确的数字, 错误位置:', from)
    end
    return num, i - 1
end

local function json2string(str, from, to)
    local ignor = false
    for i = from + 1, to do
        local char = string.sub(str, i, i)
        if not ignor then
            if char == '\"' then
                return string.sub(str, from + 1, i - 1), i
            elseif char == '\\' then
                ignor = true
            end
        else
            ignor = false
        end
    end
    Log("red", 'json格式错误，字符串没有找到结尾, 错误位置:{from}', from)
end

local function json2array(str, from, to)
    local result = {}
    from = from or 1
    local pos = from + 1
    local to = to or string.len(str)
    while (pos <= to) do
        local char = string.sub(str, pos, pos)
        if char == '\"' then
            result[#result + 1], pos = json2string(str, pos, to)
            --[[    elseif char == ' ' then

            elseif char == ':' then

            elseif char == ',' then]]
        elseif char == '[' then
            result[#result + 1], pos = json2array(str, pos, to)
        elseif char == '{' then
            result[#result + 1], pos = json2table(str, pos, to)
        elseif char == ']' then
            return result, pos
        elseif (char == 'f' or char == 'F') then
            result[#result + 1], pos = json2false(str, pos, to)
        elseif (char == 't' or char == 'T') then
            result[#result + 1], pos = json2true(str, pos, to)
        elseif (char == 'n') then
            result[#result + 1], pos = json2null(str, pos, to)
        elseif (char == 'N') then
            result[#result + 1], pos = json2nan(str, pos, to)
        elseif numberchars[char] then
            result[#result + 1], pos = json2number(str, pos, to)
        end
        pos = pos + 1
    end
    Log("red", 'json格式错误，表没有找到结尾, 错误位置:{from}', from)
end

local function string2json(key, value)
    return string.format("\"%s\":\"%s\",", key, value)
end

local function number2json(key, value)
    return string.format("\"%s\":%s,", key, value)
end

local function boolean2json(key, value)
    value = value == nil and false or value
    return string.format("\"%s\":%s,", key, tostring(value))
end

local function array2json(key, value)
    local str = "["
    for k, v in pairs(value) do
        str = str .. table2json(v) .. ","
    end
    str = string.sub(str, 1, string.len(str) - 1) .. "]"
    return string.format("\"%s\":%s,", key, str)
end

local function isArrayTable(t)

    if type(t) ~= "table" then
        return false
    end

    local n = #t
    for i, v in pairs(t) do
        if type(i) ~= "number" then
            return false
        end

        if i > n then
            return false
        end
    end

    return true
end

local function tab2json(key, value)
    if isArrayTable(value) then
        return array2json(key, value)
    end
    local tableStr = table2json(value)
    return string.format("\"%s\":%s,", key, tableStr)
end



function json2table(str, from, to)
    local result = {}
    from = from or 1
    local pos = from + 1
    local to = to or string.len(str)
    local key
    while (pos <= to) do
        local char = string.sub(str, pos, pos)
        --Log("yellow", pos, "-->", char)
        if char == '\"' then
            if not key then
                key, pos = json2string(str, pos, to)
            else
                result[key], pos = json2string(str, pos, to)
                key = nil
            end
            --[[    elseif char == ' ' then

            elseif char == ':' then

            elseif char == ',' then]]
        elseif char == '[' then
            if not key then
                key, pos = json2array(str, pos, to)
            else
                result[key], pos = json2array(str, pos, to)
                key = nil
            end
        elseif char == '{' then
            if not key then
                key, pos = json2table(str, pos, to)
            else
                result[key], pos = json2table(str, pos, to)
                key = nil
            end
        elseif char == '}' then
            return result, pos
        elseif (char == 'f' or char == 'F') then
            result[key], pos = json2false(str, pos, to)
            key = nil
        elseif (char == 't' or char == 'T') then
            result[key], pos = json2true(str, pos, to)
            key = nil
        elseif (char == 'n') then
            result[key], pos = json2null(str, pos, to)
            key = nil
        elseif (char == 'N') then
            result[key], pos = json2nan(str, pos, to)
            key = nil
        elseif numberchars[char] then
            if not key then
                key, pos = json2number(str, pos, to)
            else
                result[key], pos = json2number(str, pos, to)
                key = nil
            end
        end
        pos = pos + 1
    end
    Log("red", 'json格式错误，表没有找到结尾, 错误位置:{from}', from)
end

--json格式中表示字符串不能使用单引号
local jsonfuncs = {
    ['\"'] = json2string,
    ['['] = json2array,
    ['{'] = json2table,
    ['f'] = json2false,
    ['F'] = json2false,
    ['t'] = json2true,
    ['T'] = json2true,
}

function json2lua(str)
    local char = string.sub(str, 1, 1)
    local func = jsonfuncs[char]
    if func then
        return func(str, 1, string.len(str))
    end
    if numberchars[char] then
        return json2number(str, 1, string.len(str))
    end
end

function table2json(tab)
    local str = "{"
    for k, v in pairs(tab) do
        if type(v) == "string" then
            str = str .. string2json(k, v)
        elseif type(v) == "number" then
            str = str .. number2json(k, v)
        elseif type(v) == "boolean" then
            str = str .. boolean2json(k, v)
        elseif type(v) == "table" then
            str = str .. tab2json(k, v)
        end
    end
    str = string.sub(str, 1, string.len(str) - 1)
    return str .. "}"
end