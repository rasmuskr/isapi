# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"


Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = "ubuntu/trusty64"

  # synced folder
  config.vm.synced_folder ".", "/vagrant"


  # setup stuff
  config.vm.provision "shell", inline: "bash /vagrant/datastore/setup.sh 'USE_DEFAULT_DATA_DIR'"
  config.vm.provision "shell", inline: "bash /vagrant/datacollectors/setup.sh"
  config.vm.provision "shell", inline: "bash /vagrant/isapi/setup.sh"


end