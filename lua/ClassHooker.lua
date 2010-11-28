--[[
--3 hook types:

-- Standard/Pre:
--	Are called before the orignal function is called
--	any value they return will be ignored
--	can set return value of the hook with hookHandle:SetReturn(retvalue)
--
--
------------------------------------------
-- Raw Hooks:
--	Are processed first before Standard hooks
--	Can Modify paramaters sent to the orignal function
--	Must return the new parameters or the orignals if it did not change any e.g. "function hook(objself, a1, a2 ,a3) return a1, a2 ,a3 end" 
--		the objself paramter doesn't have tobe returned
--	Can set return value of the hook with HookHandle:SetReturn(retvalue)


-- Post Hooks:
--	called after Standard hooks and after the orignal function is called
--	can get the return value that the orignal function returned with HookHandle:GetReturn
-- 
--needs to have hook priorty/ordering system based on hooker id string
--hooks can request ordering based on the id of other hookers i.e. before and after also we should throw an error if 2 tooks both request tobe before/after each other
--be able to remove and reorder hooks without issue
--
--HookHandle:BlockCallOrignal(bool singlecall)

--if HookHandle:BlockCallOrignal(bool) is called with both false and true during the processing of a hook either trigger a lua error or a warning message
--only send the warning once for a specific conflict
]]--

if(not FakeNil) then
	FakeNil = {}
end

ClassHooker = {
	ClassObjectToName = {},
	--used to keep track of the base class of each class so we know if its safe to modfify them
	ChildClass = {Entity = {}},
	LinkedClasss = {},
	
	ClassDeclaredCb = {},
	ClassFunctionHooks = {},
	
	FileNameToClass = {},
	CreatedIn = {},
}

Script.Load("lua/DispatchBuilder.lua")
Script.Load("lua/LoadTracker.lua")

ClassHooker.ClassObjectToName[Entity] = "Entity"

local MarkerTable = {}

--[1] is the hook function
--[2] is the self arg
--[3] is the global hook table for the hooked function

local function EmptyFunction()
end

local HookHandleFunctions = {
	SetReturn = function(self, a1)
		self[3].ReturnValue = a1
	end,

	GetReturn = function(self)
		local retvalue = self[1].ReturnValue

		--check to see if we have to return more than 1 value
		if(self[3].ReturnValueIsList) then
			return unpack(retvalue)
		else
			return self[3].ReturnValue
		end
	end,
	
	--your mind will be blown
	BlockOrignalCall = function(self, continuousBlock)
		
		local hookData = self[3]

		if(not continuousBlock) then
			if(not hookData.CachedOrignalReset) then
				hookData.CachedOrignalReset = function() hookData.Orignal = hookData.RealOrignal end
			end

			hookData.Orignal = hookData.CachedOrignalReset
		else
			hookData.Orignal = EmptyFunction
			hookData.ContinuousBlockOrignal = true
		end
	end,

	EnableCallOrignal = function(self)
		local hookData = self[3]
		hookData.ContinuousBlockOrignal = false
		hookData.Orignal = hookData.RealOrignal
	end,

	IsBlockCallOrignalActive = function(self)
		return self[3].Orignal ~= self[3].RealOrignal
	end,
}

local HookHandleMT = {
	__call = function(self, ...)
		return self[1](...)
	end,
	__index = HookHandleFunctions,
}

local HookHandleMT_PassHandle = {
	__call = function(self, ...)
		return self[1](self, ...)
	end,

	__index = HookHandleFunctions,
}

local SelfFuncHookHandleMT = {
	__call = function(self, ...)
		return self[1](self[2], ...)
	end,
	__index = HookHandleFunctions
}

local SelfFuncHookHandleMT_PassHandle = {
	__call = function(self, ...)
		return self[1](self[2], self, ...)
	end,
	
	__index = HookHandleFunctions,
}

function ClassHooker:ScriptLoadFinished(scriptPath)
	
	local classlist = self.FileNameToClass[scriptPath]
	
	if(classlist) then
		for _,className in ipairs(classlist) do
			self:OnClassFullyDefined(className)
		end
	end
