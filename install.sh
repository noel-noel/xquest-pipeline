#!/bin/bash

# Downloading xQuest/xProphet
printf "Downloading xQuest/xProphet... "
mkdir /usr/local/share/xquest
cd /usr/local/share/xquest
wget https://gitlab.ethz.ch/leitner_lab/xquest_xprophet/-/blob/master/V2.1.5.tar
printf "Done.\n\n"

# Extracting the archive
printf "Extracting tar... "
tar -xvf V2.1.5.tar
rm V2.1.5.tar
printf "Done.\n\n"

# Installing dependencies
printf "Installing dependencies...\nThe script will ask you your password to run apt-get, install dos2unix and run cpan.
For the latter, please use the default configuration.\n"
read -p "Press enter to continue."
cd V2.1.5/xquest/installation
chmod 755 install_packages.sh
./install_packages.sh
printf "Installing dependencies... Done.\n\n"

# Installing xQuest/xProphet
printf "Installing xQuest/xProphet...\n"
printf "Please use the default location for the stylesheet (/var/www/).\n"
sed '1s/.*/INSTALLDIR=\/usr\/local\/share\/xquest\/V2.1.5\/xquest/' install_xquest.sh > install_xquest_new.sh
mv install_xquest.sh install_xquest.sh.bak
mv install_xquest_new.sh install_xquest.sh
chmod 755 install_xquest.sh
./install_xquest.sh
printf "Installing xQuest/xProphet... Done.\n\n"

# Adding xQuest bin to PATH
case ":$PATH:" in
  *:/usr/local/share/xquest/V2.1.5/xquest/bin:*) printf "PATH correctly set.\n\n"
                                      ;;
  *)  printf "Setting PATH... "
      cp $HOME/.bashrc $HOME/.bashrc.bak
      echo "export PATH=$PATH:/usr/local/share/xquest/V2.1.5/xquest/bin" >> $HOME/.bashrc
      source $HOME/.bashrc
      printf "Done.\n\n"
      ;;
esac

# Configuring Apache 2
sudo service apache2 restart
printf "Configuring the Apache 2 web server...\nThe script will ask you your password.\n"
sudo chmod -R 777 /usr/local/share/xquest/results
# apache2.conf
sudo cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bak
sudo bash -c 'echo "# Added by Simple xQuest" >> /etc/apache2/apache2.conf'
sudo bash -c 'echo "ServerName localhost" >> /etc/apache2/apache2.conf'
sudo bash -c 'echo "ScriptAlias /cgi-bin/ /var/www/cgi-bin/" >> /etc/apache2/apache2.conf'
sudo bash -c 'echo "Options +ExecCGI" >> /etc/apache2/apache2.conf'
sudo bash -c 'echo "AddHandler cgi-script .cgi .pl .py" >> /etc/apache2/apache2.conf'
sudo sed -i "s/Timeout 300/Timeout 30000/g" /etc/apache2/apache2.conf
# serve-cgi-bin.conf
sudo cp /etc/apache2/conf-available/serve-cgi-bin.conf /etc/apache2/conf-available/serve-cgi-bin.conf.bak
sudo sed -i "s#/usr/lib/#/var/www/#g" /etc/apache2/conf-available/serve-cgi-bin.conf
sudo sed -i "/Require all granted/d" /etc/apache2/conf-available/serve-cgi-bin.conf
sudo sed -i "s/Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch/Options +ExecCGI/g" /etc/apache2/conf-available/serve-cgi-bin.conf
# 000-default.conf
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bak
sudo sed -i "s#DocumentRoot /var/www/html#DocumentRoot /var/www#g" /etc/apache2/sites-available/000-default.conf
# Enabling CGI module
sudo a2enmod cgi
# Creating cgi-bin folder and symlinks
sudo mkdir /var/www/cgi-bin/
sudo ln -s /usr/local/share/xquest/V2.1.5/xquest/cgi/ /var/www/cgi-bin/xquest
sudo ln -s /usr/local/share/xquest/results/ /var/www/results
sudo chmod -R 777 /usr/local/share/xquest/results/
# Configuring xQuest for Apache 2
sed -i "s/xquest-desktop/$(hostname -s)/g" /usr/local/share/xquest/V2.1.5/xquest/modules/Environment.pm
sed -i "s/xquestvm/xquest-ubuntu/g" /usr/local/share/xquest/V2.1.5/xquest/modules/Environment.pm
sed -i "s#\\\/home\\\/xquest\\\/xquest#\\\/usr\\/local\\/share\\\/xquest\\\/V2.1.5\\\/xquest#g" /usr/local/share/xquest/V2.1.5/xquest/modules/Environment.pm
sed -i "s#/home/xquest/results#/usr/local/share/xquest/results#g" /usr/local/share/xquest/V2.1.5/xquest/conf/web.config
# Copying deffiles
mkdir /usr/local/share/xquest/deffiles
cp /usr/local/share/xquest/V2.1.5/xquest/deffiles/xQuest/xquest.def /usr/local/share/xquest/deffiles/xquest.def
cp /usr/local/share/xquest/V2.1.5/xquest/deffiles/xmm/xmm.def /usr/local/share/xquest/V2.1.5/xquest/deffiles/xmm.def
cp /usr/local/share/xquest/V2.1.5/xquest/deffiles/mass_table.def /usr/local/share/xquest/V2.1.5/xquest/deffiles/mass_table.def
# Changing wtf these bastards made up god knows what for
sed -i "s#\\\/cluster\\\/apps\\\/imsb#\\/usr\\/local\\/share#g" /usr/local/share/xquest/V2.1.5/xquest/modules/Environment.pm

# Restarting Apache 2 server
sudo service apache2 restart
printf "Configuring the Apache 2 web server... Done.\n\n"
printf "Please restart your terminal to take the PATH change into account.\n"

sudo apt-get install docker.io
sudo apt-get install wine
sudo apt-get install cpanminus
sudo cpanm Bio::Perl -f

