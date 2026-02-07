# frozen_string_literal: true

module Sandbox
  class CLI
    def self.run(argv, env: ENV, cwd: Dir.pwd, out: $stdout, err: $stderr)
      new(argv, env: env, cwd: cwd, out: out, err: err).run
    rescue Sandbox::Error => e
      err.puts(e.message)
      exit 1
    end

    def initialize(argv, env:, cwd:, out:, err:)
      @argv = argv.dup
      @env = env
      @cwd = cwd
      @out = out
      @err = err
      @spinner = Spinner.new(io: @out)
      @runner = CommandRunner.new(out: @out, err: @err)
      @bash_runner = BashRunner.new(command_runner: @runner)
      @ssh_config = SshConfig.new(@bash_runner)
      @backend_key = nil
      @proxy = false
      @sync = false
      @agents = nil
      @non_option_args = []
    end

    def run
      parse_options
      backend = build_backend
      Sandbox::Backend.ensure!(backend)

      command = @non_option_args.shift.to_s

      case command
      when '', 'start', 'enter'
        cmd_start_or_enter(backend)
      when 'idea'
        cmd_idea(backend)
      when 'code'
        cmd_code(backend)
      when 'tmux'
        cmd_tmux(backend)
      when 'proxy'
        cmd_proxy
      when 'sync'
        cmd_sync(backend)
      when 'ls', 'list'
        cmd_list
      when 'stop'
        cmd_stop(backend)
      when 'info'
        cmd_info(backend)
      when 'help', '--help', '-h'
        cmd_help(backend)
      else
        @err.puts("Error: Unknown command: #{command}")
        @err.puts
        cmd_help(backend)
        raise Sandbox::Error, "Unknown command: #{command}"
      end
    end

    private

    def parse_options
      until @argv.empty?
        arg = @argv.shift
        case arg
        when '--kvm'
          @backend_key = 'kvm'
        when '--container'
          @backend_key = 'container'
        when '--hcloud'
          @backend_key = 'hcloud'
        when '--proxy'
          @proxy = true
        when '--sync'
          @sync = true
        when '--agents'
          agents = @argv.shift
          raise Sandbox::Error, '--agents parameter is missing the value' if agents.nil? || agents.strip.empty?

          validate_agents(agents)
          @agents = agents
        else
          @non_option_args << arg
        end
      end
    end

    def validate_agents(list)
      list.split(',').each do |agent|
        @bash_runner.call('ensure_know_agent', agent)
      end
    end

    def build_backend
      backend_key = selected_backend_key
      base_backend = backend_for(backend_key)
      base_backend = Backends::Proxy.new(base_backend) if @proxy
      base_backend
    end

    def backend_for(key)
      case key
      when 'container'
        backend = Backends::Container.new(bash_runner: @bash_runner, command_runner: @runner)
      when 'kvm'
        validate_kvm_prereqs!
        backend = Backends::Kvm.new(bash_runner: @bash_runner, command_runner: @runner)
      when 'hcloud'
        backend = Backends::Hcloud.new(bash_runner: @bash_runner, command_runner: @runner, sync: @sync)
      else
        raise Sandbox::MissingBackendError, "Unknown backend: #{key}"
      end

      backend
    end

    def selected_backend_key
      selector = BackendSelector.new(backends: all_backends, sandbox_name: sandbox_name)
      selector.select_backend(@backend_key)
    end

    def all_backends
      {
        'container' => Backends::Container.new(bash_runner: @bash_runner, command_runner: @runner),
        'kvm' => Backends::Kvm.new(bash_runner: @bash_runner, command_runner: @runner),
        'hcloud' => Backends::Hcloud.new(bash_runner: @bash_runner, command_runner: @runner, sync: @sync)
      }
    end

    def sandbox_name
      Name.sandbox_name(@cwd)
    end

    def validate_no_backend_conflict
      selector = BackendSelector.new(backends: all_backends, sandbox_name: sandbox_name)
      detected = selector.detect_running_backend
      return if detected.nil? || detected == @backend_key

      raise Sandbox::BackendConflictError, "Error: Already a running #{detected} sandbox"
    end

    def ensure_sandbox_running(backend)
      return if backend.backend_is_running(sandbox_name)

      raise Sandbox::BackendNotRunningError, 'No sandbox running for current directory'
    end

    def ensure_not_inside_sandbox
      return if @env['SANDBOX_CONTAINER'].nil? || @env['SANDBOX_CONTAINER'].empty?

      raise Sandbox::Error, 'Error: Already inside sandbox container'
    end

    def cmd_start_or_enter(backend)
      ensure_not_inside_sandbox
      name = sandbox_name

      if backend.backend_is_running(name)
        @out.puts("Entering existing sandbox: #{name} (#{backend_name(backend)} backend)")
      else
        validate_no_backend_conflict
        @out.puts("Starting sandbox: #{name} (#{backend_name(backend)} backend)")
        @spinner.with_task('Starting sandbox') do
          backend.backend_start(name, use_pty: @spinner.tty?)
        end
      end

      if @agents
        @agents.split(',').each do |agent|
          bootstrap_agent(name, agent, backend)
        end
      end

      backend.backend_enter(name)
    end

    def bootstrap_agent(name, agent, backend)
      @out.puts("Bootstrapping AI agent: #{agent}")
      env = { 'BACKEND' => backend_name(backend) }
      env['PROXY'] = 'true' if @proxy
      @bash_runner.call('bootstrap_ai', name, agent, env: env, use_pty: true)
    end

    def cmd_list
      @out.puts('Running sandboxes (container backend):')
      Backends::Container.new(bash_runner: @bash_runner, command_runner: @runner).list
      @out.puts
      @out.puts('Running sandboxes (kvm backend):')
      Backends::Kvm.new(bash_runner: @bash_runner, command_runner: @runner).list
      @out.puts
      @out.puts('Running sandboxes (hcloud backend):')
      Backends::Hcloud.new(bash_runner: @bash_runner, command_runner: @runner, sync: @sync).list
    end

    def cmd_stop(backend)
      stop_all = @non_option_args.first
      if %w[-a --all].include?(stop_all)
        @out.puts('Stopping all sandboxes (all backends)...')
        Backends::Container.new(bash_runner: @bash_runner, command_runner: @runner).backend_stop_all
        Backends::Kvm.new(bash_runner: @bash_runner, command_runner: @runner).backend_stop_all
        Backends::Hcloud.new(bash_runner: @bash_runner, command_runner: @runner, sync: @sync).backend_stop_all
        @ssh_config.remove_all_aliases
        @out.puts('Done')
      else
        name = sandbox_name
        @out.puts("Stopping sandbox: #{name}")
        if backend.backend_is_running(name)
          backend.backend_stop(name)
          @ssh_config.remove_alias(name)
        end
        @out.puts('Done')
      end
    end

    def cmd_info(backend)
      name = sandbox_name
      ensure_sandbox_running(backend)
      port = backend.backend_get_ssh_port(name)
      raise Sandbox::BackendError, 'Error: Could not determine SSH port' if port.nil? || port.empty?

      ip = backend.backend_get_ip(name)
      raise Sandbox::BackendError, 'Error: Could not determine IP address' if ip.nil? || ip.empty?

      @out.puts("Sandbox: #{name}")
      @out.puts("Backend: #{backend_name(backend)}")
      @out.puts("Workspace: #{@cwd}")

      if @ssh_config.alias_setup?(name)
        @out.puts
        @out.puts('You can connect using the SSH alias:')
        @out.puts("  ssh #{name}")
      else
        @out.puts
        @out.puts('SSH connection:')
        @out.puts("  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p #{port} dev@#{ip}")
        @out.puts
        @out.puts('JetBrains Gateway:')
        @out.puts("  Host: #{ip}")
        @out.puts("  Port: #{port}")
        @out.puts('  User: dev')
      end

      if backend.respond_to?(:console_socket)
        socket = backend.console_socket(name)
        if socket && !socket.empty?
          @out.puts
          @out.puts('Connect to vm console (to exit: ctrl+] or ctrl+altgr + 9 on qwertz keyboard):')
          @out.puts("  socat STDIO,raw,echo=0,escape=0x1d UNIX-CONNECT:#{socket}")
        end
      end
    end

    def cmd_idea(backend)
      name = sandbox_name
      ensure_sandbox_running(backend)
      port = backend.backend_get_ssh_port(name)
      raise Sandbox::BackendError, 'Error: Could not determine SSH port' if port.empty?

      url = if @ssh_config.alias_setup?(name)
              "jetbrains://gateway/ssh/environment?h=#{name}&launchIde=true&ideHint=IU&projectHint=/home/dev/workspace"
            else
              "jetbrains://gateway/ssh/environment?h=localhost&u=dev&p=#{port}&launchIde=true&ideHint=IU&projectHint=/home/dev/workspace"
            end

      @out.puts("Opening IntelliJ IDEA on #{name}...")
      open_url(url)
    end

    def cmd_code(backend)
      name = sandbox_name
      ensure_sandbox_running(backend)
      port = backend.backend_get_ssh_port(name)
      raise Sandbox::BackendError, 'Error: Could not determine SSH port' if port.empty?

      remote = if @ssh_config.alias_setup?(name)
                 "ssh-remote+#{name}/home/dev/workspace"
               else
                 "ssh-remote+dev@localhost:#{port}/home/dev/workspace"
               end
      url = "vscode://vscode-remote/#{remote}"

      @out.puts("Opening Visual Studio Code on #{name}...")
      if command_available?('code')
        @runner.run(['code', '--folder-uri', "vscode-remote://#{remote}"])
      else
        open_url(url)
      end
    end

    def cmd_tmux(backend)
      name = sandbox_name
      ensure_sandbox_running(backend)
      unless command_available?('alacritty')
        @err.puts('Error: Alacritty terminal emulator not found')
        @err.puts("Please install Alacritty to use 'sandbox tmux'")
        raise Sandbox::Error, 'Alacritty not found'
      end

      @out.puts("Opening Alacritty terminal with tmux session on #{name}...")
      title = "dev@#{name} (ssh)"

      if @ssh_config.alias_setup?(name)
        Process.detach(
          Process.spawn('alacritty', '--title', title, '-e', 'ssh', '-t', name,
                        'cd /home/dev/workspace && exec tmux new-session -A')
        )
      else
        port = backend.backend_get_ssh_port(name)
        ip = backend.backend_get_ip(name)
        Process.detach(
          Process.spawn('alacritty', '--title', title, '-e', 'ssh', '-t',
                        '-o', 'UserKnownHostsFile=/dev/null',
                        '-o', 'StrictHostKeyChecking=no',
                        '-p', port, "dev@#{ip}",
                        'cd /home/dev/workspace && exec tmux new-session -A')
        )
      end
    end

    def cmd_proxy
      @bash_runner.call('cmd_proxy', *@non_option_args, use_pty: true)
    end

    def cmd_sync(backend)
      direction = @non_option_args.shift
      unless %w[up down].include?(direction)
        @err.puts("Error: sync requires 'up' or 'down' argument")
        @err.puts('Usage: sandbox sync [up|down]')
        raise Sandbox::Error, 'Invalid sync direction'
      end

      if %w[container kvm].include?(backend_name(backend))
        @err.puts('Error: sync command is only available for cloud backends (hcloud)')
        @err.puts('Container and KVM backends use bind mounts, so files are already synchronized')
        raise Sandbox::Error, 'Sync not available for this backend'
      end

      name = sandbox_name
      ensure_sandbox_running(backend)

      ssh_target = if @ssh_config.alias_setup?(name)
                     name
                   else
                     "dev@#{backend.backend_get_ip(name)}"
                   end

      if direction == 'up'
        @out.puts('Uploading current directory to sandbox workspace...')
        @runner.run(['rsync', '-hzav', '--no-o', '--no-g', '--delete',
                     '-e', 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no',
                     './', "#{ssh_target}:/home/dev/workspace/"])
      else
        @out.puts('Downloading sandbox workspace to current directory...')
        @runner.run(['rsync', '-hzav', '--no-o', '--no-g', '--delete',
                     '-e', 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no',
                     "#{ssh_target}:/home/dev/workspace/", './'])
      end
      @out.puts('Sync complete')
    end

    def cmd_help(backend)
      @out.puts <<~HELP
        sandbox - Containerized development sandbox

        Usage:
            sandbox [--kvm|--container|--hcloud] [flags] <command>

        Global Flags:
            --kvm           Use KVM backend
                            Stronger Isolation, sudo and root access inside sandbox
                            BUT: without the proxy option the vm has access to all port open on the host...
            --container     Use container backend
                            Container Isolation, no root access
            --hcloud        Use Hetzner Cloud backend
                            Cloud-based VMs with ephemeral lifecycle (destroyed on stop)
                            Requires hcloud CLI and authentication
            --sync          Sync workspace to VM (hcloud backend only)
                            Runs rsync from current directory to /home/dev/workspace
            --proxy          Force all communication to go throug a restrictive proxy
            --agents <list>  Bootstrap AI agents in the sandbox with credentials from the host
                             Accepts comma-separated list (e.g., claude,gemini)
                             Supported Agents: claude, gemini, opencode

        Backend Selection:
            The backend is automatically detected based on running sandboxes.
            If no sandbox is running, defaults to container backend.
            Use --kvm, --container, or --hcloud to explicitly select a backend.

        Commands:
            (none)        Start/enter sandbox for current directory
            idea          Open IntelliJ IDEA connected to sandbox
            code          Open Visual Studio Code connected to sandbox
            tmux          Open Alacritty terminal with tmux session
            proxy         Manage proxy and domain allowlist (see 'proxy help')
            sync up       Upload current directory to sandbox (cloud backends only)
            sync down     Download from sandbox to current directory (cloud backends only)
            list          List running sandboxes
            stop          Stop sandbox for current directory
            stop -a       Stop all sandboxes (all backends)
            info          Show SSH connection details
            help          Show this help

        Examples:
            sandbox                   Start/enter (auto-detects backend)
            sandbox --kvm             Start KVM sandbox
            sandbox --hcloud          Start Hetzner Cloud sandbox
            sandbox --hcloud --sync   Start Hetzner Cloud sandbox with workspace sync
            sandbox code              Open VS Code (auto-detects backend)
            sandbox info              Show info (auto-detects backend)
            sandbox stop -a           Stop all sandboxes

        Current backend: #{backend_name(backend)}
      HELP
    end

    def backend_name(backend)
      case backend
      when Backends::Proxy
        backend_name(backend.backend)
      when Backends::Container
        'container'
      when Backends::Kvm
        'kvm'
      when Backends::Hcloud
        'hcloud'
      else
        'unknown'
      end
    end

    def open_url(url)
      if command_available?('open')
        @runner.run(['open', url])
      else
        @err.puts('Error: open command found')
        @err.puts('Please open this URL manually:')
        @err.puts(url)
        raise Sandbox::Error, 'open command missing'
      end
    end

    def command_available?(name)
      system('command', '-v', name, out: File::NULL, err: File::NULL)
    end

    def validate_kvm_prereqs!
      unless File.exist?('/dev/kvm')
        raise Sandbox::BackendError, 'Error: KVM not available (no /dev/kvm)'
      end
      unless File.writable?('/dev/kvm')
        raise Sandbox::BackendError, 'Error: KVM not writeable for this user'
      end
      unless command_available?('qemu-system-x86_64')
        raise Sandbox::BackendError, 'Error: qemu-system-x86_64 not found'
      end
    end
  end
end
