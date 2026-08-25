
-- BEGIN OMARCHY QEMU PROFILE
-- QEMU publishes the live window's size and host refresh rate through Virtio
-- GPU EDID. Quattro's preceding automatic monitor rule stays authoritative;
-- hide the guest cursor because the host composites it outside the guest
-- scanout.
local function omarchy_kernel_option_enabled(expected_option)
  if type(io) ~= "table" or type(io.open) ~= "function" then
    return false
  end

  local opened, cmdline_file = pcall(io.open, "/proc/cmdline", "r")
  if not opened or not cmdline_file then
    return false
  end

  local read_ok, cmdline = pcall(cmdline_file.read, cmdline_file, "*a")
  pcall(cmdline_file.close, cmdline_file)
  if not read_ok or type(cmdline) ~= "string" then
    return false
  end

  for option in cmdline:gmatch("%S+") do
    if option == expected_option then
      return true
    end
  end
  return false
end

if omarchy_kernel_option_enabled("omarchy.qemu=1") then
  hl.config({ cursor = { invisible = true } })
  o.exec_on_start("/usr/local/bin/omarchy-native-display-sync")
end
-- END OMARCHY QEMU PROFILE
