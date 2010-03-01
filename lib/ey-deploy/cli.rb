$:.unshift File.expand_path('../vendor/thor/lib', File.dirname(__FILE__))

require 'thor'

module EY
  class CLI < Thor
    class_option :migrate,
                          :type     => :string,
                          :default  => "rake db:migrate",
                          :desc     => "Run migrations with this deploy",
                          :aliases  => ["-m"]

    class_option :branch, :type     => :string,
                          :default  => "master",
                          :desc     => "Branch to deploy from, defaults to master",
                          :aliases  => ["-b"]

    class_option :repo,   :type     => :string,
                          :desc     => "Remote repo to deploy",
                          :aliases  => ["-r"]

    method_option :app,   :type     => :string,
                          :required => true,
                          :desc     => "Application to deploy",
                          :aliases  => ["-a"]
    desc "deploy", "Deploy code from /data/<app>"
    def deploy(default_task=:deploy)
      EY::Deploy.run(options.merge("default_task" => default_task))
    end

    method_option :app,   :type     => :string,
                          :required => true,
                          :desc     => "Application to deploy",
                          :aliases  => ["-a"]
    desc "update", "Update code locally, push to all other instances and run the deploy"
    def update(default_task=:update)
      EY::Update.run(options.merge("default_task" => default_task))
    end

    desc "check", "Check whether the client gem is compatible with the server gem"
    def check(client_version, server_requirement)
      compat = EY::Compatibility.new(client_version, server_requirement)
      return if compat.compatible?

      if compat.server_newer?
        puts "Server library is newer than supported by the engineyard gem"
        puts "Please upgrade the engineyard gem"
        exit(1)
      end

      system("gem install ey-deploy -v '#{server_requirement}' > /dev/null 2>&1")
      case $?.exitstatus
      when 2
        puts "Incompatible server component detected"
        puts "Please contact us at http://cloud-support.engineyard.com"
        exit 2
      when 0
        puts "Upgraded server component"
        exit
      else
        exit 3
      end
    end
  end
end