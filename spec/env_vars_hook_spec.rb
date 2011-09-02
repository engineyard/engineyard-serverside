require File.dirname(__FILE__) + '/spec_helper'

describe "EnvVarsHook" do

  it "it works" do
    ENV["SOME_VAR_IS"].should be_nil
    require 'tmpdir'
    data_dir = Dir.tmpdir
    FileUtils.mkdir_p("#{data_dir}/my_app/shared/config")
    environment_dot_yaml_path = "#{data_dir}/my_app/shared/config/environment.yml"
    File.open(environment_dot_yaml_path, "w+"){ |fp| fp.write({"SOME_VAR_IS" => "set to a value"}.to_yaml) }
    EY::Serverside::EnvVarsHook.run("my_app", data_dir)
    ENV["SOME_VAR_IS"].should == "set to a value"
  end

end