local vfsrt = {};
---
--DO NOT Require this file.
--It provides limited functionality outside of being a daemon for vfs
--If you wish to access the vfsrt API for the purposes of direct file manipulation
--A copy can be obtained using fs.getVFSRT()

local __realfs = fs;

local chrootAction;
local getMountNode;
local getmount;
local getlocalpath;

local function handleAction(node,supplier,...)
  if node.__chroot then
    return handleAction(node.__chroot,supplier,...);
  end
  do
    local __parent= node.__parent;
    local __path = node.__name;
    while not __parent.__mount do
      __path = __parent.name..'/'..__path;
      __parent = __parent.__parent;
      if __parent.__chroot then
        if __parent.__chroot then
          return handleAction(node,chrootAction(__parent.__chroot,supplier),...);
        end
      end
    end
    
    return (supplier(__parent.__mount))(__path,...);
  end
end

function vfsrt.getnode(root,path)
  if root.__children[path] then
    return root.__children[path];
  else
    local node = setmetatable({},
    {__tostring=function(t)
      return t.__parent..t.__name;
    end});
    node.__parent = root;
    if handleAction(node,(function(handler) return handler.exists end)) then
      node.__stat = {directory=handleAction(node,(function(handler) return handler.isDir end)),writeable=node.__parent.writeable};
      node.__parent.__children[path] = node;
    end
    return node;
  end
end

function vfsrt.__getRealFS()
  return __realfs;
end

local function rootnode()
  local node = setmetatable({},{__tostring=function()return '/'; end});
  node.__children = {};
  node.__parent = node;
  node.__children["."] = node;
  node.__children[".."] = node;
  node.__name = '';
  node.__stat = {directory=true,writeable=true};
  return node;
end

local function checkInvalid(handler)
  return function(path)
    return handler.isInvalid and handler.isInvalid(path);
  end
end

local function enumerate(node)
  local mount = getMountNode(node);
  for i,v in ipairs(handleAction(node,function(handler) return handler.list end)) do
    vfsrt.toNode(v,mount);
  end
end

function vfsrt.list(node)
  if not node.__stat then
    return nil,"Cannot stat "..node.." no such file or directory";
  elseif not node.__stat.directory then
    return {};
  end
  if handleAction(node,checkInvalid) then
    enumerate(node);
  end
  local list = {};
  for k,_ in pairs(node.__children) do
    table.insert(list,k);
  end
  table.sort(list);
  return list;
end



function vfsrt.mount(node,handler)
  if not node.__stat then
    return nil,"Cannot stat "..node.." no such file or directory";
  elseif not node.__stat.directory then
    return nil,"Cannot mount "..node.." not a directory";
  end
  node.__mount = handler;
  node.__children = {};
  node.__children['.'] = node;
  node.__children['..'] = node.__parent;
  node.__stat.writeable = not handler.isReadOnly("");
  return node;
end

function vfsrt.mknod(node,handler)
  if not node.__parent.__stat then
    return nil,"Cannot create device file "..node..": no such file or directory";
  elseif not node.__parent.__stat.writeable then
    return nil,"Cannot create device file "..node..": parent isn't writeable";
  elseif node.__stat then
    return nil,"Cannot create device file "..node..": file exists";
  
  else
    local handle = vfsrt.open(vfsrt.getnode(getMountNode(node),"$$ccvfs-devices"),"a");
    handle:write(handleAction(node,getlocalpath).."\n");
    handle:close();
    node.__mount = handler;
    node.__parent.__children[node.__name] = node;
    node.__stat = {writeable=(not handler.isReadOnly()),device=true};
  end
end

local function getmount(handler)
  return function(path) return handler end
end

local function getlocalpath()
  return function(path) return path end
end

function vfsrt.copy(node,toNode)
  if toNode.__stat then
    return nil,"Cannot copy "..node.." to "..toNode..": file exists";
  elseif not node.__stat then
    return nil,"Cannot stat "..node.. ": no such file or directory";
  elseif not toNode.__parent.__stat then
    return nil,"Cannot create "..toNode..": no such file or directory";
  elseif not toNode.__parent.__stat.__writeable then
    return nil,"Cannot create "..toNode..": parent not writeable";
  elseif not node.__stat.directory then
    local handle = vfsrt.open(node,"rb");
    local toHandle = vfsrt.open(toNode,"wb");
    repeat
      local byte = handle:read();
      local _ = (byte and toHandle:write(byte));
    until byte == nil
    toHandle:close();
    handle:close();
    return node;
  else
    vfsrt.mkdir(toNode);
    for i,v in vfsrt.list(node) do
      vfsrt.copy(v,vfsrt.getnode(toNode,v.__name));
    end
  end
end

