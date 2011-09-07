module EY::Serverside::Strategies::DeployIntegrationSpec
  module Helpers

    def update_repository_cache
      cached_copy = File.join(c.shared_path, 'cached-copy')

      deploy_hook_dir = File.join(cached_copy, 'deploy')
      FileUtils.mkdir_p(deploy_hook_dir)
      %w[bundle migrate compile_assets symlink restart].each do |action|
        %w[before after].each do |prefix|
          hook = "#{prefix}_#{action}"
          File.open(File.join(deploy_hook_dir, "#{hook}.rb"), 'w') do |f|
            f.write(%Q{run 'touch "#{c.release_path}/#{hook}.ran"'})
          end
        end
      end

      FileUtils.mkdir_p(File.join(c.shared_path, 'config'))

      Dir.chdir(cached_copy) do
        `echo "this is my file; there are many like it, but this one is mine" > file`
        File.open('Gemfile', 'w') do |f|
          f.write <<-EOF
source :gemcutter

gem "bundler", "~> 1.0.0.rc.6"
gem "rake"
EOF
        end

        File.open("Gemfile.lock", "w") do |f|
          f.write <<-EOF
GEM
  remote: http://rubygems.org/
  specs:
    rake (0.8.7)

PLATFORMS
  ruby

DEPENDENCIES
  bundler (~> 1.0.0.rc.6)
  rake
EOF
        end
      end
    end

    def create_revision_file_command
      "echo 'revision, yo' > #{c.release_path}/REVISION"
    end

    def short_log_message(revision)
      "FONDLED THE CODE"
    end

  end
end


