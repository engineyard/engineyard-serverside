require 'spec_helper'

require 'pathname'

require 'railway'
require 'engineyard-serverside/callbacks/distributor/viability_filter'

module EY
  module Serverside
    module Callbacks
      module Distributor

        describe ViabilityFilter do
          let(:shell) {Object.new}
          let(:ruby_hook) {Object.new}
          let(:executable_hook) {Object.new}
          let(:executable_path) {Object.new}
          let(:hooks) {[ruby_hook, executable_hook]}
          let(:callback_name) {:some_callback}

          let(:filter) {described_class.new}

          before(:each) do
            allow(ruby_hook).to receive(:flavor).and_return(:ruby)
            allow(executable_hook).to receive(:flavor).and_return(:executable)
            hooks.each do |hook|
              allow(hook).to receive(:callback_name).and_return(callback_name)
            end

            allow(executable_hook).to receive(:path).and_return(executable_path)
            allow(executable_path).to receive(:executable?).and_return(false)

            allow(shell).to receive(:warning)
          end

          it 'is a Railway' do
            expect(filter).to be_a(Railway)
          end

          it 'has the exact steps for filtering hooks' do
            steps = described_class.steps.map {|s| s[:name]}

            expect(steps).to eql(
              [
                :normalize_input,
                :check_ruby_candidates,
                :check_executable_candidates,
                :calculate_callback_name
              ]
            )
          end

          describe '#normalize_input' do
            let(:candidates) {hooks}

            let(:input) {
              {
                :candidates => candidates,
                :shell => shell
              }
            }

            let(:result) {filter.normalize_input(input)}

            it 'is always a success' do
              expect(filter.normalize_input).to be_a(Result::Success)
            end

            it 'adds a viable array to the input hash' do
              expect(result.value[:viable]).to be_a(Array)
            end

            context 'when given a non-array candidate' do
              let(:candidates) {ruby_hook}

              it 'converts the candidate to an array' do
                expect(result.value[:candidates]).to eql([ruby_hook])
              end
            end
          end

          describe '#check_ruby_candidates' do
            let(:input) {
              {
                :candidates => hooks,
                :shell => shell,
                :viable => []
              }
            }

            let(:result) {filter.check_ruby_candidates(input)}

            it 'adds all ruby hooks to the viable array' do
              expect(result.value[:viable]).to include(ruby_hook)
            end

            it 'ignores non-ruby hooks' do
              expect(result.value[:viable]).not_to include(executable_hook)
            end

            it 'does not alter the candidates' do
              expect(result.value[:candidates]).to eql(hooks)
            end
          end

          describe '#check_executable_candidates' do
            let(:input) {
              {
                :candidates => hooks,
                :shell => shell,
                :viable => []
              }
            }

            let(:result) {filter.check_executable_candidates(input)}

            it 'ignores ruby hooks' do
              expect(result.value[:viable]).not_to include(ruby_hook)
            end

            it 'does not alter the candidates' do
              expect(result.value[:candidates]).to eql(hooks)
            end

            context 'with a hook that has the executable bit' do
              before(:each) do
                allow(executable_path).to receive(:executable?).and_return(true)
              end

              it 'adds that hook to the viable array' do
                expect(result.value[:viable]).to include(executable_hook)
              end
            end

            context 'with a hook that lacks the executable bit' do
              before(:each) do
                allow(executable_path).to receive(:executable?).and_return(false)
              end

              it 'warns the user that the hook is being skipped' do
                expect(shell).
                  to receive(:warning).
                  with(
                    "Skipping possible deploy hook #{executable_hook} because it is not executable."
                  )

                result
              end

              it 'omits that hook from the viable array' do
                expect(result.value[:viable]).not_to include(executable_hook)
              end
            end
          end

          describe '#calculate_callback_name' do
            let(:viable) {hooks}

            let(:input) {
              {
                :candidates => hooks,
                :shell => shell,
                :viable => viable
              }
            }

            let(:result) {filter.calculate_callback_name(input)}

            context 'with viable hooks' do
              let(:viable) {hooks}

              it 'is a Success' do
                expect(result).to be_a(Result::Success)
              end

              it 'has a callback name value' do
                expect(result.value).to eql(callback_name)
              end
            end

            context 'with no viable hooks' do
              let(:viable) {[]}

              it 'is a Failure' do
                expect(result).to be_a(Result::Failure)
              end

              it 'includes a failure reason' do
                expect(result.error[:reason]).to eql(:no_viable_hooks)
              end

              it 'does not modify the viable array' do
                expect(result.error[:candidates]).to eql(hooks)
              end

              it 'does not modify the candidates array' do
                expect(result.error[:viable]).to eql(viable)
              end
            end
          end

        end

      end
    end
  end
end

