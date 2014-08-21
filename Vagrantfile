# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"


Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = "ubuntu/trusty64"
  config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"

  config.vm.network :forwarded_port, guest: 80, host:8080

  # synced folder
  config.vm.synced_folder ".", "/vagrant"


  # setup stuff
  config.vm.provision "shell", inline: "bash /vagrant/datastore/setup.sh 'USE_DEFAULT_DATA_DIR'"
  config.vm.provision "shell", inline: "bash /vagrant/datacollectors/setup.sh"
  config.vm.provision "shell", inline: "bash /vagrant/isapi/setup.sh"

  config.vm.provision "shell", inline: "bash /vagrant/nginx/setup.sh"

end