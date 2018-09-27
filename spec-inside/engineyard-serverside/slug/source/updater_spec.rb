require 'spec_helper'

require 'engineyard-serverside/slug/source/updater'

module EY
  module Serverside
    module Slug
      module Source

        describe Updater do
          let(:source_ref) {'i_am_a_reference'}
          let(:source_opts) {{}}
          let(:source_cache) {Object.new}
          let(:source_uri) {'https://whatever'}
          let(:source) {Object.new}
          let(:servers) {[]}
          let(:config) {Object.new}
          let(:shell) {Object.new}

          let(:input) {
            {:servers => servers, :config => config, :shell => shell}
          }

          let(:updater) {described_class.new(input)}

          before(:each) do
            allow(config).to receive(:source).and_return(source)
            allow(source).to receive(:uri).and_return(source_uri)
            allow(source).to receive(:source_cache).and_return(source_cache)
            allow(source).to receive(:opts).and_return(source_opts)
            allow(source).to receive(:ref).and_return(source_ref)
            allow(source_cache).to receive(:mkpath)
            allow(source_cache).to receive(:to_s).and_return('source_cache')
          end

          it 'is a Railway' do
            expect(updater).to be_a(Railway)
          end

          it 'has the exact steps for updating a source cache' do
            steps = described_class.steps.map {|s| s[:name]}

            expect(steps).to eql(
              [
                :create_source_cache,
                :determine_if_clone_needed,
                :clone_if_necessary,
                :prune_source_cache,
                :fetch_updates,
                :clean_local_branch,
                :calculate_requested_revision,
                :checkout_requested_revision,
                :sync_submodules,
                :update_submodules,
                :clean_source_cache
              ]
            )
          end

          describe '#update' do
            let(:update) {updater.update}

            it 'calls the railway' do
              expect(updater).to receive(:call).with(input)

              update
            end
          end

          describe '#create_source_cache' do
            let(:create_source_cache) {
              updater.send(:create_source_cache, input)
            }

            it 'creates the source cache on the file system' do
              expect(source_cache).to receive(:mkpath)

              create_source_cache
            end

            context 'when all is good' do
              it 'is a success' do
                expect(create_source_cache.success?).to eql(true)
              end
            end

            context 'when the mkdir fails' do
              before(:each) do
                allow(source_cache).to receive(:mkpath).and_raise("any error")
              end

              it 'is a failure' do
                expect(create_source_cache.failure?).to eql(true)
              end

              it 'has an error regarding the source cache creation failure' do
                expect(create_source_cache.error[:error]).to eql("Could not create #{source_cache}")
              end
            end
          end

          describe '#determine_if_clone_needed' do
            let(:determine) {updater.send(:determine_if_clone_needed, input)}

            before(:each) do
              allow(source_cache).to receive(:directory?).and_return(true)
              allow(updater).to receive(:run_and_output).and_return(source_uri)
            end

            it 'is always a success' do
              expect(determine.success?).to eql(true)
            end

            context 'when the source cache is not a directory' do
              before(:each) do
                allow(source_cache).to receive(:directory?).and_return(false)
              end

              it 'records that a clone is needed' do
                expect(determine.value[:clone_needed]).to eql(true)
              end
            end

            context 'when the source cache is a directory' do
              context 'but its remotes do not include the source URI' do
                before(:each) do
                  allow(updater).to receive(:run_and_output).and_return('')
                end

                it 'records that a clone is needed' do
                  expect(determine.value[:clone_needed]).to eql(true)
                end
              end

              context 'and its remotes include the source URI' do
                it 'records that a clone is not needed' do
                  expect(determine.value[:clone_needed]).to eql(false)
                end
              end
            end

          end

          describe '#clone_if_necessary' do
            let(:clone_input) {input}
            let(:clone_if_necessary) {
              updater.send(:clone_if_necessary, clone_input)
            }

            before(:each) do
              allow(updater).to receive(:run_and_success?).and_return(true)
            end

            it 'is a result' do
              expect(clone_if_necessary).to be_a(Result::Base)
            end

            context 'when no clone is needed' do
              let(:clone_input) {input.merge(:clone_needed => false)}

              it 'is skips cloning' do
                expect(updater).not_to receive(:run_and_success?)

                clone_if_necessary
              end

              it 'is a success' do
                expect(clone_if_necessary.success?).to eql(true)
              end

              it 'does not alter its input' do
                expect(clone_if_necessary.value).to eql(clone_input)
              end
            end

            context 'when a clone is needed' do
              let(:clone_input) {input.merge(:clone_needed => true)}

              it 'clones the repo' do
                expect(updater).to receive(:run_and_success?).and_return(true)

                clone_if_necessary
              end

              context 'but cloning fails' do
                before(:each) do
                  allow(updater).to receive(:run_and_success?).and_return(false)
                end

                it 'is a failure' do
                  expect(clone_if_necessary.failure?).to eql(true)
                end

                it 'contains an error regarding the clone failure' do
                  expect(clone_if_necessary.error[:error]).
                    to eql("Could not clone #{source_uri} to #{source_cache}")
                end
              end

              context 'and cloning succeeds' do
                it 'is a success' do
                  expect(clone_if_necessary.success?).to eql(true)
                end

                it 'does not modify its input' do
                  expect(clone_if_necessary.value).to eql(clone_input)
                end
              end
            end

          end

          describe '#prune_source_cache' do
            let(:prune) {updater.send(:prune_source_cache, input)}

            before(:each) do
              allow(updater).to receive(:run_and_success?).and_return(true)
            end

            it 'is a result' do
              expect(prune).to be_a(Result::Base)
            end

            context 'when pruning fails' do
              before(:each) do
                allow(updater).to receive(:run_and_success?).and_return(false)
              end

              it 'is a failure' do
                expect(prune.failure?).to eql(true)
              end

              it 'contains an error regarding the prune failure' do
                expect(prune.error[:error]).
                  to eql("Could not prune #{source_cache}")
              end
            end

            context 'when pruning succeeds' do
              it 'is a success' do
                expect(prune.success?).to eql(true)
              end

              it 'does not modify its input' do
                expect(prune.value).to eql(input)
              end
            end
          end

          describe '#fetch_updates' do
            let(:fetch) {updater.send(:fetch_updates, input)}

            before(:each) do
              allow(updater).to receive(:run_and_success?).and_return(true)
            end

            it 'is a result' do
              expect(fetch).to be_a(Result::Base)
            end

            context 'when fetch fails' do
              before(:each) do
                allow(updater).to receive(:run_and_success?).and_return(false)
              end

              it 'is a failure' do
                expect(fetch.failure?).to eql(true)
              end

              it 'includes an error regarding the fetch failure' do
                expect(fetch.error[:error]).
                  to eql("Could not fetch #{source_cache}")
              end
            end

            context 'when fetch succeeds' do
              it 'is a success' do
                expect(fetch.success?).to eql(true)
              end

              it 'does not modify its input' do
                expect(fetch.value).to eql(input)
              end
            end
          end

          describe '#clean_local_branch' do
            let(:clean_local_branch) {updater.send(:clean_local_branch, input)}

            before(:each) do
              allow(updater).to receive(:run_and_success?)
            end

            it 'is always a success' do
              expect(clean_local_branch.success?).to eql(true)
            end

            it 'does not modify its input' do
              expect(clean_local_branch.value).to eql(input)
            end

            it 'spawns a shell to clean the branch' do
              git = updater.git
              ref = updater.ref

              expect(updater).
                to receive(:run_and_success?).
                with("#{git} show-branch #{ref} > /dev/null 2>&1 && #{git} branch -D #{ref} > /dev/null 2>&1")

              clean_local_branch
            end
          end

          describe '#calculate_requested_revision' do
            let(:ref) {updater.ref}
            let(:git) {updater.git}
            let(:calculate) {updater.send(:calculate_requested_revision, input)}

            before(:each) do
              allow(Dir).to receive(:chdir).and_yield
              allow(updater).to receive(:run_and_success?).and_return(true)
            end

            it 'is always a success' do
              expect(calculate.success?).to eql(true)
            end

            it 'checks for the remote branch in the source cache' do
              expect(Dir).to receive(:chdir).and_yield
              expect(updater).
                to receive(:run_and_success?).
                with("#{git} show-branch origin/#{ref} > /dev/null 2>&1")

              calculate
            end

            context 'when the remote branch is found' do
              it 'records the remote branch as the requested branch' do
                expect(calculate.value[:requested_branch]).
                  to eql("origin/#{ref}")
              end
            end

            context 'when the remote branch is not found' do
              before(:each) do
                allow(updater).to receive(:run_and_success?).and_return(false)
              end

              it 'records the raw reference as the requested_branch' do
                expect(calculate.value[:requested_branch]).
                  to eql(ref)
              end
            end
          end

          describe '#checkout_requested_revision' do
            let(:ref) {updater.ref}
            let(:git) {updater.git}
            let(:checkout_input) {input.merge(:requested_branch => ref)}
            let(:checkout) {
              updater.send(:checkout_requested_revision, checkout_input)
            }

            before(:each) do
              allow(Dir).to receive(:chdir).and_yield
              allow(updater).to receive(:run_and_success?).and_return(false)
            end

            it 'is a result' do
              expect(checkout).to be_a(Result::Base)
            end

            context 'when the raw checkout command fails' do
              before(:each) do
                allow(updater).
                  to receive(:run_and_success?).
                  with("git checkout --force --quiet '#{ref}'").
                  and_return(false)
              end

              it 'tries to run the raw reset command' do
                expect(updater).
                  to receive(:run_and_success?).
                  with("git reset --hard --quiet '#{ref}'")

                checkout
              end

              context 'and the raw reset command fails' do
                before(:each) do
                  allow(updater).
                    to receive(:run_and_success?).
                    with("git reset --hard --quiet '#{ref}'").
                    and_return(false)
                end

                it 'is a failure' do
                  expect(checkout.failure?).to eql(true)
                end

                it 'contains an error regarding the checkout failure' do
                  expect(checkout.error[:error]).
                    to eql("Could not check out #{ref}")
                end
              end

              context 'but the raw reset command succeeds' do
                before(:each) do
                  allow(updater).
                    to receive(:run_and_success?).
                    with("git reset --hard --quiet '#{ref}'").
                    and_return(true)
                end

                it 'is a success' do
                  expect(checkout.success?).to eql(true)
                end

                it 'does not modify its input' do
                  expect(checkout.value).to eql(checkout_input)
                end
              end
            end

            context 'when the raw checkout command succeeds' do
              before(:each) do
                allow(updater).
                  to receive(:run_and_success?).
                  with("git checkout --force --quiet '#{ref}'").
                  and_return(true)
              end

              it 'skips the raw reset' do
                expect(updater).
                  not_to receive(:run_and_success?).
                  with("git reset --hard --quiet '#{ref}'")

                checkout
              end

              it 'is a success' do
                expect(checkout.success?).to eql(true)
              end

              it 'does not modify its input' do
                expect(checkout.value).to eql(checkout_input)
              end
            end

          end

          describe '#sync_submodules' do
            let(:ref) {updater.ref}
            let(:git) {updater.git}
            let(:sync) {
              updater.send(:sync_submodules, input)
            }

            before(:each) do
              allow(Dir).to receive(:chdir).and_yield
              allow(updater).to receive(:run_and_success?).and_return(false)
            end

            context 'when the sync command fails' do
              before(:each) do
                allow(updater).
                  to receive(:run_and_success?).
                  with('git submodule sync').
                  and_return(false)
              end

              it 'is a failure' do
                expect(sync.failure?).to eql(true)
              end

              it 'includes an error regarding the sync failure' do
                expect(sync.error[:error]).to eql('Could not sync submodules')
              end
            end

            context 'when the sync succeeds' do
              before(:each) do
                allow(updater).
                  to receive(:run_and_success?).
                  with('git submodule sync').
                  and_return(true)
              end

              it 'is a success' do
                expect(sync.success?).to eql(true)
              end

              it 'does not modify its input' do
                expect(sync.value).to eql(input)
              end
            end

          end

          describe '#update_submodules' do
            let(:ref) {updater.ref}
            let(:git) {updater.git}
            let(:update_submodules) {
              updater.send(:update_submodules, input)
            }

            before(:each) do
              allow(Dir).to receive(:chdir).and_yield
              allow(updater).to receive(:run_and_success?).and_return(false)
            end

            context 'when the update command fails' do
              before(:each) do
                allow(updater).
                  to receive(:run_and_success?).
                  with('git submodule update --init --recursive').
                  and_return(false)
              end

              it 'is a failure' do
                expect(update_submodules.failure?).to eql(true)
              end

              it 'includes an error regarding the sync failure' do
                expect(update_submodules.error[:error]).
                  to eql('Could not update submodules')
              end
            end

            context 'when the update succeeds' do
              before(:each) do
                allow(updater).
                  to receive(:run_and_success?).
                  with('git submodule update --init --recursive').
                  and_return(true)
              end

              it 'is a success' do
                expect(update_submodules.success?).to eql(true)
              end

              it 'does not modify its input' do
                expect(update_submodules.value).to eql(input)
              end
            end

          end

          describe '#clean_source_cache' do
            let(:ref) {updater.ref}
            let(:git) {updater.git}
            let(:clean) {
              updater.send(:clean_source_cache, input)
            }

            before(:each) do
              allow(Dir).to receive(:chdir).and_yield
              allow(updater).to receive(:run_and_success?).and_return(false)
            end

            context 'when the clean command fails' do
              before(:each) do
                allow(updater).
                  to receive(:run_and_success?).
                  with('git clean -dfq').
                  and_return(false)
              end

              it 'is a failure' do
                expect(clean.failure?).to eql(true)
              end

              it 'includes an error regarding the clean failure' do
                expect(clean.error[:error]).
                  to eql('Could not clean source')
              end
            end

            context 'when the clean succeeds' do
              before(:each) do
                allow(updater).
                  to receive(:run_and_success?).
                  with('git clean -dfq').
                  and_return(true)
              end

              it 'is a success' do
                expect(clean.success?).to eql(true)
              end

              it 'does not modify its input' do
                expect(clean.value).to eql(input)
              end
            end

          end


        end

      end
    end
  end
end
