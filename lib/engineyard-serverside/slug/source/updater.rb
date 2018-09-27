require 'railway'
require 'runner'

module EY
  module Serverside
    module Slug
      module Source

        class Updater
          include Railway
          include Runner

          step :create_source_cache
          step :determine_if_clone_needed
          step :clone_if_necessary
          step :prune_source_cache
          step :fetch_updates
          step :clean_local_branch
          step :calculate_requested_revision
          step :checkout_requested_revision
          step :sync_submodules
          step :update_submodules
          step :clean_source_cache

          attr_reader :source_cache, :uri, :git, :quiet, :ref

          def initialize(input = {})
            @input = input
            source = input[:config].source
            @source_cache = source.source_cache
            @uri = source.uri
            @quiet = source.opts[:verbose] ? '' : '--quiet'
            @ref = source.ref
            @git = "git --git-dir #{source_cache}/.git --work-tree #{source_cache}"
          end

          def update
            call(@input)
          end

          private

          def create_source_cache(input = {})
            begin
              source_cache.mkpath
            rescue
              return Failure(:error => "Could not create #{source_cache}")
            end

            Success(input)
          end

          def determine_if_clone_needed(input = {})

            check = 
              source_cache.directory? &&
              run_and_output("#{git} remote -v | grep original").include?(uri)

            Success(input.merge(:clone_needed => !check))
          end

          def clone_if_necessary(input = {})
            if input[:clone_needed]
              unless run_and_success?("rm -rf #{source_cache} && git clone #{quiet} #{uri} #{source_cache} 2>&1")

                return Failure(
                  input.merge(:error => "Could not clone #{uri} to #{source_cache}")
                )
              end
            end

            Success(input)
          end

          def prune_source_cache(input = {})
            return Failure(
              input.merge(:error => "Could not prune #{source_cache}")
            ) unless run_and_success?("#{git} remote prune origin 2>&1")

            Success(input)
          end

          def fetch_updates(input = {})
            return Failure(
              input.merge(:error => "Could not fetch #{source_cache}")
            ) unless run_and_success?("#{git} fetch --force --prune --update-head-ok #{quiet} origin '+refs/heads/*:refs/remotes/origin/*' '+refs/tags/*:refs/tags/*' 2>&1")

            Success(input)
          end

          def clean_local_branch(input = {})
            run_and_success?("#{git} show-branch #{ref} > /dev/null 2>&1 && #{git} branch -D #{ref} > /dev/null 2>&1")

            Success(input)
          end

          def calculate_requested_revision(input = {})
            remote_branch = Dir.chdir(source_cache) do
              run_and_success?("#{git} show-branch origin/#{ref} > /dev/null 2>&1")
            end

            Success(
              input.merge(
                :requested_branch => remote_branch ? "origin/#{ref}" : ref
              )
            )
          end

          def checkout_requested_revision(input = {})
            requested_branch = input[:requested_branch]

            Dir.chdir(source_cache) {
              run_and_success?(
                "git checkout --force #{quiet} '#{requested_branch}'"
              ) || run_and_success?(
                "git reset --hard #{quiet} '#{requested_branch}'"
              )
            } ?
              Success(input) :
              Failure(
                input.merge(:error => "Could not check out #{requested_branch}")
              )
          end

          def sync_submodules(input = {})
            return Failure(
              input.merge(:error => "Could not sync submodules")
            ) unless Dir.chdir(source_cache) {
              run_and_success?('git submodule sync')
            }

            Success(input)
          end

          def update_submodules(input = {})
            return Failure(
              input.merge(:error => "Could not update submodules")
            ) unless Dir.chdir(source_cache) {
              run_and_success?('git submodule update --init --recursive')
            }

            Success(input)
          end

          def clean_source_cache(input = {})
            return Failure(
              input.merge(:error => "Could not clean source")
            ) unless Dir.chdir(source_cache) {
              run_and_success?('git clean -dfq')
            }

            Success(input)
          end

        end

      end
    end
  end
end
