require 'spec_helper'

require 'engineyard-serverside/configuration'

module EY
  module Serverside
    describe Configuration do
      let(:options) {{}}

      let(:configuration) {described_class.new(options)}

      let(:serverside_node) {
        {
          'instance_role' => 'superstar'
        }
      }

      before(:each) do
        # Set up the blanket stubs along the class seam
        allow(EY::Serverside).to receive(:node).and_return(serverside_node)
      end


      describe '#app' do
        let(:app) {configuration.app}

        context 'when not configured' do
          let(:options) {{}}

          it 'raises an error' do
            expect {app}.to raise_error
          end
        end

        context 'when configured' do
          let(:options) {{:app => 'zazoo'}}

          it 'is the configured value' do
            expect(app).to eql('zazoo')
          end
        end
      end

      describe '#environment_name' do
        let(:environment_name) {configuration.environment_name}

        context 'when not configured' do
          let(:options) {{}}

          it 'raises an error' do
            expect {environment_name}.to raise_error
          end
        end

        context 'when configured' do
          let(:options) {{:environment_name => 'zazoo'}}

          it 'is the configured value' do
            expect(environment_name).to eql('zazoo')
          end
        end
      end

      describe '#account_name' do
        let(:account_name) {configuration.account_name}

        context 'when not configured' do
          let(:options) {{}}

          it 'raises an error' do
            expect {account_name}.to raise_error
          end
        end

        context 'when configured' do
          let(:options) {{:account_name => 'zazoo'}}

          it 'is the configured value' do
            expect(account_name).to eql('zazoo')
          end
        end
      end

      describe '#framework_env' do
        let(:framework_env) {configuration.framework_env}

        context 'when not configured' do
          let(:options) {{}}

          it 'raises an error' do
            expect {framework_env}.to raise_error
          end
        end

        context 'when configured' do
          let(:options) {{:framework_env => 'zazoo'}}

          it 'is the configured value' do
            expect(framework_env).to eql('zazoo')
          end
        end
      end

      describe '#instances' do
        let(:instances) {configuration.instances}

        context 'when not configured' do
          let(:options) {{}}

          it 'raises an error' do
            expect {instances}.to raise_error
          end
        end

        context 'when configured' do
          let(:options) {{:instances => 'zazoo'}}

          it 'is the configured value' do
            expect(instances).to eql('zazoo')
          end
        end
      end

      describe '#instance_roles' do
        let(:instance_roles) {configuration.instance_roles}

        context 'when not configured' do
          let(:options) {{}}

          it 'raises an error' do
            expect {instance_roles}.to raise_error
          end
        end

        context 'when configured' do
          let(:options) {{:instance_roles => 'zazoo'}}

          it 'is the configured value' do
            expect(instance_roles).to eql('zazoo')
          end
        end
      end

      describe '#instance_names' do
        let(:instance_names) {configuration.instance_names}

        context 'when not configured' do
          let(:options) {{}}

          it 'raises an error' do
            expect {instance_names}.to raise_error
          end
        end

        context 'when configured' do
          let(:options) {{:instance_names => 'zazoo'}}

          it 'is the configured value' do
            expect(instance_names).to eql('zazoo')
          end
        end
      end

      describe '#git' do
        let(:git) {configuration.git}

        context 'when not configured' do
          let(:options) {{}}

          it 'is the default git value' do
            expect(git).to be_nil
          end
        end

        context 'when configured' do
          let(:options) {{:git => 'zazoo'}}

          it 'is the configured value' do
            expect(git).to eql('zazoo')
          end
        end

        context 'when configured via deprecated name' do
          let(:options){{:repo => 'zazoo-repo'}}

          before(:each) do
            allow(EY::Serverside).to receive(:deprecation_warning)
          end

          it 'is the configured value' do
            expect(git).to eql('zazoo-repo')
          end
        end
      end

      describe '#archive' do
        let(:archive) {configuration.archive}

        context 'when not configured' do
          let(:options) {{}}

          it 'is the default archive value' do
            expect(archive).to be_nil
          end
        end

        context 'when configured' do
          let(:options) {{:archive => 'zazoo'}}

          it 'is the configured value' do
            expect(archive).to eql('zazoo')
          end
        end
      end

      describe '#precompile_assets_task' do
        let(:pat) {configuration.precompile_assets_task}

        context 'when not configured' do
          let(:options) {{}}

          it 'is the default archive value' do
            expect(pat).to eql('assets:precompile')
          end
        end

        context 'when configured' do
          let(:options) {{:precompile_assets_task => 'zazoo'}}

          it 'is the configured value' do
            expect(pat).to eql('zazoo')
          end
        end
      end

      describe '#load_ey_yml_data' do
        let(:data) {{}}
        let(:shell) {Object.new}
        let(:environment_name) {'loading'}
        let(:options) {
          {
            :app => 'some app',
            :environment_name => environment_name
          }
        }

        let(:load_ey_yml_data) {configuration.load_ey_yml_data(data, shell)}

        before(:each) do
          # Stub out the shell methods involved in this thing
          [:info, :substatus, :debug].each do |message|
            allow(shell).to receive(message)
          end
        end

        context 'without defaults or environment-specific data' do
          it 'is false' do
            expect(load_ey_yml_data).to eql(false)
          end

          it 'does not change the config internal data' do
            original_config_sources = configuration.
              instance_eval {@config_sources.clone}

            load_ey_yml_data

            new_config_sources = configuration.
              instance_eval {@config_sources.clone}

            expect(new_config_sources).to eql(original_config_sources)
          end

          it 'alerts on the shell regarding the lack of an ey.yml' do
            expect(shell).
              to receive(:info).
              with('No matching ey.yml configuration found for environment "loading".')

            load_ey_yml_data
          end

          it 'sends debug information to the shell' do
            expect(shell).
              to receive(:debug).
              with("ey.yml:\n#{data.pretty_inspect}")

            load_ey_yml_data
          end
        end

        context 'when the data contains environments' do
          let(:environments) {{}}
          let(:data) {{'environments' => environments}}

          context 'and those environments include the configured environment' do
            let(:environments) {{environment_name => {'foo' => 'bar'}}}

            it 'adds a config source' do

              original_config_sources = configuration.
                instance_eval {@config_sources.clone}

              load_ey_yml_data

              new_config_sources = configuration.
                instance_eval {@config_sources.clone}

              expect(new_config_sources.length).
                to eql(original_config_sources.length + 1)
            end
          end

          context 'but those environments lack the configured environemnt' do
            it 'does not add a config source' do
              original_config_sources = configuration.
                instance_eval {@config_sources.clone}

              load_ey_yml_data

              new_config_sources = configuration.
                instance_eval {@config_sources.clone}

              expect(new_config_sources).to eql(original_config_sources)
            end
          end
        end

        context 'when the data contains defaults' do
          let(:defaults) {{}}
          let(:data) {{'defaults' => defaults}}

          it 'adds a config source' do

            original_config_sources = configuration.
              instance_eval {@config_sources.clone}

            load_ey_yml_data

            new_config_sources = configuration.
              instance_eval {@config_sources.clone}

            expect(new_config_sources.length).
              to eql(original_config_sources.length + 1)
          end
        end

        context 'when both defaults and environment-specific data is present' do
          let(:defaults) {{'scope' => 'default'}}
          let(:environments) {{environment_name => {'scope' => 'environment'}}}
          let(:data) {{'defaults' => defaults, 'environments' => environments}}

          it 'adds a config source for each' do
            original_config_sources = configuration.
              instance_eval {@config_sources.clone}

            load_ey_yml_data

            new_config_sources = configuration.
              instance_eval {@config_sources.clone}

            expect(new_config_sources.length).
              to eql(original_config_sources.length + 2)
          end

          it 'gives higher priority to environment-specific data' do
            load_ey_yml_data

            config_sources = configuration.instance_eval {@config_sources.clone}

            defaults_priority = config_sources.
              index {|source| source['scope'] == 'default'}

            environments_priority = config_sources.
              index {|source| source['scope'] == 'environment'}

            expect(defaults_priority < environments_priority).to eql(true)
          end
        end

      end

      describe '#has_key?'

      describe '#to_json' do
        let(:to_json) {configuration.to_json}

        it 'is the JSON representation of the configuration' do
          expected = 'loljson'

          expect(MultiJson).
            to receive(:dump).
            with(configuration.send(:configuration)).
            and_return(expected)

          expect(to_json).to eql(expected)
        end
      end

      describe '#node' do
        let(:node) {configuration.node}

        it 'is the value of the serverside node attribute' do
          expect(node).to eql(serverside_node)
        end
        
      end

      describe '#source' do
        let(:shell) {Object.new}
        let(:source) {configuration.source(shell)}

        context 'when both archive and git options are set' do
          let(:options) {{:git => 'one thing', :archive => 'another thing'}}
          before(:each) do
            allow(shell).to receive(:fatal)
          end

          it 'raises an error' do
            expect {source}.
              to raise_error(
                "Both --git and --archive specified. Precedence is not defined. Aborting"
            )
          end
        end

        context 'when archive is set' do
          let(:options) {{:app => 'some app', :archive => 'some archive'}}

          it 'is an Archive source' do
            archive = Object.new

            expect(EY::Serverside::Source::Archive).
              to receive(:new).
              with(
                shell,
                :verbose => configuration.verbose,
                :repository_cache => configuration.paths.repository_cache,
                :app => configuration.app,
                :uri => 'some archive',
                :ref => configuration.branch
              ).
              and_return(archive)

            expect(source).to eql(archive)
          end
        end

        context 'when git is set' do
          let(:options) {{:app => 'some app', :git => 'some repo'}}

          it 'is a Git source' do
            git = Object.new

            expect(EY::Serverside::Source::Git).
              to receive(:new).
              with(
                shell,
                :verbose => configuration.verbose,
                :repository_cache => configuration.paths.repository_cache,
                :app => configuration.app,
                :uri => 'some repo',
                :ref => configuration.branch
              ).
              and_return(git)

            expect(source).to eql(git)
          end

        end

      end

      describe '#paths'

      describe '#rollback_paths!'

      describe '#ruby_version_command' do
        let(:rvc) {configuration.ruby_version_command}

        it 'is the shell command to get the system ruby version' do
          expect(rvc).to eql('ruby -v')
        end
      end

      describe '#system_version_command' do
        let(:svc) {configuration.system_version_command}

        it 'is the shell command to get the system architecture' do
          expect(svc).to eql("uname -m")
        end
      end

      describe '#active_revision'

      describe '#latest_revision'

      describe '#previous_revision'

      describe '#has_database?'

      describe '#check_database_adapter?'

      describe '#migrate?' do
        let(:migrate) {configuration.migrate?}

        context 'when no migration command is configured' do
          let(:options) {{}}

          it 'is false' do
            expect(migrate).to eql(false)
          end
        end

        context 'when a migration command is configured' do
          let(:options) {{:migrate => 'south'}}

          it 'is true' do
            expect(migrate).to eql(true)
          end
        end
      end

      describe '#role' do
        let(:role) {configuration.role}

        it 'is the instance role configured for the serverside node' do
          expect(role).to eql(serverside_node['instance_role'])
        end
      end

      describe '#current_role'

      describe '#framework_env_names' do
        let(:fen) {configuration.framework_env_names}

        it 'is an array' do
          expect(fen).to be_a(Array)
        end

        it 'includes rails' do
          expect(fen).to include('RAILS_ENV')
        end

        it 'includes node' do
          expect(fen).to include('NODE_ENV')
        end

        it 'includes rack' do
          expect(fen).to include('RACK_ENV')
        end

        it 'includes merb' do
          expect(fen).to include('MERB_ENV')
        end
      end

      describe '#framework_envs' do
        let(:options) {{:framework_env => 'something'}}
        let(:framework_envs) {configuration.framework_envs}

        it 'is a string' do
          expect(framework_envs).to be_a(String)
        end

        it 'contains a command line ENV setting for each framework' do
          configuration.framework_env_names.each do |env|
            expect(framework_envs).to match(/#{env}=something/)
          end
        end
      end

      describe '#set_framework_envs' do
        let(:options) {{:framework_env => 'something'}}
        let(:set_framework_envs) {configuration.set_framework_envs}

        it 'propagates the framework env settings to the local environment' do
          configuration.framework_env_names.each do |env|
            expect(ENV).to receive(:[]=).with(env, 'something')
          end

          set_framework_envs
        end
      end

      describe '#extra_bundle_install_options' do
        let(:options) {{:framework_env => 'anything'}}
        let(:ebio) {configuration.extra_bundle_install_options}

        it 'is an array' do
          expect(ebio).to be_a(Array)
        end

        context 'with configured bundle options' do
          let(:options) {
            {
              :framework_env => 'anything',
              :bundle_options => 'whatever'
            }
          }

          it 'includes those bundle options' do
            expect(ebio).to include('whatever')
          end
        end

        context 'bundle without options' do
          context 'with a nil bundle without configuration' do
            let(:options) {
              {
                :framework_env => 'anything',
                :bundle_without => nil
              }
            }

            it 'omits the bundle without flags' do
              expect(ebio).not_to include('--without')
            end
          end

          context 'for specific bundle without configurations' do
            let(:options) {
              {
                :framework_env => 'anything',
                :bundle_without => 'fear'
              }
            }

            it 'very specifically bundles without the configured groups' do
              expect(ebio.join(' ')).to include('--without fear')
            end
          end
          context 'for test envs' do
            let(:options) {{:framework_env => 'test'}}

            it 'omits the test group' do
              expect(ebio.join(' ')).not_to match(/--without.*test/)
            end

            it 'includes the development group' do
              expect(ebio.join(' ')).to match(/--without.*development/)
            end
          end

          context 'for dev envs' do
            let(:options) {{:framework_env => 'development'}}

            it 'omits the development group' do
              expect(ebio.join(' ')).not_to match(/--without.*development/)
            end

            it 'includes the test group' do
              expect(ebio.join(' ')).to match(/--without.*test/)
            end
          end


          context 'for all other envs' do
            let(:options) {{:framework_env => 'whatever'}}

            it 'includes both test and development' do
              expect(ebio.join(' ')).to include('--without test development')
            end
          end
        end
      end

      describe '#precompiled_assets_inferred?'

      describe '#precompile_assets?'

      describe '#skip_precompiled_assets?'

      describe '#required_downtime_stack?' do
        let(:rds) {configuration.required_downtime_stack?}

        context 'when the stack is not configured' do
          let(:options) {{}}

          it 'is true' do
            expect(rds).to eql(true)
          end
        end

        context 'when the stack is configured' do
          let(:stack) {nil}
          let(:options) {{:stack => stack}}

          context 'as nginx with mongrel' do
            let(:stack) {'nginx_mongrel'}

            it 'is true' do
              expect(rds).to eql(true)
            end
          end

          context 'as glassfish' do
            let(:stack) {'glassfish'}

            it 'is true' do
              expect(rds).to eql(true)
            end
          end

          context 'as any other non-falsy value' do
            let(:stack) {'flibbertygibbets'}

            it 'is false' do
              expect(rds).to eql(false)
            end
          end
        end
      end

      describe '#configured_services'

    end
  end
end
