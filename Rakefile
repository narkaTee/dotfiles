ENV.has_key? 'HOME' or raise "'HOME' Environment variable is not available"
ENV['HOME'].length > 0 or raise "'HOME' Environment variable is empty"

HOME = ENV['HOME']

require 'pathname'
require './lib/dsl'
require './lib/util'

task :default => :install
task :install => [
  :sh,
  :direnv,
  :git,
  :tmux,
  :mintty,
  :alacritty,
  :ideavim,
  :bash,
  :zsh,
  :vim,
  :k9s,
  :fonts,
  :macos,
  :vscode
]
task :shell => [
  :sh,
  :bash,
  :zsh
]
task :check => [
  :test_sh,
  :test_bash,
  :test_zsh,
  :shellcheck
]

task :shellcheck do
  dirs = ["git/scripts", "sh", "bash"]
  ignore = ["bash/bashrc.d/z.sh"]
  files = dirs.flat_map { |dir| Dir.glob("#{dir}/**/*") }.select { |f| File.file?(f) && !ignore.include?(f) }
  failed = false
  files.each do |file|
    puts "Checking #{file}"
    sh "shellcheck '#{file}'" do |ok|
      failed ||= !ok
      puts "check failed for #{file}!" unless ok
    end
  end
  raise "shellcheck failed, see output above" if failed
end

task :sh => :test_sh do
  Cfg.directory "#{HOME}/.config/shrc.d/" do
    purge
    source "sh/shrc.d/"
  end
  Cfg.directory "#{HOME}/.config/setup/" do
    purge
    ignore ['env.local.sh']
    source "sh/setup"
  end
  # The default gnu coreutils colors for backup files do not play very well with the solarized theme
  # "bright black" text is the same colors as the background. patch the colors and be happy.
  # to keep the patches definitions somewhat up to date run it every time the dotfiles are installed
  sh 'dircolors -p | sed "s/00;90/00;30/g" > "$HOME/.config/dircolors"'
end

task :direnv do
  Cfg.directory "#{HOME}/.config/direnv" do
    purge
    source "direnv"
  end
end

task :test_sh do
  Dir.glob("sh/*/*").each do |file|
     sh "dash -n '#{file}'"
     exit unless $?.exitstatus == 0
  end
end

task :bash => [:test_bash, :sh] do
  ## remove legacy directory
  sh 'rm -rf "$HOME/.bashrc.d"'
  Cfg.directory "#{HOME}/.config/bashrc.d/" do
    purge
    source "bash/bashrc.d/"
  end
  Cfg.directory "#{HOME}/.config/lib/bash" do
    purge
    source "bash/lib/"
  end
  Cfg.file("0644", dst: "#{HOME}/.bashrc", src: "bash/bashrc")
  Cfg.file("0644", dst: "#{HOME}/.bash_profile", src: "bash/bash_profile")
  sh 'install -m 700 -d "$HOME/bin"'
  sh 'cp bash/bin/* "$HOME/bin/"'
  if !is_macos
    # no bwrap in macos
    Cfg.directory "#{HOME}/.config/boxed/" do
      purge
      source "bash/boxed/"
    end
  end
end

task :test_bash do
  files = Dir.glob("bash/bash*").select { |f| File.file?(f) } +
    Dir.glob("bash/bashrc.d/*") +
    Dir.glob("bash/boxed/**/*").select { |f| File.file?(f) }
  files.each do |file|
    sh "bash -n '#{file}'"
    exit unless $?.exitstatus == 0
  end
end

task :git do
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

task :tmux => :install_tmux_plugins do
  ## remove legacy directory
  sh 'rm -rf "$HOME/.tmux/"'
  Cfg.file("0644", dst: "#{HOME}/.tmux.conf", src: "tmux/tmux.conf")
  Cfg.file("0644", dst: "#{HOME}/.config/tmux/tmuxline.conf", src: "tmux/tmuxline.conf")
end

task :install_tmux_plugins do
  sh 'git submodule update --init'
  Cfg.directory "#{HOME}/.config/tmux/plugins/" do
    purge
    source "tmux/plugins"
  end
end

task :mintty do
  sh <<-CMD.chomp
  if hash cygcheck.exe 2> /dev/null; then
    cp -f "mintty/minttyrc" "#{HOME}/.minttyrc"
  fi
  CMD
end

task :alacritty do
  Cfg.directory "#{HOME}/.config/alacritty" do
    source "alacritty"
  end
end

task :ideavim do
  Cfg.file("0644", src: ".ideavimrc")
end

task :zsh => [:test_zsh, :install_zsh_plugins, :sh, :bash] do
  Cfg.file("0644", src: "zsh/zshrc", dst: "#{HOME}/.zshrc")
  Cfg.directory "#{HOME}/.config/zshrc.d/" do
    purge
    source "zsh/zshrc.d"
  end
  Cfg.file("0644", src: "zsh/p10k.zsh", dst: "#{HOME}/.p10k.zsh")
end

task :test_zsh do
  files = ["zsh/zshrc"] + Dir.glob("zsh/**/*.zsh")
  files.each do |file|
    sh "zsh -n '#{file}'"
    exit unless $?.exitstatus == 0
  end
end

task :install_zsh_plugins do
  Cfg.git_directory("#{HOME}/.config/zsh-plugins/", {
    :powerlevel10k => "https://github.com/romkatv/powerlevel10k.git",
    :zsh_syntax_highlighting => "https://github.com/zsh-users/zsh-syntax-highlighting.git"
  })
  sh <<-CMD.chomp
  # delete removed plugins
  rm -rf "#{HOME}/.config/zsh-plugins/fast_syntax_highlighting"
  CMD
end

task :vim => :install_vim_plugins do
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
    :solarized_colors => "https://github.com/altercation/vim-colors-solarized.git",
    :sensible => "https://github.com/tpope/vim-sensible.git",
    :sorround => "https://github.com/tpope/vim-surround.git",
    :sleuth => "https://github.com/tpope/vim-sleuth.git",
    :vim_airline => "https://github.com/vim-airline/vim-airline",
    :vim_airline_themes => "https://github.com/vim-airline/vim-airline-themes",
    :vim_fugitive => "https://github.com/tpope/vim-fugitive.git",
    :vim_visual_multi => "https://github.com/mg979/vim-visual-multi.git",
    # As long as I don't change the theme it is easier to just keep the
    # exported config. I want the pane-active-border-style to differ and
    # there is no easy way to just change this color.
    #:tmuxline => "https://github.com/edkolev/tmuxline.vim.git",
    :ale => "https://github.com/dense-analysis/ale.git",
    :fzf_vim => "https://github.com/junegunn/fzf.vim.git",
  })
end

task :k9s do
  Cfg.directory "#{HOME}/.config/k9s/plugins" do
    source "k9s/plugins"
  end
end

task :fonts do
  next if !is_linux
  next if !has_command("fc-cache")
  sh 'install -m 700 -d "$HOME/.local/share/fonts"'
  sh 'cp fonts/*.ttf "$HOME/.local/share/fonts"'
  sh 'fc-cache'
end

task :macos do
  next if !is_macos
  Cfg.file("0644", src: "macos/karabiner.json", dst: "#{HOME}/.config/karabiner/karabiner.json")
end

task :vscode do
  next if ! Dir.exist?("#{HOME}/.config/Code/User/")
  Cfg.file("0644", src: "vscode/settings.json", dst: "#{HOME}/.config/Code/User/settings.json")
  if has_command("code")
    [
      'ms-azuretools.vscode-containers'
    ].each do |ext|
      sh "code --install-extension #{ext}"
    end
  end
end
