require 'spec_helper'


require 'engineyard-serverside/shell/yieldio'

module EY
  module Serverside
    class Shell

      describe YieldIO do
        let(:yieldio) {described_class.new {|str| str.reverse}}

        describe '#<<' do
          let(:input) {'123'}
          let(:result) {yieldio << input}
          let(:block) {yieldio.instance_eval {@block}}

          it 'passes the input to the block' do
            expect(block).to receive(:call).with(input)

            result
          end

          it 'is the result of the block' do
            expect(result).to eql(input.reverse)
          end

        end
      end

    end
  end
end
