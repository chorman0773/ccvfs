
local vfsrt = require("internal-apis.vfs-rt");

local root = vfsrt.getRootMount();

local function _delete(node)
  if not node.__stat then
    return
  elseif not node.__stat.__directory then
    vfsrt.unlink(node)
  else
    for name,n in pairs(node.__children) do
      if name ~= "." or name ~= ".." then --Ignore . and ..
        _delete(n);
      end
    end
  end
end

local function _chroot(node)
  local fsbind = {};
  node = node==root and node or vfsrt.chroot(node); --No need to chroot to /
  function fsbind.chroot(path)
    return _chroot(vfsrt.toNode(path,node));
  end
  function fsbind.open(path,mode)
    return vfsrt.open(vfsrt.toNode(path,node),mode);
  end
  function fsbind.mknod(path,handler)
     return vfsrt.mknod(vfsrt.toNode(path,node),handler);
  end
  function fsbind.getVFSRT()
    return vfsrt;
  end
  function fsbind.delete(path)
    _delete(vfsrt.toNode(path,node));
  end
  function fsbind.exists(path)
    return vfsrt.exists(vfsrt.toNode(path,node));
  end
  function fsbind.getDir(path)
    return tostring(vfsrt.toNode(path,node).__parent);
  end
  function fsbind.getDrive(path)
    return vfsrt.getMountName(vfsrt.toNode(path,node));
  end
  function fsbind.getName(path)
    return vfsrt.toNode(path,node).__name;
  end
  return fsbind;
end

_G.fs = _chroot(root);


