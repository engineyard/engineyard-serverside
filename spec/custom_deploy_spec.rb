require 'spec_helper'

describe "the EY::Serverside::Deploy API" do
  it "calls tasks in the right order" do
    class TestDeploy < FullTestDeploy
      # This happens before require_custom_tasks, so it's not
      # overrideable. That's why it's not in @call_order.
      def update_repository_cache() end
      def check_repository() end

      # cheat a bit; we don't actually want to do these things
      def require_custom_tasks() end
      def callback(*_) end

      attr_reader :call_order
      def initialize(*a)
        super
        @call_order = []
      end

      def run(*)
      end

      def sudo(*)
      end

      def push_code()                @call_order << 'push_code'                end
      def copy_repository_cache()    @call_order << 'copy_repository_cache'    end
      def create_revision_file()     @call_order << 'create_revision_file'     end
      def bundle()                   @call_order << 'bundle'                   end
      def setup_services()           @call_order << 'setup_services'           end
      def symlink_configs()          @call_order << 'symlink_configs'          end
      def migrate()                  @call_order << 'migrate'                  end
      def compile_assets()           @call_order << 'compile_assets'           end
      def symlink()                  @call_order << 'symlink'                  end
      def restart()                  @call_order << 'restart'                  end
      def cleanup_old_releases()     @call_order << 'cleanup_old_releases'     end
      def enable_maintenance_page()  @call_order << 'enable_maintenance_page'  end
      def disable_maintenance_page() @call_order << 'disable_maintenance_page' end
      def gc_repository_cache()      @call_order << 'gc_repository_cache'      end
    end

    config = EY::Serverside::Deploy::Configuration.new({
      'app' => 'app_name',
      'framework_env' => 'staging',
    })

    td = TestDeploy.realnew(test_servers, config, test_shell)
    td.deploy

    ############################# IMPORTANT ####################################
    #
    # Call order is referenced in the engineyard gem eydeploy.rb documentation.
    #
    # https://support.cloud.engineyard.com/entries/20996661-customize-your-deployment
    #
    # Changing call order or removing methods may adversely affect customers
    # that are using eydeploy.rb and relying on this documentation.
    #
    ############################################################################
    expect(td.call_order).to eq(%w(
      push_code
      copy_repository_cache
      create_revision_file
      bundle
      setup_services
      symlink_configs
      compile_assets
      enable_maintenance_page
      migrate
      symlink
      restart
      disable_maintenance_page
      cleanup_old_releases
      gc_repository_cache))
  end

  describe "task overrides" do
    before(:each) do
      @tempdir = Pathname.new(`mktemp -d -t custom_deploy_spec.XXXXX`.strip)
    end

    def write_eydeploy(relative_path, contents = "def got_new_methods() 'from the file on disk' end")
      path = @tempdir.join(relative_path)
      path.dirname.mkpath
      path.open('w') { |f| f << contents }
    end

    describe "eydeploy_rb disabled" do
      before do
        @config = EY::Serverside::Deploy::Configuration.new('app' => 'app_name', 'repository_cache' => @tempdir.to_s, 'eydeploy_rb' => 'false')
        @deploy = FullTestDeploy.realnew(test_servers, @config, test_shell)
      end

      it "doesn't load eydeploy_rb file" do
        write_eydeploy 'eydeploy.rb'
        @deploy.require_custom_tasks
        expect(@deploy).not_to respond_to(:got_new_methods)
      end
    end

    describe "eydeploy_rb detect or enabled" do
      before do
        @config = EY::Serverside::Deploy::Configuration.new('app' => 'app_name', 'repository_cache' => @tempdir.to_s, 'eydeploy_rb' => 'true')
        @deploy = FullTestDeploy.realnew(test_servers, @config, test_shell)
      end

      it "requires 'eydeploy.rb' and adds any defined methods to the deploy" do
        write_eydeploy 'eydeploy.rb'
        @deploy.require_custom_tasks
        expect(@deploy.got_new_methods).to eq('from the file on disk')
      end

      it "falls back to 'config/eydeploy.rb'" do
        write_eydeploy 'config/eydeploy.rb'
        @deploy.require_custom_tasks
        expect(@deploy.got_new_methods).to eq('from the file on disk')
      end

      it "lets you super up from any defined methods" do
        write_eydeploy 'eydeploy.rb', "def value() super << ' + derived' end"

        class TestDeploySuper < FullTestDeploy
          def value() 'base' end
        end

        deploy = TestDeploySuper.realnew(test_servers, @config, test_shell)
        deploy.require_custom_tasks
        expect(deploy.value).to eq("base + derived")
      end

      it "records exceptions raised from the instance eval in the log" do
        write_eydeploy 'eydeploy.rb', "raise 'Imma blow up'"
        expect { @deploy.require_custom_tasks }.to raise_error
        log = @log_path.read
        expect(log).to match(/Exception while loading .*eydeploy\.rb/)
        expect(log).to include('Imma blow up')
      end
    end
  end
end
