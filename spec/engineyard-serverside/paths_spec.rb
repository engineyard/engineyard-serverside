require 'spec_helper'

require 'timecop'

require 'engineyard-serverside/paths'

module EY
  module Serverside

    describe Paths do
      let(:release_1) {Pathname.new('20200201001000')}
      let(:release_2) {Pathname.new('20200201002000')}
      let(:release_3) {Pathname.new('20200201003000')}
      let(:all_release_paths) {[release_1, release_2, release_3]}
      let(:home) {'/some/dir/home'}
      let(:app_name) {'some_app'}
      let(:active_release) {'/some/dir/active_release'}
      let(:repository_cache) {'/some/dir/repository_cache'}
      let(:deploy_root) {'/some/dir/deploy_root'}
      let(:opts) {{
        :home => home,
        :app_name => app_name,
        :active_release => active_release,
        :repository_cache => repository_cache,
        :deploy_root => deploy_root
      }}

      let(:now) {Time.utc(2020, 1, 15, 1, 27, 0)}

      let(:paths) {described_class.new(opts)}

      before(:each) do
        Timecop.freeze(now)

        # What say we avoid creating a bunch of files on the file system just
        # to test some of these methods?
        allow(Pathname).to receive(:glob).and_return(all_release_paths)
      end

      after(:each) do
        Timecop.return
      end

      describe '#home' do
        let(:result) {paths.home}

        it 'is a Pathmame' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the home opt provided at initializetion' do
          expect(result.to_s).to eql(home)
        end
      end

      describe '#deploy_root' do
        let(:result) {paths.deploy_root}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the deploy_root opt provided at initialization' do
          expect(result.to_s).to eql(deploy_root)
        end
      end

      describe '#internal_key' do
        let(:result) {paths.internal_key}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the internal ssh key within the home directory' do
          expect(result.to_s).to eql("#{home}/.ssh/internal")
        end
      end

      describe '#current' do
        let(:result) {paths.current}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the "current" directory under the deploy root' do
          expect(result.to_s).to eql("#{deploy_root}/current")
        end
      end

      describe '#releases' do
        let(:result) {paths.releases}

        it 'is a Pathanme' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the releases directory under the deploy root' do
          expect(result.to_s).to eql("#{deploy_root}/releases")
        end
      end

      describe '#releases_failed' do
        let(:result) {paths.releases_failed}

        it 'is a Pathanme' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the failed releases directory under the deploy root' do
          expect(result.to_s).to eql("#{deploy_root}/releases_failed")
        end
      end

      describe '#shared' do
        let(:result) {paths.shared}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the shared directory under the deploy root' do
          expect(result.to_s).to eql("#{deploy_root}/shared")
        end
      end

      describe '#shared_log' do
        let(:result) {paths.shared_log}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the log directory under the shared path' do
          expect(result.to_s).to eql("#{paths.shared}/log")
        end
      end

      describe '#shared_tmp' do
        let(:result) {paths.shared_tmp}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the tmp directory under the shared path' do
          expect(result.to_s).to eql("#{paths.shared}/tmp")
        end
      end

      describe '#shared_config' do
        let(:result) {paths.shared_config}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the config directory under the shared path' do
          expect(result.to_s).to eql("#{paths.shared}/config")
        end
      end

      describe '#shared_hooks' do
        let(:result) {paths.shared_hooks}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the hooks directory under the shared path' do
          expect(result.to_s).to eql("#{paths.shared}/hooks")
        end
      end

      describe '#shared_node_modules' do
        let(:result) {paths.shared_node_modules}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the node_modules directory under the shared path' do
          expect(result.to_s).to eql("#{paths.shared}/node_modules")
        end
      end

      describe '#shared_system' do
        let(:result) {paths.shared_system}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the system directory under the shared path' do
          expect(result.to_s).to eql("#{paths.shared}/system")
        end
      end

      describe '#default_repository_cache' do
        let(:result) {paths.default_repository_cache}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the cached-copy directory under the shared path' do
          expect(result.to_s).to eql("#{paths.shared}/cached-copy")
        end
      end

      describe '#enabled_maintenance_page' do
        let(:result) {paths.enabled_maintenance_page}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the maintenance.html file in the shared system path' do
          expect(result.to_s).to eql("#{paths.shared_system}/maintenance.html")
        end
      end

      describe '#shared_assets' do
        let(:result) {paths.shared_assets}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the assets directory under the shared path' do
          expect(result.to_s).to eql("#{paths.shared}/assets")
        end
      end

      describe '#bundled_gems' do
        let(:result) {paths.bundled_gems}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the bundled_gems directory under the shared path' do
          expect(result.to_s).to eql("#{paths.shared}/bundled_gems")
        end
      end

      describe '#shared_services_yml' do
        let(:result) {paths.shared_services_yml}

        it 'is a Pathmame' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the ey_services_config_deploy.yml file under the share config path' do
          expect(result.to_s).
            to eql("#{paths.shared_config}/ey_services_config_deploy.yml")
        end
      end

      describe '#ruby_version' do
        let(:result) {paths.ruby_version}

        it 'is a Pathanme' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the RUBY_VERSION file under the bundled gems path' do
          expect(result.to_s).to eql("#{paths.bundled_gems}/RUBY_VERSION")
        end
      end

      describe '#system_version' do
        let(:result) {paths.system_version}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the SYSTEM_VERSION file under the bundled gems path' do
          expect(result.to_s).to eql("#{paths.bundled_gems}/SYSTEM_VERSION")
        end
      end

      describe '#latest_revision' do
        let(:result) {paths.latest_revision}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the REVISION file under the latest release path' do
          expect(result.to_s).to eql("#{paths.latest_release}/REVISION")
        end
      end

      describe '#active_revision' do
        let(:result) {paths.active_revision}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the REVISION file under the active release path' do
          expect(result.to_s).to eql("#{paths.active_release}/REVISION")
        end
      end

      describe '#binstubs' do
        let(:result) {paths.binstubs}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the ey_bundler_binstubs directory under the active release paath' do
          expect(result.to_s).to eql("#{paths.active_release}/ey_bundler_binstubs")
        end
      end

      describe '#gemfile' do
        let(:result) {paths.gemfile}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the Gemfile file under the active release path' do
          expect(result.to_s).to eql("#{paths.active_release}/Gemfile")
        end
      end

      describe '#gemfile_lock' do
        let(:result) {paths.gemfile_lock}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the Gemfile.lock file under the active release path' do
          expect(result.to_s).to eql("#{paths.active_release}/Gemfile.lock")
        end
      end

      describe '#public' do
        let(:result) {paths.public}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the public directory under the active release path' do
          expect(result.to_s).to eql("#{paths.active_release}/public")
        end
      end

      describe '#deploy_hooks' do
        let(:result) {paths.deploy_hooks}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the deploy directory under the active release path' do
          expect(result.to_s).to eql("#{paths.active_release}/deploy")
        end
      end

      describe '#public_assets' do
        let(:result) {paths.public_assets}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the assets directory under the public path' do
          expect(result.to_s).to eql("#{paths.public}/assets")
        end
      end

      describe '#public_system' do
        let(:result) {paths.public_system}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the system directory under the public path' do
          expect(result.to_s).to eql("#{paths.public}/system")
        end
      end

      describe '#package_json' do
        let(:result) {paths.package_json}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the package.json file in the active relase path' do
          expect(result.to_s).to eql("#{paths.active_release}/package.json")
        end
      end

      describe '#composer_json' do
        let(:result) {paths.composer_json}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the composer.json file in the active release path' do
          expect(result.to_s).to eql("#{paths.active_release}/composer.json")
        end
      end

      describe '#composer_lock' do
        let(:result) {paths.composer_lock}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the composer.lock file in the active release path' do
          expect(result.to_s).to eql("#{paths.active_release}/composer.lock")
        end
      end

      describe '#active_release_config' do
        let(:result) {paths.active_release_config}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the config directory in the active release path' do
          expect(result.to_s).to eql("#{paths.active_release}/config")
        end
      end

      describe '#active_log' do
        let(:result) {paths.active_log}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the log directory in the active release path' do
          expect(result.to_s).to eql("#{paths.active_release}/log")
        end
      end

      describe '#active_node_modules' do
        let(:result) {paths.active_node_modules}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the node_modules directory under the active release path' do
          expect(result.to_s).to eql("#{paths.active_release}/node_modules")
        end
      end

      describe '#active_tmp' do
        let(:result) {paths.active_tmp}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the tmp directory under the active release path' do
          expect(result.to_s).to eql("#{paths.active_release}/tmp")
        end
      end

      describe '#release_dirname' do
        let(:result) {paths.release_dirname}

        it 'is the current timestamp' do
          expect(result).to eql(now.strftime('%Y%m%d%H%M%S'))
        end
      end

      describe '#new_release!' do
        let(:result) {paths.new_release!}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        context 'when the active release is known' do
          it 'resolves to the active release path' do
            expect(result.to_s).to eql(active_release)
          end
        end

        context 'when the active release is not known' do
          let(:active_release) {nil}

          it 'resolves to the current release dirname under the releases path' do
            expect(result.to_s).
              to eql("#{paths.releases}/#{paths.release_dirname}")
          end
        end
      end

      describe '#active_release' do
        let(:result) {paths.active_release}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        context 'when the active release is already known' do
          it 'resolves to that active release' do
            expect(result.to_s).to eql(active_release)
          end
        end

        context 'when the active release is not yet known' do
          let(:active_release) {nil}

          it 'resolves to the latest release' do
            expect(result).to eql(paths.latest_release)
          end
        end
      end

      describe '#deploy_key' do
        let(:result) {paths.deploy_key}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resovles to the deply key for the application' do
          expect(result.to_s).to eql("#{paths.home}/.ssh/#{app_name}-deploy-key")
        end
      end

      describe '#ssh_wrapper' do
        let(:result) {paths.ssh_wrapper}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the ssh wrapper for the application under the shared config path' do
          expect(result.to_s).
            to eql("#{paths.shared_config}/#{app_name}-ssh-wrapper")
        end
      end

      describe '#deploy_hook' do
        let(:hook_name) {'james'}
        let(:result) {paths.deploy_hook(hook_name)}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the requested ruby deploy hook under the deploy hooks path' do
          expect(result.to_s).to eql("#{paths.deploy_hooks}/#{hook_name}.rb")
        end
      end

      describe '#service_hook' do
        let(:service_name) {'superawesomeservice'}
        let(:hook_name) {'henry'}
        let(:result) {paths.service_hook(service_name, hook_name)}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the requested ruby service hook under the shared hooks path' do
          expect(result.to_s).
            to eql("#{paths.shared_hooks}/#{service_name}/#{hook_name}.rb")
        end
      end

      describe '#executable_deploy_hook' do
        let(:hook_name) {'mikey'}
        let(:result) {paths.executable_deploy_hook(hook_name)}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resovlves to the requested deploy hook script under the deploy hooks path' do
          expect(result.to_s).
            to eql("#{paths.deploy_hooks}/#{hook_name}")
        end
      end

      describe '#executable_service_hook' do
        let(:service_name) {'someotherservice'}
        let(:hook_name) {'george'}
        let(:result) {paths.executable_service_hook(service_name, hook_name)}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        it 'resolves to the requsted service hook script under the shared hooks path' do
          expect(result.to_s).
            to eql("#{paths.shared_hooks}/#{service_name}/#{hook_name}")
        end
      end

      describe '#repository_cache' do
        let(:result) {paths.repository_cache}

        it 'is a Pathname' do
          expect(result).to be_a(Pathname)
        end

        context 'when the repository cache is known' do
          it 'resolves to that repository cache path' do
            expect(result.to_s).to eql(repository_cache)
          end
        end

        context 'when the repository cache is not known' do
          let(:repository_cache) {nil}

          it 'respoves to the default repository cache' do
            expect(result.to_s).to eql("#{paths.shared}/cached-copy")
          end
        end
      end

      describe '#all_releases' do
        let(:all_release_paths) {[release_3, release_1, release_2]}
        let(:result) {paths.all_releases}

        it 'is the sorted result of globbing the releases path' do
          expect(Pathname).
            to receive(:glob).
            with(paths.releases.join('*')).
            and_return(all_release_paths)

          expect(result).to eql(all_release_paths.sort)
        end
      end

      describe '#previous_release' do
        let(:from_release) {release_3}
        let(:result) {paths.previous_release(from_release)}

        context 'when a release is specified' do
          it 'is the release immediately before the specified release' do
            expect(paths.previous_release(release_3)).to eql(release_2)
            expect(paths.previous_release(release_2)).to eql(release_1)
          end
        end

        context 'when no release is specified' do
          it 'is the release immediately before the latest release' do
            expect(paths.previous_release).to eql(release_2)
          end
        end

        context 'when there are no releases' do
          let(:all_release_paths) {[]}

          it 'is nil' do
            expect(result).to be_nil
          end
        end

        context 'when there are releases' do
          context 'but there is no release before the release in question' do
            let(:all_release_paths) {[release_3]}

            it 'is nil' do
              expect(result).to be_nil
            end
          end

          context 'and there are releases before the release in question' do
            let(:all_release_paths) {[release_1, release_3]}

            it 'is the last release before the specified release' do
              expect(result).to eql(release_1)
            end
          end
        end
      end

      describe '#previous_revision' do
        let(:active_release) {release_3}
        let(:result) {paths.previous_revision}

        context 'when there are not previous releases' do
          let(:all_release_paths) {[]}

          it 'is nil' do
            expect(result).to be_nil
          end
        end

        context 'when there are previous releases' do
          it 'is a Pathname' do
            expect(result).to be_a(Pathname)
          end

          it 'resolves to the REVISION file under the previous release path' do
            expect(result.to_s).to eql("#{release_2}/REVISION")
          end
        end
      end

      describe '#latest_release' do
        let(:result) {paths.latest_release}

        context 'when there are no releases' do
          let(:all_release_paths) {[]}

          it 'is nil' do
            expect(result).to be_nil
          end
        end

        context 'when there are releases' do
          it 'is the most recent release' do
            expect(result).to eql(release_3)
          end
        end
      end

      describe '#deployed?' do
        let(:result) {paths.deployed?}

        context 'when there are no releases' do
          let(:all_release_paths) {[]}

          it 'is false' do
            expect(result).to eql(false)
          end
        end

        context 'when there are releases' do
          it 'is true' do
            expect(result).to eql(true)
          end
        end
      end

      describe '#maintenance_page_candidates' do
        let(:result) {paths.maintenance_page_candidates}

        it 'is an Array' do
          expect(result).to be_a(Array)
        end

        context 'when there are no releases' do
          let(:all_release_paths) {[]}

          it 'contains only the default maintenance page' do
            expect(result.length).to eql(1)

            expect(result.first).to eql(described_class::DEFAULT_MAINTENANCE_PAGE)
          end
        end

        context 'when there are releases' do
          it 'contains each candidate for the latest release' do
            described_class::MAINTENANCE_CANDIDATES.each do |candidate|
              expect(result).to include(release_3.join(candidate))
            end
          end

          it 'contains the default maintenance page' do
            expect(result).to include(described_class::DEFAULT_MAINTENANCE_PAGE)
          end

          it 'contains only the specific items discussed' do
            expect(result.length).
              to eql(described_class::MAINTENANCE_CANDIDATES.length + 1)
          end
        end
      end

      describe '#rollback' do
        let(:result) {paths.rollback}

        context 'when there is a previous release' do
          let(:all_release_paths) {[release_2, release_3]}

          it 'is a Paths object' do
            expect(result).to be_a(described_class)
          end

          it 'has its active release set to the previous release' do
            expect(result.active_release).to eql(release_2)
          end
        end

        context 'when there is not a previous release' do
          let(:all_release_paths) {[release_3]}

          it 'is nil' do
            expect(result).to be_nil
          end
        end

        context 'when there are no releases' do
          let(:all_release_paths) {[]}

          it 'is nil' do
            expect(result).to be_nil
          end
        end
      end
    end

  end
end
