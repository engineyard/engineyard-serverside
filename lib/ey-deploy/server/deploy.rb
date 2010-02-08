# stolen wholesale from capistrano, thanks Jamis!
require 'fileutils'
require 'json'

module Ey
  module Server
    class Deploy
      def self.run(opts={})
        node = JSON.parse(IO.read('/etc/chef/dna.json'))

        default_config = {
          :migration_command => "rake db:migrate",
          :repository_cache  => File.expand_path(opts[:repo]),
          :branch            => 'master',
          :migrate           => false,
          :deploy_to         => "/data/#{opts[:app]}",
          :copy_exclude      => '.git',
          :node              => node,
        }

        EyDeploy.new(default_config.merge!(opts)).deploy
      end

      attr_reader :configuration

      def initialize(opts={})
        @configuration = opts
      end

      def deploy
        Dir.chdir deploy_to

        puts "~> application received"

        puts "~> ensuring proper ownership"
        run_with_result("chown -R #{user}:#{group} #{deploy_to}")

        puts "~> copying to #{release_path}"
        run_with_result(copy_repository_cache)

        run_with_result("chown -R #{user}:#{group} #{deploy_to}")

        callback(:before_migrate)
        bundle
        migrate
        callback(:before_symlink)
        puts "~> symlinking code"
        symlink
        callback(:before_restart)
        restart
        callback(:after_restart)
        cleanup
        puts "~> finalizing deploy"
      end

      def restart
        restart = case node['environment']['stack']
        when "nginx_unicorn"
          "/etc/init.d/unicorn_#{app} restart"
        when "nginx_mongrel"
          "monit restart all -g #{app}"
        when "nginx_passenger", "apache_passenger"
          "touch #{latest_release}/tmp/restart.txt"
        end
        if restart
          puts "~> restarting app: #{latest_release}"
          run_with_result("cd #{current_path} && INLINEDIR=/tmp #{framework_env} #{restart}")
        end
      end

      def bundle
        if File.exist?("#{latest_release}/Gemfile")
          puts "~> Gemfile detected, bundling gems"
          puts "~> have patience young one..."
          Dir.chdir(latest_release) do
            system("gem bundle")
          end
          #puts run_with_result("cd #{latest_release} && gem bundle")
        end
      end

      # before_symlink
      # before_restart
      def callback(what)
        if File.exist?("#{latest_release}/deploy/#{what}.rb")
          Dir.chdir(latest_release) do
            puts "~> running deploy hook: deploy/#{what}.rb"
            instance_eval(IO.read("#{latest_release}/deploy/#{what}.rb"))
          end
        end
      end

      def latest_release
        all_releases.last
      end

      def previous_release(current=latest_release)
        index = all_releases.index(current)
        all_releases[index-1]
      end

      def oldest_release
        all_releases.first
      end

      def all_releases
        `ls #{release_dir}`.split("\n").sort.map{|r| File.join(release_dir, r)}
      end

      def cleanup
        while all_releases.size >= 3
          puts "~> cleaning up old releases"
          FileUtils.rm_rf oldest_release
        end
      end

      def rollback
        puts "~> rolling back to previous release"
        symlink(previous_release)
        FileUtils.rm_rf latest_release
        puts "~> restarting with previous release"
        restart
      end

      def migrate
        if migrate
          run_with_result "ln -nfs #{shared_path}/config/database.yml #{latest_release}/config/database.yml"
          run_with_result "ln -nfs #{shared_path}/log #{latest_release}/log"
          puts "~> Migrating: cd #{latest_release} && sudo -u #{user} #{framework_envs} #{migration_command}"
          run_with_result("chown -R #{user}:#{group} #{latest_release}")
          run_with_result("cd #{latest_release} && sudo -u #{user} #{framework_envs} #{migration_command}")
        end
      end

      def framework_envs
        "RAILS_ENV=#{environment} RACK_ENV=#{environment} MERB_ENV=#{environment}"
      end

      def user
        node['users'].first['username'] || 'nobody'
      end
      alias :group :user

      def role
        node['instance_role']
      end

      def environment
        node['environment']['framework_env']
      end

      def current_path
        File.join(deploy_to, "current")
      end

      def shared_path
        File.join(deploy_to, "shared")
      end

      def release_dir
        File.join(deploy_to, "releases")
      end

      def release_path
        @release_path ||= File.join(release_dir, Time.now.utc.strftime("%Y%m%d%H%M%S"))
      end

      def symlink(release_to_link=latest_release)
        symlink = false
        begin
          run_with_result [ "chmod -R g+w #{release_to_link}",
            "rm -rf #{release_to_link}/log #{release_to_link}/public/system #{release_to_link}/tmp/pids",
            "mkdir -p #{release_to_link}/tmp",
            "ln -nfs #{shared_path}/log #{release_to_link}/log",
            "mkdir -p #{release_to_link}/public",
            "mkdir -p #{release_to_link}/config",
            "ln -nfs #{shared_path}/system #{release_to_link}/public/system",
            "ln -nfs #{shared_path}/pids #{release_to_link}/tmp/pids",
            "ln -nfs #{shared_path}/config/database.yml #{release_to_link}/config/database.yml",
            "chown -R #{user}:#{group} #{release_to_link}"
            ].join(" && ")

          symlink = true
          run_with_result "rm -f #{current_path} && ln -nfs #{release_to_link} #{current_path} && chown -R #{user}:#{group} #{current_path}"
        rescue => e
          run_with_result "rm -f #{current_path} && ln -nfs #{previous_release(release_to_link)} #{current_path} && chown -R #{user}:#{group} #{current_path}" if symlink
          run_with_result "rm -rf #{release_to_link}"
          raise e
        end
      end

      def run_with_result(cmd)
        res = `sh -c "#{cmd} 2>&1"`
        unless $? == 0
          puts res
          exit 1
        end
        res
      end

      def run(cmd)
        res = `sudo -u #{user} sh -c "#{cmd} 2>&1"`
        unless $? == 0
          puts res
          exit 1
        end
        res
      end

      def sudo(cmd)
        res = `sh -c "#{cmd} 2>&1"`
        unless $? == 0
          puts res
          exit 1
        end
        res
      end

      def method_missing(meth, *args, &blk)
        if configuration.key?(meth)
          configuration[meth]
        else
          super
        end
      end

      def respond_to?(meth)
        if configuration.key?(meth)
          true
        else
          super
        end
      end

    private

      def copy_repository_cache
        if copy_exclude.empty?
          return "cp -RPp #{repository_cache} #{release_path}"
        else
          exclusions = copy_exclude.map { |e| "--exclude=\"#{e}\"" }.join(' ')
          return "rsync -lrpt #{exclusions} #{repository_cache}/* #{release_path}"
        end
      end

      def copy_exclude
        @copy_exclude ||= Array(configuration.fetch(:copy_exclude, []))
      end
    end
  end
end