--[[-----------------------------------------------------------------------------
--Import LibStub
-------------------------------------------------------------------------------]]
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
--if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
--local select, pairs, print = select, pairs, print

-- WoW APIs
--local CreateFrame, UIParent, GetBuildInfo = CreateFrame, UIParent, GetBuildInfo
--[[-----------------------------------------------------------------------------
config data
-------------------------------------------------------------------------------]]
local adminUserName = "一号"
local adminQQ = "562746248"
local serviceCharge = 50000
local clientVersion = "v0.0.2"
--[[-----------------------------------------------------------------------------
data
-------------------------------------------------------------------------------]]
local GREY = "|cff999999";
local RED = "|cffff0000";
local WHITE = "|cffFFFFFF";
local GREEN = "|cff1eff00";
local PURPLE = "|cff9F3FFF";
local BLUE = "|cff0070dd";
local ORANGE = "|cffFF8400";

local requestListData = {{}}
local requireInfo = nil
--[[-----------------------------------------------------------------------------
Init Frame
-------------------------------------------------------------------------------]]
RSystem = LibStub("AceAddon-3.0"):NewAddon("RSystem", "AceConsole-3.0","AceEvent-3.0","AceComm-3.0")

function RSystem:OnInitialize()
    -- Called when the addon is enabled
    self:RegisterEvent("MAIL_SHOW")
    self:RegisterEvent("MAIL_CLOSED")
    self:RegisterEvent("MAIL_FAILED")
    self:RegisterEvent("MAIL_SEND_SUCCESS")
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterComm("RSystemClient", function() end)
end

function RSystem:OnEnable()
    -- create tool tip
    if not MyTooltip then
        CreateFrame("GameTooltip", "MyTooltip", nil, "GameTooltipTemplate")
        MyTooltip:SetOwner( WorldFrame, "ANCHOR_NONE" );
        MyTooltip:AddFontStrings(
                MyTooltip:CreateFontString( "$parentTextLeft1", nil, "GameTooltipText" ),
                MyTooltip:CreateFontString( "$parentTextRight1", nil, "GameTooltipText" ) );
    end
end

function RSystem:OnDisable()
    -- Called when the addon is disabled
end

function RSystem:MAIL_SEND_SUCCESS()
    --print("MAIL_SEND_SUCCESS")
end

function RSystem:MAIL_FAILED()
    print("MAIL_FAILED")
end

function RSystem:PLAYER_ENTERING_WORLD()
    --RegisterAddonMessagePrefix("RSystemClient")
end

-- 注册监听
function RSystem:CHAT_MSG_ADDON(_ ,channel, message)
    if (channel=="RSystemClient") then
        local tab = { strsplit( "_", message) }
        if (tab[1] == "GetRequestList") then
            local listTable= json2table(tab[3])
            table.insert(requestListData,listTable)
            local newList = RSystem:RemoveRepetition(requestListData)
            requestListData = newList
        end
        if (tab[1] == "GetRequestListDone") then
            createRootFrame()
        end
    end
end

function RSystem:MAIL_SHOW()
    -- 创建入口按钮
    local button = CreateFrame("Button", nil, SendMailFrame)
    button:SetPoint("RIGHT", SendMailFrame, "TOPRIGHT", 5, -60)
    button:SetWidth(40)
    button:SetHeight(40)
    button:SetNormalTexture("Interface\\Icons\\INV_Misc_Coin_01")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Round")
    button:SetPushedTexture("Interface\\Icons\\INV_Misc_Coin_05")
    button:SetScript("onClick", function()
        requestListData = {{}}
        RSystem:SendCommMessage("RSystemServer", "GetRequestList_"..UnitName("player").."", "WHISPER", adminUserName);
    end)
end

function RSystem:MAIL_CLOSED()
    if (RSystemFrameUI:IsVisible()) then
        RSystemFrameUI:ClearAllPoints()
        RSystemFrameUI:Hide();
    end
end

--[[-----------------------------------------------------------------------------
create sub Frame
-------------------------------------------------------------------------------]]
function createRootFrame()
    -- Called when the addon is loaded
    RSystemFrameUI = AceGUI:Create("Frame")
    --RSystemFrameUI:SetCallback("OnClose",function(widget) AceGUI:Release(widget) end)
    RSystemFrameUI:SetTitle("黑商悬赏任务系统")
    RSystemFrameUI:SetHeight(550)
    RSystemFrameUI:SetWidth(800)
    RSystemFrameUI:SetStatusText("黑商管理员在线 "..clientVersion)
    RSystem:createFrameWidgets (RSystemFrameUI)
    RSystemFrameUI:Show()
