require 'railway'

module EY
  module Serverside
    module Callbacks
      module Distributor

        class ViabilityFilter
          include Railway

          step :normalize_input
          step :check_ruby_candidates
          step :check_executable_candidates
          step :calculate_callback_name

          def normalize_input(input = {})
            input[:viable] = []

            unless input[:candidates].respond_to?(:each)
              input[:candidates] = [input[:candidates]]
            end

            Success(input)
          end

          def check_ruby_candidates(input = {})
            hooks = input[:candidates].
              select {|hook| hook.flavor == :ruby}

            hooks.each do |hook|
              input[:viable].push(hook)
            end

            Success(input)
          end

          def check_executable_candidates(input = {})
            hooks = input[:candidates].
              select {|hook| hook.flavor == :executable}

            hooks.each do |hook|
              if hook.path.executable?
                input[:viable].push(hook)
              else
                input[:shell].warning(
                  "Skipping possible deploy hook #{hook} because it is not executable."
                )
              end
            end

            Success(input)
          end

          def calculate_callback_name(input = {})
            if input[:viable].empty?
              return Failure(input.merge({:reason => :no_viable_hooks}))
            end

            Success(input[:viable].first.callback_name)
          end
        end

      end
    end
  end
end
