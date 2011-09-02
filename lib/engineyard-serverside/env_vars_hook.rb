module EY
  module Serverside
    class EnvVarsHook
      def self.run(app, data_dir = "/data")
        env_vars_file_path = "#{data_dir}/#{app}/shared/config/environment.yml"
        if File.exists?(env_vars_file_path)
          YAML::load_file(env_vars_file_path).each do |k, v|
            ENV[k] = v
          end
        end
      end
    end
  end
end
