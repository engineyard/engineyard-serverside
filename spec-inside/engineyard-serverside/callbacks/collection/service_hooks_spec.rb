require 'spec_helper'

require 'pathname'

require 'engineyard-serverside/callbacks/collection'

module EY
  module Serverside
    module Callbacks
      module Collection

        describe ServiceHooks do
          let(:paths) {Object.new}

          describe '.load' do
            let(:combined) {Object.new}
            let(:result) {described_class.load(paths)}

            it 'is a combined service hooks collection' do
              expect(described_class::Combined).
                to receive(:load).with(paths).and_return(combined)

              expect(result).to eql(combined)
            end
          end
        end

      end
    end
  end
end


require 'spec_helper'

require 'pathname'

require 'engineyard-serverside/callbacks/collection'

module EY
  module Serverside
    module Callbacks

      describe Collection do
        let(:paths) {Object.new}
        let(:deploy_hooks) {described_class::DeployHooks}
        let(:service_hooks) {described_class::ServiceHooks}

        before(:each) do
          allow(deploy_hooks).
            to receive(:load).
            with(paths)

          allow(service_hooks).
            to receive(:load).
            with(paths)
        end

        describe '.load' do
          let(:result) {described_class.load(paths)}

          it 'loads deploy hooks' do
            expect(deploy_hooks).to receive(:load).with(paths)

            result
          end

          it 'loads service hooks' do
            expect(service_hooks).to receive(:load).with(paths)

            result
          end

          it 'is a combined callbacks collection' do
            expect(result).to be_a(described_class::Combined)
          end
        end
      end

    end
  end
end
