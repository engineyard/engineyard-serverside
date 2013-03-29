module Capissh
  class CommandTree
    attr_reader :configuration
    attr_reader :branches
    attr_reader :fallback
    attr_reader :options

    include Enumerable

    class Branch
      attr_accessor :command, :callback
      attr_reader :options

      def initialize(command, options, callback)
        @command = command.strip.gsub(/\r?\n/, "\\\n")
        @callback = callback || Capissh::Command.default_io_callback
        @options = options
        @skip = false
      end

      def last?
        options[:last]
      end

      def skip?
        @skip
      end

      def skip!
        @skip = true
      end

      def match(server)
        true
      end

      def to_s
        command.inspect
      end
    end

    class ConditionBranch < Branch
      attr_accessor :condition

      class Evaluator
        attr_reader :condition, :server

        def initialize(condition, server)
          @condition = condition
          @server = server
        end

        def result
          eval(condition, binding)
        end

        def method_missing(sym, *args, &block)
          if server.respond_to?(sym)
            server.send(sym, *args, &block)
          else
            super
          end
        end
      end

      def initialize(condition, command, options, callback)
        @condition = condition
        super(command, options, callback)
      end

      def match(server)
        Evaluator.new(condition, server).result
      end

      def to_s
        "#{condition.inspect} :: #{command.inspect}"
      end
    end

    # A tree with only one branch.
    def self.twig(config, command, options={}, &block)
      new(config, options) { |t| t.else(command, &block) }
    end

    def initialize(config, options={})
      @configuration = config
      @options = options
      @branches = []
      yield self if block_given?
    end

    def when(condition, command, options={}, &block)
      branches << ConditionBranch.new(condition, command, options, block)
    end

    def else(command, &block)
      @fallback = Branch.new(command, {}, block)
    end

    def branches_for(server)
      seen_last = false
      matches = branches.select do |branch|
        success = !seen_last && !branch.skip? && branch.match(server)
        seen_last = success && branch.last?
        success
      end

      matches << fallback if matches.empty? && fallback

      return matches
    end

    def base_command_and_callback(server)
      branches_for(server).map do |branch|
        command = branch.command
        if configuration
          command = configuration.placeholder_callback.call(command, server)
        end
        command = compose_command(command, server)
        [command, branch.callback]
      end
    end

    def each
      branches.each { |branch| yield branch }
      yield fallback if fallback
      return self
    end

    def compose_command(command, server)
      command = command.strip.gsub(/\r?\n/, "\\\n")

      if options[:shell] == false
        shell = nil
      else
        shell = "#{options[:shell] || "sh"} -c"
        command = command.gsub(/'/) { |m| "'\\''" }
        command = "'#{command}'"
      end

      [environment, shell, command].compact.join(" ")
    end

    # prepare a space-separated sequence of variables assignments
    # intended to be prepended to a command, so the shell sets
    # the environment before running the command.
    # i.e.: options[:env] = {'PATH' => '/opt/ruby/bin:$PATH',
    #                        'TEST' => '( "quoted" )'}
    # environment returns:
    # "env TEST=(\ \"quoted\"\ ) PATH=/opt/ruby/bin:$PATH"
    def environment
      return if options[:env].nil? || options[:env].empty?
      @environment ||=
        if String === options[:env]
          "env #{options[:env]}"
        else
          options[:env].inject("env") do |string, (name, value)|
            value = value.to_s.gsub(/[ "]/) { |m| "\\#{m}" }
            string << " #{name}=#{value}"
          end
        end
    end
  end
end