end

function ClassHooker:SetClassCreatedIn(class, luafile)
	
	local path = LoadTracker.NormalizePath(luafile)
	
	if(not self.FileNameToClass[path]) then
		self.FileNameToClass[path] = {class}
	else
		table.insert(self.FileNameToClass[path], class)
	end
	
	self.CreatedIn[class] = path
end

function ClassHooker:CreateAndSetHook(hookData, class, funcname)

	local OrignalFunction = _G[class][funcname]
	
	if(not OrignalFunction) then
		error(string.format("ClassHooker:CreateAndSetHook function \"%s\" in class %s does not exist", funcname, class))
	end
	
	--don't write to Orignal if a hook has called BlockOrignalCall already which changes Orignal to an empty function
	if(not hookData.Orignal) then
		hookData.Orignal = OrignalFunction 
	end
	
	--we have this so we have a second copy for when a hook disable calling the orignal bt replacing Orignal with a dummy function through BlockCallOrignal
	hookData.RealOrignal = Orignal

	hookData.Dispatcher	= DispatchBuilder:CreateDispatcher(hookData)

	local HookFunc = function(...)
		return hookData:Dispatcher(...)
	end
	
	_G[class][funcname] = HookFunc
	hookData.HookFunction = HookFunc
end

function ClassHooker:CheckCreateHookTable(classname, functioname, hookType)
	local hookTable = self.ClassFunctionHooks[classname]

	if(not hookTable) then
		hookTable = {}
		self.ClassFunctionHooks[classname] = hookTable
	end

	if(not hookTable[functioname]) then
		hookTable[functioname] = {}
	end
	
	hookTable = hookTable[functioname]
	
	if(hookType) then
		if(hookType == "Raw") then
			if(not hookTable.Raw) then
				hookTable.Raw = {}
			end
		elseif(hookType == "Post") then
			if(not hookTable.Post) then
				hookTable.Post = {}
			end
		end
	end
	
	return hookTable
end

--args classname functioName, FuncOrSelf, [callbackFuncName]
function ClassHooker:RawHookClassFunction(classname, ...)
	return self:HookClassFunctionType("Raw", ...)
end

--args classname functioName, FuncOrSelf, [callbackFuncName]
function ClassHooker:HookClassFunction(...)
	return self:HookClassFunctionType("Normal", ...)
end

--args classname functioName, FuncOrSelf, [callbackFuncName]
function ClassHooker:PostHookClassFunction(...)
	return self:HookClassFunctionType("Post", ...)
end

function ClassHooker:HookClassFunctionType(hookType, classname, functioName, FuncOrSelf, callbackFuncName)
	
	if(self:IsUnsafeToModify(classname)) then
		error(string.format("ClassHooker:HookClassFunction '%s' cannot be hooked after another class has inherited it", classname))
	end

	local HookData = self:CheckCreateHookTable(classname, functioName, hookType)

	local hookTable = HookData
	
	if(hookType == "Raw") then
		hookTable = HookData.Raw
	elseif(hookType == "Post") then
		hookTable = HookData.Post
	end

	local handle

	if(not callbackFuncName) then
		handle = setmetatable({FuncOrSelf, nil, HookData}, HookHandleMT)
	else
		handle = setmetatable({FuncOrSelf[callbackFuncName], FuncOrSelf, HookData}, SelfFuncHookHandleMT)
	end
	
	table.insert(hookTable, handle)
	
	return handle
end

function ClassHooker:ClassDeclaredCallback(classname, FuncOrSelf, callbackFuncName)

	if(self:IsUnsafeToModify(classname)) then
		error(string.format("ClassHooker:ClassDeclaredCallback '%s'",classname))
	end

	if(not self.ClassDeclaredCb[classname]) then
		self.ClassDeclaredCb[classname] = {}
	end

	if(callbackFuncName) then
		table.insert(self.ClassDeclaredCb[classname],	setmetatable({FuncOrThis[callbackFuncName], FuncOrSelf}, dispatcher))
	else
		table.insert(self.ClassDeclaredCb[classname], FuncOrSelf)
	end
