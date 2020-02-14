HOME = ENV['HOME']

require "./lib/dsl"

task :default => :install
task :install => [
  :install_sh,
  :install_git,
  :install_tmux,
  :install_mintty,
  :install_ideavim,
  :install_zsh
]

task :install_sh => :test_sh do
  Cfg.directory "#{HOME}/.config/shrc.d/" do
    purge
    source "tmux/plugins/"
  end
end

task :test_sh do
  Dir.glob("sh/shrc.d/*.sh").each do |file|
     `dash -n "#{file}"`
     exit unless $?.exitstatus == 0
  end
end

task :install_bash => [:test_bash, :install_sh] do
  Cfg.directory "#{HOME}/.bashrc.d/" do
    purge
    source "bash/bashrc/"
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
  Cfg.directory "#{HOME}/.config/git-scripts/" do
    purge
    source "git/git-scripts/"
  end
  Cfg.directory "#{HOME}/.git_template/" do
    purge
    source "git/git_template/"
  end
  Cfg.file("0644", dst: "#{HOME}/.gitconfig.dot", src: "git/gitconfig")
  sh <<-CMD.chomp
  git config --global --get-all include.path "#{HOME}/.gitconfig.dot" > /dev/null || \
  git config --global --add include.path "#{HOME}/.gitconfig.dot"
  CMD
end

task :install_tmux => :install_tmux_plugins do
  Cfg.file("0644", dst: "#{HOME}/.tmux.conf", src: "tmux/tmux.conf")
end

task :install_tmux_plugins do
  directory "#{HOME}/.tmux/plugins/" do
    purge true
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
end

task :install_zsh_plugins do
  Cfg.git_folder("#{HOME}/.config/zsh-plugins/", {
    :powerlevel10k => "https://github.com/romkatv/powerlevel10k.git",
    :zsh_syntax_highlighting => "https://github.com/zsh-users/zsh-syntax-highlighting.git"
  })
end
