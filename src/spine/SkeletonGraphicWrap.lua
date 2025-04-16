local SkeletonGraphicWrap = BaseClass("SkeletonGraphicWrap")

function GetAnimationTimeByName(transform, animationName)
    local skeletonGraphic = transform.transform:GetComponentInChildren(ClassType.SkeletonGraphic)
    if skeletonGraphic == nil then
        printerror("没有 skeletonGraphic组件 ")
        return 0
    end
    local skeletonData = skeletonGraphic.Skeleton.Data
    local animation = skeletonData:FindAnimation(animationName)
    if ObjectUtils.IsNotNil(animation) then
        return animation.Duration
    else
        printerror("Animation not found: " .. animationName)
        return 0
    end
end

Const.SpineAnimationStateEvent = {
    ---[[
    ---触发时机：某个动画 TrackEntry 被设置播放时（SetAnimation 或 AddAnimation 时）
    ---说明：动画开始播放的那一刻（注意，不是帧为0，而是被激活）
    ---用途示例：播放入场动画、初始化状态
    ---]]
    Start = "OnStart",
    ---[[
    ---触发时机：某动画播放过程中被另一个动画中断了
    ---说明：例如 A 正在播，突然被 B 替换，就会触发 A 的 Interrupt
    ---用途示例：处理动画被打断的状态清理，或播放中断特效
    ---]]
    Interrupt = "OnInterrupt",
    ---[[
    ---触发时机：当动画自然播放完成或被替换时触发（即生命周期结束）
    ---说明：动画播放结束后，从播放轨道中移除，不再占用资源
    ---用途示例：资源释放、对象销毁、逻辑状态标记
    ---]]
    End = "OnEnd",
    ---[[
    ---触发时机：当 TrackEntry 被彻底释放（GC）之前
    ---说明：和 End 类似，但更多用于底层清理或对象池回收
    ---用途示例：清理引用、归还对象池
    ---]]
    Dispose = "OnDispose",
    ---[[
    ---触发时机：动画播放完整循环后触发一次（无论是否 loop）
    ---说明：
    ---如果是非循环动画：播放一轮后触发
    ---如果是循环动画：每播放一整轮触发一次
    ---用途示例：执行一次奖励逻辑、跳转动画阶段
    ---]]
    Complete = "OnComplete"
}

function SkeletonGraphicWrap:__ctor(skeletonGraphic)
    self.skeletonGraphic = skeletonGraphic
    self:SpineInitialize()
end

function SkeletonGraphicWrap:GetAnimationState()
    return self.skeletonGraphic.AnimationState
end

function SkeletonGraphicWrap:__delete()
    self:UnBindAllEvent()
    for i, v in ipairs(self.bindFunc) do
        table.clear(v)
    end
    table.clear(self.bindFunc)
    self.bindFunc = nil
    table.clear(self.funcIdDict)
    self.funcIdDict = nil
    self.transform = nil
    self.skeletonGraphic = nil
end

function SkeletonGraphicWrap:UnBindAllEvent()
    if self.bindFunc then
        for eventType, eventFuncList in pairs(self.bindFunc) do
            for _, func in ipairs(eventFuncList) do
                if eventType == Const.SpineAnimationStateEvent.Start then
                    self.skeletonGraphic.AnimationState.Start = self.skeletonGraphic.AnimationState.Start - func
                elseif eventType == Const.SpineAnimationStateEvent.Interrupt then
                    self.skeletonGraphic.AnimationState.Interrupt = self.skeletonGraphic.AnimationState.Interrupt - func
                elseif eventType == Const.SpineAnimationStateEvent.End then
                    self.skeletonGraphic.AnimationState.End = self.skeletonGraphic.AnimationState.End - func
                elseif eventType == Const.SpineAnimationStateEvent.Dispose then
                    self.skeletonGraphic.AnimationState.Dispose = self.skeletonGraphic.AnimationState.Dispose - func
                elseif eventType == Const.SpineAnimationStateEvent.Complete then
                    self.skeletonGraphic.AnimationState.Complete = self.skeletonGraphic.AnimationState.Complete - func
                end
            end
        end
    end
end

function SkeletonGraphicWrap:SetSpineAnimtionLoop(animationName)
    self:SetSpineAnimtion(animationName, true)
end

function SkeletonGraphicWrap:ClearTracks()
    self.skeletonGraphic.AnimationState:ClearTracks()
end

function SkeletonGraphicWrap:SpineInitialize()
    self.skeletonGraphic:Initialize(true)
end

function SkeletonGraphicWrap:GetAnimationTimeByName(animationName)
    local skeletonData = self.skeletonGraphic.Skeleton.Data
    local animation = skeletonData:FindAnimation(animationName)
    if ObjectUtils.IsNotNil(animation) then
        return animation.Duration
    else
        printerror("Animation not found: " .. animationName)
        return 0
    end
