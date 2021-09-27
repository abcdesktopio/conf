Vagrant.configure("2") do |config|
    config.vm.box = "hashicorp/bionic64"
    
    config.vm.define 'ubuntu'

    # Prevent SharedFoldersEnableSymlinksCreate errors
    config.vm.synced_folder ".", "/vagrant", disabled: true
    
     config.vm.provision "shell", inline: <<-SHELL
     # update package 
     apt-get update
     #
     # install docker 
     curl -fsSL https://get.docker.com -o get-docker.sh
     sudo bash ./get-docker.sh 
     #
     # install docker-compose
     sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
     sudo chmod +x /usr/local/bin/docker-compose
     # 
     # install npm
     curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
     sudo apt-get update
     # To be able to compile native addons from npm you’ll need to install the development tools
     sudo apt-get install -y git build-essential nodejs
     #
     # install newman 
     sudo npm install -g newman
     #
     # clone git conf to run install and newman collections
     git clone https://github.com/abcdesktopio/conf.git
     #
     # install and start abcdesktop
     sudo conf/docker/install.sh
     # 
     sleep 30
     #
     newman run conf/postman-collections/login.anonymous.json 
  SHELL

end
