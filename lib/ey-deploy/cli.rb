$:.unshift File.expand_path('../vendor/thor/lib', File.dirname(__FILE__))

require 'thor'

module EY
  class CLI < Thor
    def self.start(*)
      super
    rescue RemoteFailure
      exit(1)
    end

    method_option :migrate,   :type     => :string,
                              :desc     => "Run migrations with this deploy",
                              :aliases  => ["-m"]

    method_option :branch,    :type     => :string,
                              :desc     => "Branch to deploy from, defaults to master",
                              :aliases  => ["-b"]

    method_option :repo,      :type     => :string,
                              :desc     => "Remote repo to deploy",
                              :aliases  => ["-r"]

    method_option :app,       :type     => :string,
                              :required => true,
                              :desc     => "Application to deploy",
                              :aliases  => ["-a"]

    method_option :config,    :type     => :string,
                              :desc     => "Additional configuration"

    method_option :stack,     :type     => :string,
                              :desc     => "Web stack (so we can restart it correctly)"

    method_option :instances, :type     => :array,
                              :desc     => "Instances in cluster"

    desc "deploy", "Deploy code from /data/<app>"
    def deploy(default_task=:deploy)
      EY::Server.all = parse_instances(options[:instances])
      invoke :propagate
      EY::Deploy.run(options.merge("default_task" => default_task))
    end

    method_option :app,          :type     => :string,
                                 :required => true,
                                 :desc     => "Which application's hooks to run",
                                 :aliases  => ["-a"]

    method_option :release_path, :type => :string,
                                 :desc => "Value for #release_path in hooks (mostly for internal coordination)",
                                 :aliases => ["-r"]

    method_option :current_role, :type => :string,
                                 :desc => "Value for #current_role in hooks"

    method_option :current_name, :type => :string,
                                 :desc => "Value for #current_name in hooks"

    desc "hook [NAME]", "Run a particular deploy hook"
    def hook(hook_name)
      EY::DeployHook.new(options).run(hook_name)
    end

    desc "install_bundler [VERSION]", "Make sure VERSION of bundler is installed (in system ruby)"
    def install_bundler(version)
      egrep_escaped_version = version.gsub(/\./, '\.')
      # the grep "bundler " is so that gems like bundler08 don't get
      # their versions considered too
      #
      # the [,$] is to stop us from looking for e.g. 0.9.2, seeing
      # 0.9.22, and mistakenly thinking 0.9.2 is there
      has_bundler_cmd = "gem list bundler | grep \"bundler \" | egrep -q '#{egrep_escaped_version}[,)]'"

      unless system(has_bundler_cmd)
        system("gem install bundler -q --no-rdoc --no-ri -v '#{version}'")
      end
    end

    desc "propagate", "Propagate the ey-deploy gem to the other instances in the cluster. This will install exactly version #{VERSION} and remove other versions if found."
    def propagate
      config          = EY::Deploy::Configuration.new
      gem_filename    = "ey-deploy-#{VERSION}.gem"
      local_gem_file  = File.join(Gem.dir, 'cache', gem_filename)
      remote_gem_file = File.join(Dir.tmpdir, gem_filename)
      gem_binary      = File.join(Gem.default_bindir, 'gem')

      EY::Server.config = config

      EY::Server.all.find_all do |server|
        !server.local?            # of course this machine has it
      end.find_all do |server|
        has_gem_cmd = "#{gem_binary} list ey-deploy | grep -q '(#{VERSION})'"
        !server.run(has_gem_cmd)  # doesn't have only this exact version
      end.each do |server|
        puts "~> Installing ey-deploy on #{server.hostname}"

        system(Escape.shell_command([
              'scp', '-i', "#{ENV['HOME']}/.ssh/internal",
              "-o", "StrictHostKeyChecking=no",
              local_gem_file,
              "#{config.user}@#{server.hostname}:#{remote_gem_file}",
            ]))
        server.run("sudo #{gem_binary} uninstall -a -x ey-deploy 2>/dev/null")
        server.run("sudo #{gem_binary} install --no-rdoc --no-ri '#{remote_gem_file}'")
      end
    end

    private

    def parse_instances(instance_strings)
      instance_strings.map do |s|
        tuple = s.split(/,/)
        {:hostname => tuple[0], :role => tuple[1], :name => tuple[2]}
      end
    end

  end
end