end

function SkeletonGraphicWrap:SetSpineAnimtion(animationName, _isLoop)
    _isLoop = _isLoop or false
    local strings = string.split(animationName, ",")
    if strings == nil then
        G_printerror("SetSpineAnimation error")
    end
    if (#strings == 1) then
        self.skeletonGraphic.AnimationState:SetAnimation(0, strings[1], _isLoop)
        return
    end
    self.skeletonGraphic.AnimationState:SetAnimation(0, strings[1], false)
    self.skeletonGraphic.AnimationState.Complete = self.skeletonGraphic.AnimationState.Complete +
        callback(self, "__Complete1", strings, _isLoop)
end

function SkeletonGraphicWrap:__Complete1(strings, _isLoop, spineTrackEntry)
    if #strings > 2 then
        self.skeletonGraphic.AnimationState:SetAnimation(0, strings[2], false)
        self.skeletonGraphic.AnimationState.Complete = self.skeletonGraphic.AnimationState.Complete +
            callback(self, "__Complete2", strings, _isLoop)
    elseif #strings == 2 then
        self.skeletonGraphic.AnimationState:SetAnimation(0, strings[2], _isLoop)
    end
end

function SkeletonGraphicWrap:__Complete2(spineTrackEntry, strings, _isLoop)
    self.skeletonGraphic.AnimationState:SetAnimation(0, strings[2], _isLoop)
end

function SkeletonGraphicWrap:SetSpineSkin(skinName)
    local skeleton = self.skeletonGraphic.Skeleton
    if skeleton == nil then
        printerror("skeleton is nil")
        return
    end
    local skin = skeleton.Data:FindSkin(skinName);
    if skin == nil then
        printerror("skin is nil")
        return
    end
    skeleton:SetSkin(skin)
    skeleton:SetSlotsToSetupPose()
    self.skeletonGraphic:UpdateMesh()
end

local funcId = 0

function SkeletonGraphicWrap:BindEvent(eventType, func)
    self.bindFunc = self.bindFunc or {}
    self.bindFunc[eventType] = self.bindFunc[eventType] or {}
    self.funcIdDict = self.funcIdDict or {}
    table.insert(self.bindFunc[eventType], func)
    if eventType == Const.SpineAnimationStateEvent.Start then
        self.skeletonGraphic.AnimationState.Start = self.skeletonGraphic.AnimationState.Start + func
    elseif eventType == Const.SpineAnimationStateEvent.Interrupt then
        self.skeletonGraphic.AnimationState.Interrupt = self.skeletonGraphic.AnimationState.Interrupt + func
    elseif eventType == Const.SpineAnimationStateEvent.End then
        self.skeletonGraphic.AnimationState.End = self.skeletonGraphic.AnimationState.End + func
    elseif eventType == Const.SpineAnimationStateEvent.Dispose then
        self.skeletonGraphic.AnimationState.Dispose = self.skeletonGraphic.AnimationState.Dispose + func
    elseif eventType == Const.SpineAnimationStateEvent.Complete then
        self.skeletonGraphic.AnimationState.Complete = self.skeletonGraphic.AnimationState.Complete + func
    else
        printerror("SkeletonGraphic 没有" .. eventType .. "事件可以绑定")
        return
    end
    funcId = funcId + 1
    self.funcIdDict[funcId] = func
end

function SkeletonGraphicWrap:UnBindEvent(eventType, funcId)
    local func = self.funcIdDict[funcId]
    if func then
        printerror("事件" .. eventType .. "没有绑定函数,无法解绑函数")
    end
    if eventType == Const.SpineAnimationStateEvent.Start then
        self.skeletonGraphic.AnimationState.Start = self.skeletonGraphic.AnimationState.Start - func
    elseif eventType == Const.SpineAnimationStateEvent.Interrupt then
        self.skeletonGraphic.AnimationState.Interrupt = self.skeletonGraphic.AnimationState.Interrupt - func
    elseif eventType == Const.SpineAnimationStateEvent.End then
        self.skeletonGraphic.AnimationState.End = self.skeletonGraphic.AnimationState.End - func
    elseif eventType == Const.SpineAnimationStateEvent.Dispose then
        self.skeletonGraphic.AnimationState.Dispose = self.skeletonGraphic.AnimationState.Dispose - func
    elseif eventType == Const.SpineAnimationStateEvent.Complete then
        self.skeletonGraphic.AnimationState.Complete = self.skeletonGraphic.AnimationState.Complete - func
    end
end

return SkeletonGraphicWrap
