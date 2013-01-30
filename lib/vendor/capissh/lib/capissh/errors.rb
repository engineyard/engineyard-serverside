module Capissh

  Error = Class.new(RuntimeError)

  CaptureError            = Class.new(Capissh::Error)
  NoSuchTaskError         = Class.new(Capissh::Error)
  NoMatchingServersError  = Class.new(Capissh::Error)

  class RemoteError < Error
    attr_accessor :hosts
  end

  ConnectionError     = Class.new(Capissh::RemoteError)
  TransferError       = Class.new(Capissh::RemoteError)
  CommandError        = Class.new(Capissh::RemoteError)

  LocalArgumentError  = Class.new(Capissh::Error)

end