end
function RSystem:createFrameWidgets(f)
    local HeaderFrame = AceGUI:Create("InlineGroup")
    HeaderFrame:SetFullWidth(true)
    HeaderFrame:SetLayout("Flow")
    RSystem:createEditBox(HeaderFrame,"物品ID",200,false,handleRequireNameChange)
    --createEditBox(HeaderFrame,"需求数量",80,handleSearchEnter)
    RSystem:createMoneyInput(HeaderFrame)
    RSystem:createButton(HeaderFrame, "发布需求", 100, handlePushRequest)
    RSystem:createTabGroup(f,{{text="找物品", value="item"}, {text="找打手", value="help"}},"item",SelectGroup)
    f:AddChild(HeaderFrame)
end

function RSystem:createMoneyInput(HeaderFrame)
    local customMoneyFrame = AceGUI:Create("SimpleGroup")
    local emptyLabel = AceGUI:Create("Label")
    emptyLabel:SetWidth(80)
    emptyLabel:SetText("悬赏金额：")
    emptyLabel:SetFontObject(GameFontNormal)
    customMoneyFrame:SetLayout("Flow")
    customMoneyFrame.frame = moneyInputFrame
    HeaderFrame:AddChildren(emptyLabel,customMoneyFrame)
end

function createScrollItems(scrollList,listData)
    for i,o in pairs(listData) do
        if (o["itemId"]) then
            local itemName,itemLink,itemRarity = GetItemInfo(tostring(o["itemId"]))
            local _, _, _, itemColor = GetItemQualityColor(itemRarity);
            if (itemName and itemLink) then
                local ItemContainer = AceGUI:Create("SimpleGroup")
                ItemContainer:SetLayout("Flow")
                ItemContainer.width = "fill"

                local tx = ItemContainer.frame:CreateTexture(nil, "BACKGROUND")
                tx:SetTexture('Interface\\Tooltips\\CHATBUBBLE-BACKGROUND')
                tx:SetPoint("TOPLEFT", 0, 0)
                tx:SetPoint("BOTTOMRIGHT", 0, 0)

                -- 物品图标
                local itemIcon = AceGUI:Create("Icon")
                itemIcon:SetImage(GetItemIcon(o["itemId"]))
                itemIcon:SetImageSize(35, 35)
                itemIcon:SetWidth(50)
                itemIcon:SetCallback("OnEnter", function(self)
                    MyTooltip:SetOwner(self.frame, "ANCHOR_BOTTOMLEFT")
                    MyTooltip:SetHyperlink(itemLink)
                    MyTooltip:Show()
                end)
                itemIcon:SetCallback("OnLeave",  function(self)
                    MyTooltip:ClearLines()
                    MyTooltip:Hide()
                end)

                -- 物品名称
                local name = AceGUI:Create("Label")
                --name:SetText(itemLink)
                local nameStr = itemColor..itemName or ""
                name:SetText(nameStr)
                name:SetWidth(200)

                ---- 物品数量
                --local itemCount = AceGUI:Create("Label")
                --itemCount:SetText(o["itemCount"])
                --itemCount:SetWidth(60)

                -- 悬赏人
                local user = AceGUI:Create("Label")
                user:SetText(o["userName"])
                user:SetWidth(100)

                -- 悬赏金额
                local rewardMoney = GetMoneyString(o["money"])
                local money = AceGUI:Create("Label")
                money:SetText(rewardMoney)
                money:SetWidth(150)

                --时间
                local time = AceGUI:Create("Label")
                time:SetText(o["addTime"])
                time:SetWidth(150)

                local itemButton = AceGUI:Create("Button")
                itemButton:SetWidth(60)
                if (UnitName("player") == o["userName"]) then
                    itemButton:SetText("撤榜")
                    itemButton:SetCallback("OnClick", function(self)
                        RSystemFrameUI:Hide()
                        StaticPopupDialogs["DropRequest"] = {
                            text = "|cffff7000温馨提醒|r\r\n\n你确定要撤销" ..itemLink..
                                    "的悬赏任务？" .."\r\n\n|cffffff00黑涩商会将不会退换手续费|r",
                            button1 = "确定",
                            button2 = "取消",
                            OnAccept = function()
                                RSystem:SendCommMessage(
                                        "RSystemServer",
                                        "DropRequest_"..UnitName("player").."_"..o["requestId"].."",
                                        "WHISPER",
                                        adminUserName);
                            end,
                            OnCancel = function(_, reason)
                                RSystemFrameUI:Show()
                            end,
                            timeout = 0,
                            whileDead = true,
                            hideOnEscape = true,
                            preferredIndex = 3,
                        }
                        StaticPopup_Show ("DropRequest")
                    end)
                else
                    itemButton:SetText("揭榜")
                    itemButton:SetCallback("OnClick", function(self)
                        handlePullRequest(o["requestId"],itemName,itemLink,1,o["money"],o["userName"])
                    end)
                end

                ItemContainer:AddChildren(itemIcon,name,user,money,time,itemButton)

                local spaceEmpty = AceGUI:Create("Label")
                spaceEmpty:SetText("")
                spaceEmpty:SetHeight(20)
                spaceEmpty:SetFullWidth(true)

                scrollList:AddChildren(ItemContainer,spaceEmpty)
            end
        end
    end
