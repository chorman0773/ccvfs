
local vfsrt = dofile("internal-apis/vfs-rt.lua");

local root = vfsrt.getRootMount();

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
    vfsrt.mknod(vfsrt.toNode(path,node),handler);
  end
  function fsbind.getVFSRT()
    return vfsrt;
  end
  
end

_G.fs = _chroot(root);


