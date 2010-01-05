# stolen wholesale from capistrano, thanks Jamis!
require 'yaml'
require 'fileutils'
class EyDeployFailure < StandardError
end

class EyDeploy
  # Executes the SCM command for this strategy and writes the REVISION
  # mark file to each host.
  def deploy
    puts "*" * 40
    puts "~> application received"
    @configuration[:release_path] = "#{@configuration[:deploy_to]}/releases/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}"
    if @configuration[:revision] == ''
       @configuration[:revision] = `git rev-list --branches`.split.first
    end

    puts "~> ensuring proper ownership"
    run_with_result("chown -R #{user}:#{group} #{@configuration[:deploy_to]}")

    puts "~> copying to #{release_path}"
    run_with_result(copy_repository_cache)

    run_with_result("chown -R #{user}:#{group} #{@configuration[:deploy_to]}")

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
    puts "*" * 40
    puts "~> deploy finished successfuly"
  end

  def restart
    unless @configuration[:restart_command].empty?
      puts "~> restarting app: #{latest_release}"
      run_with_result("cd #{current_path} && INLINEDIR=/tmp RAILS_ENV=#{@configuration[:environment]} RACK_ENV=#{@configuration[:environment]} MERB_ENV=#{@configuration[:environment]} #{@configuration[:restart_command]}")
    end
  end

  def bundle
    if File.exist?("#{latest_release}/Gemfile")
      puts "~> Gemfile detected, bundling gems"
      puts "~> have patience young one..."
      puts run_with_result("cd #{latest_release} && gem bundle")
    end
  end

  # before_symlink
  # before_restart
  def callback(what)
    if File.exist?("#{latest_release}/deploy/#{what}.rb")
      Dir.chdir(latest_release) do
        puts "~> running deploy hook: #{latest_release}/deploy/#{what}.rb"
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
    if @configuration[:migrate]
      run_with_result "ln -nfs #{shared_path}/config/database.yml #{latest_release}/config/database.yml"
      run_with_result "ln -nfs #{shared_path}/log #{latest_release}/log"
      puts "~> Migrating: cd #{latest_release} && sudo -u #{user} RAILS_ENV=#{@configuration[:environment]} RACK_ENV=#{@configuration[:environment]} MERB_ENV=#{@configuration[:environment]} #{@configuration[:migration_command]}"
      run_with_result("chown -R #{user}:#{group} #{latest_release}")
      run_with_result("cd #{latest_release} && sudo -u #{user} RAILS_ENV=#{@configuration[:environment]} RACK_ENV=#{@configuration[:environment]} MERB_ENV=#{@configuration[:environment]} #{@configuration[:migration_command]}")
    end
  end

  def user
    @configuration[:user] || 'nobody'
  end

  def group
    @configuration[:group] || user
  end

  def current_path
    "#{@configuration[:deploy_to]}/current"
  end

  def shared_path
    configuration[:shared_path]
  end

  def release_dir
    "#{@configuration[:deploy_to]}/releases"
  end

  def release_path
    @configuration[:release_path]
  end

  def node
    @configuration[:node]
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
    res = `#{cmd} 2>&1`
    raise(EyDeployFailure, res) unless $? == 0
    res
  end

  def run(cmd)
    res = `sudo -u #{user} #{cmd} 2>&1`
    raise(EyDeployFailure, res) unless $? == 0
    res
  end

  def sudo(cmd)
    run cmd
  end

  # :repository_cache
  # :shared_path
  # :repository
  # :release_path
  # :copy_exclude
  # :revision
  # :user
  # :group
  def initialize(opts={})
    @configuration = opts
    @configuration[:shared_path] = "#{@configuration[:deploy_to]}/shared"
  end

  def configuration
    @configuration
  end

  private

  def repository_cache
    File.join(configuration[:shared_path], configuration[:repository_cache] || "cached-copy")
  end

  def copy_repository_cache
    if copy_exclude.empty?
      return "cp -RPp #{repository_cache} #{release_path} && #{mark}"
    else
      exclusions = copy_exclude.map { |e| "--exclude=\"#{e}\"" }.join(' ')
      return "rsync -lrpt #{exclusions} #{repository_cache}/* #{release_path} && #{mark}"
    end
  end

  def revision
    configuration[:revision]
  end

  def mark
    "(echo #{revision} > #{release_path}/REVISION)"
  end

  def copy_exclude
    @copy_exclude ||= Array(configuration.fetch(:copy_exclude, []))
  end
end
