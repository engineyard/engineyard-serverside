
module Capissh
  class Command
    class Tree
      attr_reader :configuration
      attr_reader :branches
      attr_reader :fallback

      include Enumerable

      class Branch
        attr_accessor :command, :callback
        attr_reader :options

        def initialize(command, options, callback)
          @command = command.strip.gsub(/\r?\n/, "\\\n")
          @callback = callback || Capissh::Command.default_io_proc
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
        attr_accessor :configuration
        attr_accessor :condition

        class Evaluator
          attr_reader :configuration, :condition, :server

          def initialize(config, condition, server)
            @configuration = config
            @condition = condition
            @server = server
          end

          def in?(role)
            configuration.roles[role].include?(server)
          end

          def result
            eval(condition, binding)
          end

          def method_missing(sym, *args, &block)
            if server.respond_to?(sym)
              server.send(sym, *args, &block)
            elsif configuration.respond_to?(sym)
              configuration.send(sym, *args, &block)
            else
              super
            end
          end
        end

        def initialize(configuration, condition, command, options, callback)
          @configuration = configuration
          @condition = condition
          super(command, options, callback)
        end

        def match(server)
          Evaluator.new(configuration, condition, server).result
        end

        def to_s
          "#{condition.inspect} :: #{command.inspect}"
        end
      end

      def initialize(config)
        @configuration = config
        @branches = []
        yield self if block_given?
      end

      def when(condition, command, options={}, &block)
        branches << ConditionBranch.new(configuration, condition, command, options, block)
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

      def each
        branches.each { |branch| yield branch }
        yield fallback if fallback
        return self
      end
    end
  end
end