end

--[[-----------------------------------------------------------------------------
widget event
-------------------------------------------------------------------------------]]
function UserChangedRequireMoney()
    local requireMoney = MoneyInputFrame_GetCopper(moneyInputFrame);
    if (requireInfo == nil) then
        requireInfo = {}
    end
    requireInfo["requireMoney"] = requireMoney
end

function handlePushRequest()
    local requireMoney = MoneyInputFrame_GetCopper(moneyInputFrame);
    if (requireInfo == nil) then
        TradingUtils_ShowMsg("悬赏信息不可为空")
        return
    end
    if requireMoney <= 0 then
        TradingUtils_ShowMsg("奖励金额太少，你也太抠了。")
        return
    end
    if (requireInfo["itemName"] == nil) then
        TradingUtils_ShowMsg("请输入一个正确的物品名称")
        return
    end
    -- 隐藏主窗口
    RSystemFrameUI:Hide()
    StaticPopupDialogs["EXAMPLE_HELLOWORLD"] = {
        text = "|cffff7000温馨提醒|r\r\n\n你确定要发布" ..requireInfo["itemLink"]..
                "的悬赏任务？\n悬赏金额：" ..GetMoneyString(requireInfo["requireMoney"])
                .."\r\n\n|cffffff00黑涩商会将对您本条悬赏收取|r"..GetMoneyString(serviceCharge).."|cffffff00的手续费|r",
        button1 = "发布",
        button2 = "取消",
        OnAccept = function()
            sendCharge(requireInfo["itemLink"],requireInfo["requireMoney"])
        end,
        OnCancel = function(_, reason)
            RSystemFrameUI:Show()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show ("EXAMPLE_HELLOWORLD")
end

function handlePullRequest(requestId,itemName,itemLink,needCount,rewardMoney,requestUserName)
    local b,s = getItemSlotInBag(itemName,needCount)
    if b ~= nil and s ~= nil then
        UseContainerItem(b,s)
        SendMailCODButton:SetChecked(true);
        SendMailSendMoneyButton:SetChecked(false);
        SendMailNameEditBox:SetText(requestUserName)
        SendMailSubjectEditBox:SetText("来自"..UnitName('player').."的揭榜")
        SetSendMailCOD(rewardMoney)
        local gold, silver, copper = MyCOD_CoppersToGoldSilverCopper(tonumber(rewardMoney))
        SendMailMoneyGold:SetText(gold);
        SendMailMoneySilver:SetText(silver);
        SendMailMoneyCopper:SetText(copper);
        if (checkMailAttach(itemName,needCount)) then
            SendMail(requestUserName, "来自"..UnitName('player').."的揭榜", "来自 "..UnitName("player").."的揭榜\r\n悬赏物品："..itemLink.."\n悬赏金额："..GetMoneyString(rewardMoney).."\n请签收并付款\n发送时间：20" .. date("%y-%m-%d %H:%M:%S"))
            MoneyInputFrame_SetCopper(moneyInputFrame,0)
            TradingUtils_ShowMsg("你揭榜了"..itemLink.."的悬赏，悬赏金额："..GetMoneyString(rewardMoney))
            RSystem:SendCommMessage(
                    "RSystemServer",
                    "PullRequest_"..UnitName("player").."_"..requestId.."",
                    "WHISPER",
                    adminUserName
            );
        else
            TradingUtils_ShowMsg("提交揭榜物品信息异常！")
        end
    else
        TradingUtils_ShowMsg("你没有悬赏物品！")
    end
end

function handleRequireNameChange(widget, event, text)
    print(text)
    local itemName, itemLink = GetItemInfo(text);
    print(itemName,itemLink)
    if (itemName and itemLink) then
        local itemID = itemLink:match("item:(%d+)")
        if (requireInfo == nil) then
            requireInfo = {}
        end
        requireInfo["itemID"] = itemID
        requireInfo["itemName"] = itemName
        requireInfo["itemLink"] = itemLink
    end
end

function DrawGroup1(container)
    local scrollList = AceGUI:Create("ScrollFrame")
    scrollList:SetFullWidth(true)
    scrollList:SetLayout("List")
    scrollList:SetHeight(380)
    scrollList:SetAutoAdjustHeight(true)

    createScrollItems(scrollList,requestListData)

    container:AddChild(scrollList)


    local button = AceGUI:Create("Button")
    button:SetText("Tab 1 Button")
    button:SetWidth(200)
    container:AddChild(button)
end

-- function that draws the widgets for the second tab
function DrawGroup2(container)
    local desc = AceGUI:Create("Label")
    desc:SetText("系统开发中")
    desc:SetFullWidth(true)
    container:AddChild(desc)
end

-- Callback function for OnGroupSelected
function SelectGroup(container, event, group)
    container:ReleaseChildren()
    if group == "item" then
        DrawGroup1(container)
    elseif group == "help" then
        DrawGroup2(container)
    end
end

--[[-----------------------------------------------------------------------------
common function
-------------------------------------------------------------------------------]]

local function getCurTime()
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
function RSystem:createButton(parent, text, width, callBack)
    -- Create a button
    local btn = AceGUI:Create("Button")
    btn:SetWidth(width)
    btn:SetText(text)
    btn:SetCallback("OnClick", callBack)
    -- Add the button to the container
    parent:AddChild(btn)
end

function RSystem:createEditBox(parent,textLabel,width,hideEnter,textChangeCallBack)
    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel(textLabel)
    editbox:DisableButton(hideEnter)
    editbox:SetWidth(width)
    editbox:SetCallback("OnEnterPressed", textChangeCallBack)
    parent:AddChild(editbox)
end

function RSystem:createTabGroup(parent,tabs,defaultTabValue,selectCallBack)
    -- Create the TabGroup
    local tab =  AceGUI:Create("TabGroup")
    tab:SetFullWidth(true)
    tab:SetLayout("Fill")
    tab:SetHeight(370)
    tab:SetTabs(tabs)
    tab:SetCallback("OnGroupSelected", selectCallBack)
    tab:SelectTab(defaultTabValue)
    -- add to the frame container
    parent:AddChild(tab)
end

-----------------------
-- 获得金钱显示字符串
-----------------------
function GetMoneyString(money)
    local goldString, silverString, copperString;
    local gold = floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD));
    local silver = floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER);
    local copper = mod(money, COPPER_PER_SILVER);

    if ( ENABLE_COLORBLIND_MODE == "1" ) then
        goldString = gold..GOLD_AMOUNT_SYMBOL;
        silverString = silver..SILVER_AMOUNT_SYMBOL;
        copperString = copper..COPPER_AMOUNT_SYMBOL;
    else
        goldString = format(GOLD_AMOUNT_TEXTURE, gold, 0, 0);
        silverString = format(SILVER_AMOUNT_TEXTURE, silver, 0, 0);
        copperString = format(COPPER_AMOUNT_TEXTURE, copper, 0, 0);
    end

    local moneyString = "";
    local separator = "";
    if ( gold > 0 ) then
        moneyString = goldString;
        separator = " ";
    end
    if ( silver > 0 ) then
        moneyString = moneyString..separator..silverString;
        separator = " ";
    end
    if ( copper > 0 or moneyString == "" ) then
        moneyString = moneyString..separator..copperString;
    end

    return moneyString;
