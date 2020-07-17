ENV.has_key? 'HOME' or raise "'HOME' Environment variable is not available"
ENV['HOME'].length > 0 or raise "'HOME' Environment variable is empty"

HOME = ENV['HOME']

require 'pathname'
require './lib/dsl'

task :default => :install
task :install => [
  :install_sh,
  :install_git,
  :install_tmux,
  :install_mintty,
  :install_ideavim,
  :install_bash,
  :install_zsh,
  :install_vim
]

task :install_sh => :test_sh do
  Cfg.directory "#{HOME}/.config/shrc.d/" do
    purge
    source "sh/shrc.d/"
  end
end

task :test_sh do
  Dir.glob("sh/shrc.d/*.sh").each do |file|
     `dash -n "#{file}"`
     exit unless $?.exitstatus == 0
  end
end

task :install_bash => [:test_bash, :install_sh] do
  ## remove legacy directory
  sh 'rm -rf "$HOME/.bashrc.d"'
  Cfg.directory "#{HOME}/.config/bashrc.d/" do
    purge
    source "bash/bashrc.d/"
  end
  Cfg.file("0644", dst: "#{HOME}/.bashrc", src: "bash/bashrc")
  Cfg.file("0644", dst: "#{HOME}/.bash_profile", src: "bash/bash_profile")
end

task :test_bash do
  Dir.glob("bash/bashrc.d/*.bash").each do |file|
     `bash -n "#{file}"`
     exit unless $?.exitstatus == 0
  end
end

task :install_git do
  Cfg.directory "#{HOME}/.config/git/scripts/" do
    purge
    source "git/scripts/"
  end
  Cfg.directory "#{HOME}/.config/git/template/" do
    purge
    source "git/template/"
  end
  Cfg.file("0644", dst: "#{HOME}/.config/git/gitconfig", src: "git/gitconfig")
  sh <<-CMD.chomp
  # remove old path(s) if present
  git config --global --get-all include.path "#{HOME}/.gitconfig.dot" > /dev/null && \
  git config --global --unset include.path "#{HOME}/.gitconfig.dot"
  # delete legacy paths
  rm -f "#{HOME}/.gitconfig.dot"
  rm -rf "#{HOME}/.gitconfig.d/"
  rm -rf "#{HOME}/.config/git-scripts"
  rm -rf "#{HOME}/.git_template"

  git config --global --get-all include.path "#{HOME}/.config/git/gitconfig" > /dev/null || \
  git config --global --add include.path "#{HOME}/.config/git/gitconfig"
  CMD
end

task :install_tmux => :install_tmux_plugins do
  ## remove legacy directory
  sh 'rm -rf "$HOME/.tmux/"'
  Cfg.file("0644", dst: "#{HOME}/.tmux.conf", src: "tmux/tmux.conf")
  Cfg.file("0644", dst: "#{HOME}/.config/tmux/tmuxline.conf", src: "tmux/tmuxline.conf")
end

task :install_tmux_plugins do
  Cfg.directory "#{HOME}/.config/tmux/plugins/" do
    purge
    source "tmux/plugins"
  end
end

task :install_mintty do
  sh <<-CMD.chomp
  if hash cygcheck.exe 2> /dev/null; then
    cp -f "mintty/minttyrc" "#{HOME}/.minttyrc"
  fi
  CMD
end

task :install_ideavim do
  Cfg.file("0644", src: ".ideavimrc")
end

task :install_zsh => :install_zsh_plugins do
  Cfg.file("0644", src: "zsh/zshrc", dst: "#{HOME}/.zshrc")
  Cfg.directory "#{HOME}/.config/zshrc.d/" do
    purge
    source "zsh/zshrc.d"
  end
end

task :install_zsh_plugins do
  Cfg.git_directory("#{HOME}/.config/zsh-plugins/", {
    :powerlevel10k => "https://github.com/romkatv/powerlevel10k.git",
    :fast_syntax_highlighting => "https://github.com/zdharma/fast-syntax-highlighting"
  })
end

task :install_vim => :install_vim_plugins do
  Cfg.directory "#{HOME}/.vim/custom/" do
    source "vim/custom"
  end
  Cfg.directory "#{HOME}/.vim/ftplugin/" do
    source "vim/ftplugin"
  end
  Cfg.file("0644", src: "vim/vimrc", dst: "#{HOME}/.vim/vimrc")
end

task :install_vim_plugins do
  VIM_BUNDLE = Pathname.new( ENV['HOME'] ) + '.vim' + 'pack' + 'my-plugins' + 'start'
  Cfg.git_directory(VIM_BUNDLE, {
    :solarized_colors => "git://github.com/altercation/vim-colors-solarized.git",
    :sensible => "git://github.com/tpope/vim-sensible.git",
    :sorround => "git://github.com/tpope/vim-surround.git",
    :sleuth => "git://github.com/tpope/vim-sleuth.git",
    :vim_airline => "git://github.com/vim-airline/vim-airline",
    :vim_airline_themes => "git://github.com/vim-airline/vim-airline-themes",
    :vim_fugitive => "git://github.com/tpope/vim-fugitive.git",
    :vim_multiple_cursor => "git@github.com:terryma/vim-multiple-cursors.git",
    :tmuxline => "git@github.com:edkolev/tmuxline.vim.git"
  })
end