end

function ClassHooker:IsUnsafeToModify(classname)
	return self.LinkedClasss[classname] and #self.ChildClass[classname] ~= 0
end

function ClassHooker:ClassStage2_Hook(classname, baseClassObject)
	
	if(baseClassObject) then
		local BaseClass = self.ClassObjectToName[baseClassObject]
		
		if(not baseClassObject) then
			--just let luabind spit out an error
			return
		end
		
		table.insert(self.ChildClass[BaseClass], classname)
	end
end

local Original_Class = _G.class
_G.class = function(...) 
	return ClassHooker:Class_Hook(...)
end


function ClassHooker:Class_Hook(classname)
	self.ChildClass[classname] = {}
	
	local stage2 = Original_Class(classname)

	self.ClassObjectToName[ _G[classname]] = classname

	return 	function(classObject) 
						stage2(classObject)
						ClassHooker:ClassStage2_Hook(classname, classObject)
					end
end



--Hook Shared.LinkClassToMap so we know when we can insert any hooks for a class
local OrginalLinkClassToMap = Shared.LinkClassToMap

Shared.LinkClassToMap = function(...)
		ClassHooker:OnClassFullyDefined(...)
	OrginalLinkClassToMap(...)
end

function ClassHooker:OnClassFullyDefined(classname, entityname)
	
	if(entityname) then
		self.LinkedClasss[classname] = true
	end
	
	local ClassDeclaredCb = self.ClassDeclaredCb[classname]
	
	if(ClassDeclaredCb) then
		for _,hook in ipairs(ClassDeclaredCb) do
			hook(classname)
		end
	end
	
	if(self.ClassFunctionHooks[classname]) then
		--Create and insert all the hooks registered for this class
		for funcName,hooktbl in pairs(self.ClassFunctionHooks[classname]) do
			self:CreateAndSetHook(hooktbl, classname, funcName)
		end
	end
end

local function Mixin_HookClassFunctionType(self, hooktype, classname, functionName, callbackFuncName)
	
	local callbackFunction

	if(not self.ClassHooker_Hooks[classname]) then
		self.ClassHooker_Hooks[classname] = {}		
	end

	if(self.ClassHooker_Hooks[classname][functionName] ~= nil) then
		error(string.format("ClassHooker:HookClassFunctionType function \"%s\" of class \"%s\" has already been hooked", functionName, classname))
	end

	--default to the to using a function with the same name as the hooked function
	if(not callbackFuncName) then
		callbackFuncName = functionName
	end

	if(not self[callbackFuncName]) then
		error(string.format("ClassHooker:HookClassFunctionType hook callback function \"%s\" does not exist", callbackFuncName))
	end

	local handle = ClassHooker:HookClassFunctionType(hooktype, classname, functionName, self, callbackFuncName)
	
	handle[4] = self.ClassHooker_ID

	return handle
end

local function Mixin_RawHookClassFunction(self, ...)
	return Mixin_HookClassFunctionType(self, "Raw", ...)
end

local function Mixin_HookClassFunction(self, ...)
	return Mixin_HookClassFunctionType(self, "Normal", ...)
end

local function Mixin_PostClassFunction(self, ...)
	return Mixin_HookClassFunctionType(self, "Post", ...)
end

function ClassHooker:Mixin(classTableOrName, IdString)

	if(not IdString) then
		
		if(type(classTableOrName) == "string") then
			if(not _G[classTableOrName]) then
				error("ClassHooker:Mixin No gobal table named "..classTableOrName)
			end
			
			classTableOrName = _G[classTableOrName]
			IdString = classTableOrName
		else
			error("ClassHooker:Mixin an Id String must be passed to the function")
		end
	end
	
	classTableOrName.ClassHooker_Hooks = {}
	classTableOrName.ClassHooker_ID = IdString
	
	classTableOrName.HookClassFunction = Mixin_HookClassFunction
	classTableOrName.PostHookClassFunction = Mixin_PostClassFunction
	classTableOrName.RawHookClassFunction = Mixin_RawHookClassFunction
end
