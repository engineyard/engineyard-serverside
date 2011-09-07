# methods for String that aren't available in ruby 1.8.6 (used by ey_resin)
# versions here are just workarounds
# FIXME remove this module when ey_resin (and .rvmrc) updated to ruby 1.8.7 or 1.9.2
module ModernString
  def start_with?(prefix)
    self.index(prefix) == 0
  end
end
String.send(:include, ModernString)