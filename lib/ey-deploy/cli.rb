$:.unshift File.expand_path('../vendor/thor/lib', File.dirname(__FILE__))

require 'thor'

module EY
  class CLI < Thor
    class_option :migrate, :type     => :boolean,
                           :default  => true,
                           :desc     => "Run migrations with this deploy",
                           :aliases  => ["-m"]

    class_option :branch,  :type     => :string,
                           :default  => "master",
                           :desc     => "Branch to deploy from, defaults to master",
                           :aliases  => ["-b"]

    class_option :repo,    :type     => :string,
                           :desc     => "Checked out repo to run deploy from"

    method_option :app,    :type     => :string,
                           :required => true,
                           :desc     => "Application to deploy",
                           :aliases  => ["-a"]
    desc "deploy", "Deploy code from /data/<app>"
    def deploy(default_task=:deploy)
      EY::Deploy.run(options.merge("default_task" => default_task))
    end

    method_option :app,    :type     => :string,
                           :required => true,
                           :desc     => "Application to deploy",
                           :aliases  => ["-a"]
    desc "update", "Update code locally, push to all other instances and run the deploy"
    def update
      EY::Update.run(options)
    end
  end
end