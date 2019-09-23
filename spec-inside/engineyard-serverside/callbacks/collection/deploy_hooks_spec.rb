require 'spec_helper'

require 'pathname'

require 'engineyard-serverside/callbacks/collection'

module EY
  module Serverside
    module Callbacks
      module Collection

        describe DeployHooks do
          
          let(:paths) {Object.new}
          let(:app_base_path) {Pathname.new('/data/some_app')}
          let(:deploy_hooks_path) {
            app_base_path.join('releases', 'TIMESTAMP', 'deploy')
          }

          let(:hook_1_path) {deploy_hooks_path.join('hook_1.rb')}
          let(:hook_2_path) {deploy_hooks_path.join('hook_2.rb')}
          let(:hook_paths) {[hook_1_path.to_s, hook_2_path.to_s]}

          let(:collection) {described_class.load(paths)}

          before(:each) do
            allow(paths).to receive(:deploy_hooks).and_return(deploy_hooks_path)
            allow(Dir).to receive(:[]).and_return([])
          end

          describe '.load' do
            let(:result) {described_class.load(paths)}

            context 'with application hooks present' do
              before(:each) do
                allow(Dir).
                  to receive(:[]).
                  with("#{deploy_hooks_path}/*").
                  and_return(hook_paths)
              end

              it 'loads those application hooks' do
                expect(Hooks::App).to receive(:new).with(hook_1_path.to_s)
                expect(Hooks::App).to receive(:new).with(hook_2_path.to_s)

                result
              end
            end

            it 'is a callbacks collection' do
              expect(result).to be_a(Collection::Base)
            end
          end

          describe '#all' do
            let(:result) {collection.all}

            before(:each) do
              allow(Dir).
                to receive(:[]).
                with("#{deploy_hooks_path}/*").
                and_return(hook_paths)
            end

            it 'is an Array' do
              expect(result).to be_a(Array)
            end

            it 'contains all of the hooks detected at load time' do
              hook_paths.each do |path|
                expect(
                  result.select {|h| h.path == Pathname(path)}.length
                ).to eql(1)
              end
            end
          end

          describe '#matching' do
            let(:name) {:hook_2}
            let(:result) {collection.matching(name)}

            before(:each) do
              allow(Dir).
                to receive(:[]).
                with("#{deploy_hooks_path}/*").
                and_return(hook_paths)
            end

            it 'is an Array' do
              expect(result).to be_a(Array)
            end

            it 'contains hooks with the desired name' do
              expect(
                result.select {|h| h.path == Pathname(hook_2_path)}.length
              ).to eql(1)
            end

            it 'omits hooks without the desired name' do
              expect(
                result.select {|h| h.path == Pathname(hook_1_path)}.length
              ).to eql(0)
            end

            context "when a hook is represented by more than one format" do
              let(:hook_1_path) {deploy_hooks_path.join('hook_2')}
              let(:hook_2_path) {deploy_hooks_path.join('hook_2.rb')}

              it 'contains the ruby hook' do
                expect(
                  result.select {|h| h.path == Pathname(hook_2_path)}.length
                ).to eql(1)
              end

              it 'omits the other hooks' do
                expect(
                  result.select {|h| h.path == Pathname(hook_1_path)}.length
                ).to eql(0)
              end
            end
          end

          describe '#distribute' do
            let(:runner) {Object.new}
            let(:name) {:hook_2}
            let(:distributor) {Callbacks::Distributor}
            let(:distribution_result) {Object.new}
            let(:matched) {Object.new}
            let(:result) {collection.distribute(runner, name)}

            before(:each) do
              allow(Dir).
                to receive(:[]).
                with("#{deploy_hooks_path}/*").
                and_return(hook_paths)

              allow(collection).
                to receive(:matching).
                with(name).
                and_return(matched)

              allow(distributor).to receive(:distribute)
            end

            it 'distributes matching hooks via an distributor' do
              expect(distributor).
                to receive(:distribute).
                with(runner, matched).
                and_return(distribution_result)

              expect(result).to eql(distribution_result)
            end

            it 'skips non-matching hooks' do
              expect(distributor).not_to receive(:distribute).with(runner, :hook_1)

              result
            end
          end
        end

      end
    end
  end
end
