def is_macos
  RUBY_PLATFORM =~/darwin/
end

def is_linux
  RUBY_PLATFORM =~/linux/
end

def has_command(cmd)
  system("which fc-cache", out: "/dev/null")
end