function vfsrt.rename(node,newName,newParent)
  local newNode = vfsrt.getnode(newParent,newName);
  if newParent.__children[newName] then
    return nil,"Cannot rename "..node.." to "..newParent.__children[newName]..": file exists";
  elseif not node.__parent.__stat.writeable or not newParent.__stat.writeable then
    return nil,"Cannot rename "..node.." to "..newNode..": source or destination directory not writeable";
  end
  
  if node.__mount or handleAction(node,getmount) == handleAction(newNode,getmount) then
    local newPath = handleAction(newNode,getlocalpath);
    if not node.__mount then
      handleAction(node,function(handle) return handle.move end,newPath);
    end
    node.__parent.__children[node.__name] = nil;
    node.__parent = newParent;
    node.__name = newName;
    newParent.__children[newName] = node;
    return node;
  elseif node.__stat.directory then
    vfsrt.mkdir(newParent);
    for i,v in ipairs(vfsrt.list(node)) do
      vfsrt.rename(v,v.__name,newParent);
    end
  else
    vfsrt.copy(node,newNode);
    vfsrt.unlink(node);
  end
end

function vfsrt.open(node,mode)
  if not node.__parent.__stat then
    return nil,"Cannot open "..node..": no such file or directory";
  elseif node.__stat and node.__stat.directory then
    return nil,"Cannot open "..node..": is directory";
  elseif mode:find("w") then
    node.__stat = node.__stat or {writeable=node.__parent.writeable};
    if not node.__stat.writeable then
      return nil,"Cannot open "..node.." for writing: node is not writeable";
    end
  end
  if node.__mount then
    return node.__mount.open(mode);
  end
  return handleAction(node,function(handler) return handler.open end,mode);
end

function vfsrt.stat(node)
  if not node.__stat then
    return nil,"Cannot stat "..node.." no such file or directory";
  end
  return setmetatable({},{__index=node.__stat,__newindex=function() return error"Cannot modify stat table" end});
end

function vfsrt.mkdir(node)
  if node.__parent.__children[node.__name] then
    return nil,"Cannot create directory "..node..": file exists";
  elseif not node.__parent.__stat then
    return nil,"Cannot stat "..node.__parent..": no such file or directory";
  elseif not node.__parent.__stat.writeable then
    return nil,"Cannot create directory "..node..": parent isn't writeable";
  else
    node.__parent.__children[node.__name] = node;
    node.__stat = {writeable=true,directory=true};
    node.__children = node.__children or {};
    node.__children['.'] = node;
    node.__children['..'] = node.__parent;
    handleAction(node,function(handler) return handler.mkdir end);
    return node;
  end
end

function vfsrt.unlink(node)
  if not node.__stat then
    return nil,"Cannot stat "..node.." no such file or directory";
  elseif node.__stat.directory and #node.__children ~= 2 then
    return nil,"Cannot remove non-empty directory "..node;
  end
  if not node.__parent.__stat.writeable then
    return nil,"Cannot unlink "..node.." from parent: Not writeable";
  end
  node.__parent.__children[node.__name] = nil; --Orphan the node
  node.__stat = nil; 
  handleAction(node,function(handler) return handler.delete end);
  return true;
end

local rootNode = vfsrt.rootnode();

function vfsrt.getRootMount()
  return rootNode;
end

function vfsrt.size(node)
   if not node.__stat then
    return nil,"Cannot stat "..node.." no such file or directory";
   elseif node.__stat.directory then
    return nil,"Cannot get size of "..node..": is directory";
   elseif node.__mount then
    return node.__mount.getSize();
   else
    return handleAction(node,function(handler)return handler.getSize end);
   end
end

function vfsrt.makeReadOnly(node)
  if not node.__stat then
    return nil,"Cannot stat "..node.." no such file or directory";
  else
    node.__stat.writeable = false;
    return node;
  end
end

function vfsrt.exists(node)
  return not not node.__stat
end

function vfsrt.toNode(path, root)
  root = root or rootNode;
  if path == "" or path == "/" then
    return root;
  else
    return vfsrt.getNode(vfsrt.toNode(__realfs.getDir(path),root),__realfs.getName(path));
  end
end

local function chrootAction(chrootnode,supplier)
  return function(path,...)
    return handleAction(chrootnode,function(handler)
      return (function(basePath,...)
        return (suppler(handler))(__realfs.combine(basePath,path),...);
      end)
    end,...);
  end
end

function vfsrt.chroot(node)
  local _chroot = {};
  _chroot.__stat = node.__stat;
  _chroot.__parent = _chroot;
  _chroot.__children = {};
  _chroot.__children['.'] = _chroot;
  _chroot.__children['..'] = _chroot;
  _chroot.__chroot = node;
end

function vfsrt.ln(node,to)
  if node.__stat then
    return nil,"Cannot link "..node.." to "..to..": file exists";
  elseif not node.__parent.__stat then
    return nil,"Cannot create hard link "..to..": no such file or directory";
  elseif not node.__parent.__writeable then
    return nil,"Cannot create hard link "..to..": parent not writeable";
  else
    
  end
end

function vfsrt.getMountName(node)
  return handleAction(node,function(handler) return handler.getDrive end);
end

local function getMountNode(node)
  if node.__mount then
    return node;
  else
    return getMountNode(node.__parent);
  end
end




return vfsrt;