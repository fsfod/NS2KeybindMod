DispatchBuilder = {}


function DispatchBuilder.SingleNormal(hookData, ...)
	hookData[1](...)

	local retvalue = hookData.Orignal(...)

		if(hookData.ReturnValue) then
			retvalue = hookData.ReturnValue
			hookData.ReturnValue = nil

			if(retvalue == FakeNil) then
				retvalue = nil
			end
		end

	return retvalue
end

function DispatchBuilder.SingleRaw(hookData, self, ...)
	local retvalue = hookData.Orignal(self, hookData.Raw[1](self, ...))

		if(hookData.ReturnValue) then
			retvalue = hookData.ReturnValue
			hookData.ReturnValue = nil
			
			if(retvalue == FakeNil) then
				retvalue = nil
			end
		end

	return retvalue
end

function DispatchBuilder.SinglePost(hookData, ...)
	--Store the return value in our hookinfo so the post hook can read it if it wants
	hookData.ReturnValue = hookData.Orignal(...)
	hookData.Post[1](...)

	local retvalue = hookData.ReturnValue
	hookData.ReturnValue = nil

	return retvalue
end


function DispatchBuilder:CreateDispatcher(hookData)
	
	if(#hookData == 1 and not hookData.Raw and not hookData.Post) then
		return self.SingleNormal
	end
	
	if(#hookData == 0) then
		if(hookData.Raw and #hookData.Raw == 1 and not hookData.Post) then
			return self.SingleRaw
		elseif(hookData.Post and #hookData.Post == 1 and not hookData.Raw) then
			return self.SinglePost
		end
	end

	error("more than 1 hook type not implemented yet")
end



local function CreateRawTableChain(tableCount)

	local str = {}

	for z=tableCount,1,-1 do
		str[#str+1] = string.format("tbl[%i](self,", i)
	end

	str[#str+1] = "..."

	for z=1,tableCount do
		str[#str+1] = ")"
	end

	return table.concat(str, "")
end

local function CreateTblPassingString(entryCoount)

	local str = {}

	for z=entryCoount,1,-1 do
		str[#str+1] = string.format("tbl[%i](...) ", i)
	end

	return table.concat(str, "")
end

--TODO add exception handling 
function DispatchBuilder.FallbackDispatcher(hookData, ...)

	local retvalue
	
	if(hookData.Raw) then
		retvalue = hookData.Orignal(DispatcherI[#hookData](hookData, RawDispatcherI[#hookData.Raw](...)))
	else 
		retvalue = hookData.Orignal(DispatcherI[#hookData](hookData, ...))
	end

	if(hookData.Post) then
		for _,hook in ipairs(hookData.Post) do
			hook(...)
		end
	end

	local retvalue = hookData.ReturnValue or retval
	 hookData.ReturnValue = nil
	
 return retvalue
end

function DispatchBuilder.ErrorHandler(err)
	Shared.Message(err)
end

--note luaJITs xpcall can take extra arguments to pass to the function being called
function DispatchBuilder.DebugDispatcher(hookData, ...)

	local args = {...}
	local success

	if(hookData.Raw) then
		local self = select(1, ...)
		
		for _,hook in ipairs(hookData.Raw) do
			local args2 = {xpcall(hook, DispatchBuilder.ErrorHandler, unpack(args))}
			
			--check to see if the captured success return value is true
			if(args2[1] == true) then
				args2[1] = self
				args = args2
			end
		end
	end

	if(#hookData ~= 0) then
		for _,hook in ipairs(hookData) do
			xpcall(hook, DispatchBuilder.ErrorHandler, unpack(args))
		end
	end
	
	hookData.ReturnValue = hookData.Orignal(unpack(args))
	
	if(hookData.Post) then
		for _,hook in ipairs(hookData.Post) do
			xpcall(hook, DispatchBuilder.ErrorHandler, unpack(args))
		end
	end
	
	local retvalue = hookData.ReturnValue
	hookData.ReturnValue = nil
	
	if(retvalue == FakeNil) then
		retvalue = nil
	end
	
	return retvalue
end

function CreateCustom(hookData)
	
	local funcbody = {[[
		local normalDispatcher = DispatcherI[#hookData]
			return function(hookDataArg, ...)
	]]}

	if(hookData.Raw and #hookData) then
		funcbody[#funcbody+1] = [[
				local tbl = hookDataArg.Raw
		]]
		

		funcbody[#funcbody+1] = [[local retvalue = hookDataArg.Orignal(normalDispatcher(hookDataArg, ]]

		funcbody[#funcbody+1] = CreateRawTableChain(#hookData.Raw)
		funcbody[#funcbody+1] = "))\n"
	else
		if(#hookData) then
			--funcbody[#funcbody+1] = CreateTblPassingString(#hookData)
			
			funcbody[#funcbody+1] = [[
				for _,hook in ipairs(hookData) do
					hook(...)
				end
			]]
		elseif(hookData.Raw) then
			funcbody[#funcbody+1] = [[
				local tbl = hookData.Raw
			]]
			funcbody[#funcbody+1] = CreateRawTableChain(#hookData.Raw)
			funcbody[#funcbody+1] = ")\n"
		end
	end
	
	if(hookData.Post) then
		funcbody[#funcbody+1] = [[
			for _,hook in ipairs(hookDataArg.Post) do
				hook(...)
			end
		]]
	end
	
	funcbody[#funcbody+1] = [[
		if(hookDataArg.ReturnValue) then
			retvalue = hookDataArg.ReturnValue
			hookDataArg.ReturnValue = nil
			
			if(retvalue == FakeNil) then
				retvalue = nil
			end
		end
	
	 return retvalue
	end
	]]
end

local DispatcherI = {
	[0] = function(...) return ... end,
	function (tbl, ...) tbl[1](...) end,
	function (tbl, ...) tbl[1](...) tbl[2](...) end,
	function (tbl, ...) tbl[1](...) tbl[2](...) tbl[3](...) end,
}

setmetatable(DispatcherI, {
	__index = function(self, i)
		local func = loadstring("function (tbl, ...) " .. CreateRawTblPassingString(i).." \n return ... end")()
		 rawset(self, i, func)
		
		return func
	end
})

local RawDispatcherI = {
	[0] = function(...) return ... end,
	function (tbl, self, ...) return tbl[1](self, ...) end,
	function (tbl, self, ...) return tbl[2](self, tbl[1](self, ...)) end,
	function (tbl, self, ...) return tbl[3](self, tbl[2](self, tbl[1](self, ...))) end,
}

setmetatable(RawDispatcherI, {
	__index = function(self, i)
		local func = loadstring("return function (tbl, self, ...) return " .. CreateRawTblPassingString(i).."end")()
		 rawset(self, i, func)
		
		return func
	end
})