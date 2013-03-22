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

    td = TestDeploy.new(test_servers, config, test_shell)
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
    td.call_order.should == %w(
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
      gc_repository_cache)
  end

  describe "task overrides" do
    class TestQuietDeploy < EY::Serverside::Deploy
      def puts(*_) 'quiet' end
    end

    before(:each) do
      @tempdir = `mktemp -d -t custom_deploy_spec.XXXXX`.strip
      @config = EY::Serverside::Deploy::Configuration.new('app' => 'app_name', 'repository_cache' => @tempdir)
      @deploy = TestQuietDeploy.new(test_servers, @config, test_shell)
    end

    def write_eydeploy(relative_path, contents = "def got_new_methods() 'from the file on disk' end")
      FileUtils.mkdir_p(File.join(
          @tempdir,
          File.dirname(relative_path)))

      File.open(File.join(@tempdir, relative_path), 'w') do |f|
        f.write contents
      end
    end

    it "requires 'eydeploy.rb' and adds any defined methods to the deploy" do
      write_eydeploy 'eydeploy.rb'
      @deploy.require_custom_tasks
      @deploy.got_new_methods.should == 'from the file on disk'
    end

    it "falls back to 'config/eydeploy.rb'" do
      write_eydeploy 'config/eydeploy.rb'
      @deploy.require_custom_tasks
      @deploy.got_new_methods.should == 'from the file on disk'
    end

    it "lets you super up from any defined methods" do
      write_eydeploy 'eydeploy.rb', "def value() super << ' + derived' end"

      class TestDeploySuper < TestQuietDeploy
        def value() 'base' end
      end

      deploy = TestDeploySuper.new(test_servers, @config, test_shell)
      deploy.require_custom_tasks
      deploy.value.should == "base + derived"
    end

    it "records exceptions raised from the instance eval in the log" do
      write_eydeploy 'eydeploy.rb', "raise 'Imma blow up'"
      lambda { @deploy.require_custom_tasks }.should raise_error
      log = @log_path.read
      log.should =~ /Exception while loading .*eydeploy\.rb/
      log.should include('Imma blow up')
    end
  end
end
