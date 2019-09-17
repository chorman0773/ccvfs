--inject_vfs.lua

package.path = "/global-apis/?.lua;/global-apis/?;"..package.path;
shell.setPath("/commands;"..shell.getPath());
dofile("/global-apis/fsbind.lua");

