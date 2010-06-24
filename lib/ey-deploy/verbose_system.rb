module EY
  module VerboseSystem
    def system(cmd)
      puts "::   running #{cmd}"
      super
    end
  end
end
