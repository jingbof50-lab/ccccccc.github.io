-- 1. 定义变量"judge"，默认值为0
local judge = 1

-- 2. 创建函数"frame"
local function frame()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/jingbof50-lab/roblox_universe_script/main/scripting_framework"))() -- 此处放入函数要执行的具体逻辑（示例：打印信息）
    print("judge为0，frame函数正在运行")
end

-- 3. 条件判断：当judge等于0时，调用frame函数
if judge == 1 then
    frame()  -- 执行函数
end
