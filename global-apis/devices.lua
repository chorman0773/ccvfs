local devices = {};

local devhandlers = {};

function devices.addDevice(name,devhandler)
  devhandlers[name] = devhandler;
end

function devices.getDevice(name)
  return devhandlers[name];
end

return devices;