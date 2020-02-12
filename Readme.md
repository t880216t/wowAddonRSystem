年前和游戏中的朋友交流，他们希望有个魔兽世界内的发布悬赏商品的插件。作为程序狗，一口就汪下来了。哪知踏上了一条坑溢满满的lua开发之路。

<!--more-->

# 背景

作为一个老wower，还是时不时会打开魔兽逛逛。最近在玩一个SF，游戏里很多装备需要其它装备合成。所以游戏里很多小伙伴希望有个便捷装备交易的系统。
说实话，作为不充钱的普通玩家，这本和我无关，不过游戏里有几个玩的不错的wow友，着实很肝。出于对他们的关爱和程序汪的装13心理。我着手设计开发了这个装备悬赏系统插件。

# 实现效果

![](https://github.com/t880216t/wowAddonRSystem/blob/master/gitImage/home.jpg)

# 架构

![](https://github.com/t880216t/wowAddonRSystem/blob/master/gitImage/luawow.png)

# 功能

- 玩家可以发布自己的采购需求，并需向管理员支付一定的服务费
- 玩家看到别人的悬赏物品，及悬赏金额等信息
- 玩家点击“揭榜”将自动发送指定悬赏金额的物品给发布人，且为付费取货邮件
- 管理员接收各个玩家发来的消息，处理数据回复给玩家，并会对数据做持久化保存

# 核心代码

## 服务端

服务端主要是看不见服务，部分操作也有界面日志输出。

首先注册下插件
```lua
RSystemServer = LibStub("AceAddon-3.0"):NewAddon("RSystemServer", "AceConsole-3.0","AceEvent-3.0")

function RSystemServer:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RSystemServerDB")
    -- Called when the addon is enabled
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    if (self.db.profile.receiveRequestList) then
        receiveRequestList = self.db.profile.receiveRequestList
    end
end

function RSystemServer:PLAYER_ENTERING_WORLD()
    RegisterAddonMessagePrefix("RSystemServer")
end
```

监听发来的消息
```lua
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
```

具体的处理方法见源码，这里主要是把table数据分割，并格式化为了string回复给玩家。

## 客户端

玩家客户端涉及到界面展示，我使用的ACEGUI3框架，比原生好用很多，不过定制的化能力较弱些。

初始化插件
```lua
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

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
```

可以看到，我们的插件会和邮件系统的事件有很多交互。

创建一个tooltip，后面我们就可以直接调“MyTooltip:Show()”用了
```lua
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
```

创建界面元素
```lua
function RSystem:createFrameWidgets(f)
    local HeaderFrame = AceGUI:Create("InlineGroup")
    HeaderFrame:SetFullWidth(true)
    HeaderFrame:SetLayout("Flow")
    RSystem:createEditBox(HeaderFrame,"物品ID",200,false,handleRequireNameChange)
    RSystem:createMoneyInput(HeaderFrame)
    RSystem:createButton(HeaderFrame, "发布需求", 100, handlePushRequest)
    RSystem:createTabGroup(f,{{text="找物品", value="item"}, {text="找打手", value="help"}},"item",SelectGroup)
    f:AddChild(HeaderFrame)
end

```

系统最重要的部分，支付佣金、发送货物模块。

```lua
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
```

# 结束

完整的实现代码：https://github.com/t880216t/wowAddonRSystem

虽然玩的私服，但是实际本应用中所有的api和框架都是正式服可用，所以由此C/S架构的插件开发其实我们还可以做更多的扩展，精力有限暂时先折腾这些。
