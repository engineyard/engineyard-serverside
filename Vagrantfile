Vagrant.configure("2") do |config|
  config.vm.box = "opscode-ubuntu-12.04"
  config.vm.box_url = "https://opscode-vm.s3.amazonaws.com/vagrant/opscode_ubuntu-12.04_provisionerless.box"

  config.ssh.max_tries = 15
  config.ssh.timeout = 120

  config.vm.provision :shell, :path => "bootstrap.sh"
  config.vm.define "boxi"
end
