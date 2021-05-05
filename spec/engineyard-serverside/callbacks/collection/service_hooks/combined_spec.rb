require 'spec_helper'

require 'pathname'

require 'engineyard-serverside/callbacks/collection/service_hooks/combined'

module EY
  module Serverside
    module Callbacks
      module Collection
        module ServiceHooks

          describe Combined do
            let(:paths) {Object.new}
            let(:app_base_path) {Pathname.new('/data/someapp')}
            let(:shared_hooks_path) {app_base_path.join('shared', 'hooks')}
            let(:service_1_path) {shared_hooks_path.join('svc1')}
            let(:service_2_path) {shared_hooks_path.join('svc2')}
            let(:service_paths) {[service_1_path.to_s, service_2_path.to_s]}

            let(:service_1_hook_1) {Object.new}
            let(:service_1_hook_2) {Object.new}
            let(:service_2_hook_1) {Object.new}
            let(:service_2_hook_2) {Object.new}

            let(:service_1_collection) {Object.new}
            let(:service_2_collection) {Object.new}

            let(:collection) {described_class.load(paths)}

            before(:each) do
              allow(paths).
                to receive(:shared_hooks).
                and_return(shared_hooks_path)

              allow(Dir).to receive(:[]).and_return([])
              allow(Dir).
                to receive(:[]).
                with("#{shared_hooks_path}/*").
                and_return(service_paths)

              # Stub out a collection for service 1
              allow(ServiceHooks::Collection).
                to receive(:load).
                with(service_1_path.to_s).
                and_return(service_1_collection)

              allow(service_1_collection).
                to receive(:all).
                and_return([service_1_hook_1, service_1_hook_2])

              allow(service_1_collection).
                to receive(:matching).
                and_return([service_1_hook_2])

              # Stub out a collection for service 2
              allow(ServiceHooks::Collection).
                to receive(:load).
                with(service_2_path.to_s).
                and_return(service_2_collection)

              allow(service_2_collection).
                to receive(:all).
                and_return([service_2_hook_1, service_2_hook_2])

              allow(service_2_collection).
                to receive(:matching).
                and_return([service_2_hook_1])
            end

            describe '.load' do
              let(:service_hooks) {Object.new}
              let(:result) {described_class.load(paths)}

              context 'with service hooks present' do
                it 'loads a collection for each service' do
                  service_paths.each do |path|
                    expect(ServiceHooks::Collection).
                      to receive(:load).
                      with(path)
                  end

                  result
                end
              end

              it 'is a callbacks collection' do
                expect(result).to be_a(Callbacks::Collection::Base)
              end
            end

            describe '#all' do
              let(:all_known_hooks) {
                [
                  service_1_hook_1,
                  service_1_hook_2,
                  service_2_hook_1,
                  service_2_hook_2
                ]
              }

              let(:result) {collection.all}

              it 'is an Array' do
                expect(result).to be_a(Array)
              end

              it 'contains all known service hooks' do
                all_known_hooks.each do |hook|
                  expect(result).to include(hook)
                end
              end
            end

            describe '#matching' do
              let(:name) {:hook_2}
              let(:result) {collection.matching(name)}

              it 'is an Array' do
                expect(result).to be_a(Array)
              end

              it 'contains hooks with the desired name' do
                [service_1_hook_2, service_2_hook_1].each do |hook|
                  expect(result).to include(hook)
                end
              end

              it 'omits hooks without the desired name' do
                [service_1_hook_1, service_2_hook_2].each do |hook|
                  expect(result).not_to include(hook)
                end
              end
            end

            describe '#distribute' do
              let(:runner) {Object.new}
              let(:name) {:hook_2}
              let(:distributor) {Callbacks::Distributor}
              let(:distribution_result) {Object.new}
              let(:matched) {[service_1_hook_2, service_2_hook_1]}
              let(:result) {collection.distribute(runner, name)}

              before(:each) do
                allow(distributor).to receive(:distribute)

                # Bypass Base#minimize_ruby
                allow(collection).to receive(:minimize_ruby) {|matches|
                  matches
                }
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
end
