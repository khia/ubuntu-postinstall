#!/bin/bash
set -e

echo "Let this user use docker"


echo "hide internal partitions from unity"
declare -a hidden=(Recovery SYSTEM OS Restore)
for label in ${hidden[@]}
do
  uuid=$(sudo blkid -s UUID `blkid -L ${label}` | cut -d'"' -f2)
  # need to append all uuid and have a single list
  uuids="'${uuid}',${uuids}"
  #gsettings set com.canonical.Unity.Devices blacklist "['${uuid}']"
done
if [ ! -z "${uuids}" ]; then
  uuids=${uuids::-1}
  gsettings set com.canonical.Unity.Devices blacklist "[${uuids}]"
fi

echo "change number of workspaces"
gsettings set org.compiz.core:/org/compiz/profiles/unity/plugins/core/ vsize 2
gsettings set org.compiz.core:/org/compiz/profiles/unity/plugins/core/ hsize 2

echo "customize unity inerface"
dconf write /org/compiz/profiles/unity/plugins/unityshell/icon-size "24"

echo "Configure keyboard layout switch"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Alt>Shift_L']"
gsettings set org.gnome.libgnomekbd.keyboard layouts "['en', 'ru']"
gconftool-2 --set --type list --list-type string /desktop/gnome/peripherals/keyboard/kbd/layouts "[en, ru]"

echo "configure bash prompt"
# show git branch in bash prompt
curl https://raw.github.com/git/git/master/contrib/completion/git-prompt.sh -o ~/bin/git-prompt.sh
echo ". ~/bin/git-prompt.sh" >> ~/.bashrc
echo 'PS1="\w:\$(__git_ps1)\[$WHITE\]\$ "' >> ~/.bashrc

############################
echo "Remove ubuntu spyware"
####

gsettings set com.canonical.Unity.Lenses remote-content-search none
# gsettings set com.canonical.Unity.Lenses remote-content-search all
gsettings set com.canonical.Unity.Lenses disabled-scopes "['more_suggestions-amazon.scope', 'more_suggestions-u1ms.scope', 'more_suggestions-populartracks.scope', 'music-musicstore.scope', 'more_suggestions-ebay.scope', 'more_suggestions-ubuntushop.scope', 'more_suggestions-skimlinks.scope', 'unity-scope-gdrive.scope']"


# Block connections to Ubuntu's ad server, just in case
if ! grep -q productsearch.ubuntu.com /etc/hosts; then
  echo -e "\n127.0.0.1 productsearch.ubuntu.com" | sudo tee -a /etc/hosts >/dev/null
fi

# remove amazon from dash
sudo rm -rf /usr/share/applications/ubuntu-amazon-default.desktop

# disable error reporting to Ubuntu
sudo sed -i '/^enabled=/s/=.*/=0/' /etc/default/apport

echo "Install some languages locally"

echo "Install nodejs"
mkdir -p ~/bin/lang/nodejs && cd ~/bin/lang/nodejs
nodejs_vsn="v0.10.32"
curl http://nodejs.org/dist/${nodejs_vsn}/node-${nodejs_vsn}-linux-x64.tar.gz | tar -xvz
mv node-${nodejs_vsn}-linux-x64 ${nodejs_vsn} && mkdir -p ~/.npm

echo "Install golang"
go_vsn="1.3.3"
mkdir -p ~/bin/lang/golang && cd ~/bin/lang/golang
curl https://storage.googleapis.com/golang/go${go_vsn}.linux-amd64.tar.gz | tar -xvz
mv go go${go_vsn}

echo "Install erlang"
erlang_vsn="17.3"
sudo apt-get install -fqy libssl-dev freeglut3-dev libwxgtk2.8-dev g++ libncurses5-dev
mkdir -p ~/bin/lang/erlang && cd ~/bin/lang/erlang
curl -O https://raw.github.com/spawngrid/kerl/master/kerl; chmod a+x kerl
./kerl update releases
./kerl build ${erlang_vsn} ${erlang_vsn}
./kerl install ${erlang_vsn} ~/bin/lang/erlang/${erlang_vsn}
cd ~/bin && curl -O https://github.com/rebar/rebar/wiki/rebar; chmod a+x rebar

echo "Install elixir"
mkdir -p ~/bin/lang/elixir && cd ~/bin/lang/elixir
elixir_prefix=~/bin/lang/elixir
elixir_vsn="v1.0.0"
source ~/bin/lang/erlang/${erlang_vsn}/activate
git clone https://github.com/elixir-lang/elixir.git ${elixir_prefix}/${elixir_vsn}
cd ${elixir_prefix}/${elixir_vsn} && git checkout ${elixir_vsn} && make

echo "Install ruby"
ruby_vsn="2.1.3"
mkdir -p ~/bin/lang/ruby/.gems && cd ~/bin/lang/ruby
git clone git://github.com/sstephenson/ruby-build.git ruby-build
ruby-build/bin/ruby-build --definitions
ruby-build/bin/ruby-build ${ruby_vsn} ${ruby_vsn}
# to install gem localy set GEM_HOME env


############################
echo "Installing some software locally"
####

mkdir -p ~/bin

echo "Installing zotero"
curl https://download.zotero.org/standalone/4.0.23/Zotero-4.0.23_linux-x86_64.tar.bz2 -o ~/bin/zotero.tar.bz2 && tar -jxf zotero.tar.bz2

echo "install direnv"
mkdir -p ~/bin/tools && cd ~/bin/tools
git clone https://github.com/zimbatm/direnv.git && cd direnv
make build PATH=~/bin/lang/golang/go${go_vsn}/bin GOROOT=~/bin/lang/golang/go${go_vsn}/ && ln -s `pwd`/direnv ~/bin/direnv && make -p /home/ilya/.local/lib/go/
cat << EOF > ~/.envrc
export GOPATH="/home/ilya/.local/lib/go/"
export GOROOT="/home/ilya/bin/lang/golang/go${go_vsn}"
export GEM_HOME="home/ilya/bin/lang/ruby/.gems"
source ~/bin/lang/erlang/${erlang_vsn}/activate
export PATH=$GOROOT/bin:~/bin/lang/nodejs/${nodejs_vsn}/bin:~/bin/lang/rust/rust-0.8/bin:~/bin/lang/ruby/${ruby_vsn}/bin:${elixir_prefix}/${elixir_vsn}/bin:$$PATH
EOF
echo 'export EDITOR=emacs' >> ~/.bashrc
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
direnv allow ~
source ~/.bashrc

echo "install pass (password manager)"
sudo apt-get install -fqy pwgen xclip
git clone git://git.zx2c4.com/password-store && cd password-store && \
  sed -i 's/\(.*\)\.password-store\(.*\)/\1.local\/.pass\2/' src/password-store.sh && sudo make install
echo "source /usr/share/bash-completion/completions/pass" >> ~/.bashrc
if [ ! -d ~/.local/.pass ]; then
  gpg --gen-key
  gpg --export-secret-keys --armor example@test.com | printer
  id=$(gpg --fingerprint example@test.com | grep pub | cut -d'/' -f2 | cut -d ' ' -f1)
  pass init $id
  pass git init
fi
if ! grep --quiet pass_generate ~/.bash_aliases; then
  echo -e "alias pass_generate='pwgen -s -y 32 1'\n" >> ~/.bash_aliases
fi
