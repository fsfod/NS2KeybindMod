
LoadTracker = {
	LoadStack = {},
	LoadedScripts = {},
	
	LoadedFileHooks = {},
}

local function NormalizePath(luaFilePath)

	local path = string.gsub(luaFilePath, "\\", "/")
	path = path:lower()
	
	if(string.byte(path) == '/') then
	 path =	path:sub(1)
	end

	return path
end

LoadTracker.NormalizePath = NormalizePath

local orignalLoad = Script.Load

Script.Load = function(scriptPath)
	
	local normPath = NormalizePath(scriptPath)
	
	LoadTracker:ScriptLoadStart(normPath)
		orignalLoad(scriptPath)
	LoadTracker:ScriptLoadFinished(normPath)
end

function LoadTracker:ScriptLoadStart(normalizedsPath)
	table.insert(self.LoadStack, normalizedsPath)
	
	--store the stack index so we can be sure were not reacting to a double load of the same file
	if(not self.LoadedScripts[normalizedsPath]) then
		self.LoadedScripts[normalizedsPath] = #self.LoadStack
	end
end

function LoadTracker:HookFileLoadFinished(scriptPath, selfTable, funcName)
	
	local path = NormalizePath(scriptPath)
	
	if(not self.LoadedFileHooks[path]) then
		self.LoadedFileHooks[path] = {{selfTable, selfTable[funcName]}}
	else
		table.insert(self.LoadedFileHooks[path], {selfTable, selfTable[funcName]})
	end
end

function LoadTracker:ScriptLoadFinished(normalizedsPath)

	--make sure that were not getting a nested double load of the same file
	if(self.LoadedScripts[normalizedsPath] == #self.LoadStack) then
		if(self.LoadedFileHooks[normalizedsPath]) then
			for _,hook in ipairs(self.LoadedFileHooks[normalizedsPath]) do
				hook[2](hook[1])
			end
		end
		
		if(ClassHooker) then
			ClassHooker:ScriptLoadFinished(normalizedsPath)
		end
		
		self.LoadedScripts[normalizedsPath] = true
	end

	table.remove(self.LoadStack)

end