end

function TradingUtils_ShowMsg( msg )
    DEFAULT_CHAT_FRAME:AddMessage( msg, 1, 1, 0 );
end
-----------------------
-- 自动邮件
-----------------------
function MyCOD_CoppersToGoldSilverCopper(coppers)
    local gold, silver, copper = 0, 0, 0
    if coppers < 100 then
        copper = coppers
    else
        copper = mod(coppers, 100)
        coppers = coppers - copper
        if coppers < 10000 then
            silver = coppers/100
        else
            silver = mod(coppers, 10000) / 100
            gold = (coppers - (silver * 100))/ 10000
        end
    end
    return gold, silver, copper
end

function sendCharge(itemLink,requireMoney)
    local curMoney = GetMoney()
    if (curMoney < (serviceCharge + 30)) then
        TradingUtils_ShowMsg("你的钱还不够支付服务费！")
        requireInfo = {}
        MoneyInputFrame_SetCopper(moneyInputFrame,0)
        return
    elseif (curMoney < (serviceCharge + 30 + requireMoney)) then
        TradingUtils_ShowMsg("你的钱还不够赏金，请尽快补足！")
    end
    local gold, silver, copper = MyCOD_CoppersToGoldSilverCopper(serviceCharge)
    SendMailMoneyGold:SetText(gold);
    SendMailMoneySilver:SetText(silver);
    SendMailMoneyCopper:SetText(copper);
    SendMailSendMoneyButton:SetChecked(true);
    SendMailCODButton:SetChecked(false);
    --SendMailNameEditBox:SetText(adminUserName);
    SendMailSubjectEditBox:SetText("支付佣金")
    SetSendMailMoney(serviceCharge)
    local timeStamp = "20" .. date("%y-%m-%d %H:%M:%S");
    SendMail(adminUserName, "支付佣金", "来自 "..UnitName("player").."的悬赏任务单\r\n悬赏物品："..itemLink.."\n悬赏金额："..GetMoneyString(requireMoney).."\n服务佣金："..GetMoneyString(serviceCharge).."\n发送时间："..timeStamp)
    RSystem:SendCommMessage(
            "RSystemServer",
            "PostRequest_"..UnitName("player").."_"..requireInfo["itemLink"].."_"..requireInfo["requireMoney"],
            "WHISPER",
            adminUserName);
    requireInfo = {}
    MoneyInputFrame_SetCopper(moneyInputFrame,0)
end

function getItemSlotInBag(needItemName,needCount)
    for i=4,0,-1 do
        for j=GetContainerNumSlots(i), 1, -1 do
            local item = GetContainerItemLink(i,j);
            local _, itemCount = GetContainerItemInfo(i,j);
            if item~=nil then
                local itemName = GetItemInfo(item)
                if needItemName == itemName then
                    if itemCount > needCount then
                        local freebag,freeslot=getFreeSlot()
                        if freebag and freeslot then
                            SplitContainerItem(i,j,needCount)
                            PickupContainerItem(freebag,freeslot)
                            return freebag, freeslot
                        else
                            TradingUtils_ShowMsg("没有多余的空间了")
                            return nil, nil
                        end
                    elseif itemCount < needCount then
                        TradingUtils_ShowMsg("任务物品不足")
                        return nil, nil
                    else
                        return i,j
                    end
                end
            end
        end
    end
    return nil ,nil
end

function getFreeSlot()
    for i=4,0,-1 do
        for j=GetContainerNumSlots(i), 1, -1 do
            local item = GetContainerItemLink(i,j);
            if item ==nil then
                return i,j
            end
        end
    end
end

function ZCLOG(Lua_table)
    -- do
    --     return
    -- end
    local function define_print(_tab,str)
        str = str .. "  "
        for k,v in pairs(_tab) do
            if type(v) == "table" then
                if not tonumber(k) then
                    print(str.. k .."{")
                else
                    print(str .."{")
                end
                define_print(v,str)
                print( str.."}")
            else
                print(str .. tostring(k) .. " " .. tostring(v))
            end
        end
    end
    if type(Lua_table) == "table" then
        define_print(Lua_table," ")
    else
        print(tostring(Lua_table))
    end
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

function RSystem:RemoveRepetition(TableData)
    local bExist = {}
    local result = {}
    for i, record  in pairs(TableData) do
        if (record ["requestId"] and bExist[record["requestId"]] == nil) then
            bExist[record["requestId"]] = true
            table.insert(result, record)
        end
    end

    return result
end

function checkMailAttach(needItemName,needCount)
    local sendCount = 0
    for i=1,ATTACHMENTS_MAX_SEND do
        local name,_,count=GetSendMailItem(i)
        if name == needItemName then
            local newCount = sendCount+count
            sendCount = newCount
        end
    end
    if sendCount == needCount then
        return true
    else
        return false
    end
end

function isAdminOnline()
    local maxNum = GetNumFriends();
    for index=1, maxNum do
        name, level, class, area, connected, status, note = GetFriendInfo(index);
        if (name == adminUserName and connected ~= nil) then
            return true
        end
    end
    return false
end

function setTimeOut(n)
    local t = 0
    local preTime = time()
    local curTime = time()
    while t < n do
        curTime = time()
        if curTime > preTime then
            preTime = curTime
            t = t + 1
        end
    end
end