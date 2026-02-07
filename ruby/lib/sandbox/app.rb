# frozen_string_literal: true

module Sandbox
  class App
    def initialize(
      backends:,
      runner: CommandRunner.new,
      spinner: Spinner.new,
      ssh_alias: SshAlias.new,
      proxy_cli: nil,
      stdout: $stdout,
      stderr: $stderr
    )
      @backends = backends
      @runner = runner
      @spinner = spinner
      @ssh_alias = ssh_alias
      @proxy_cli = proxy_cli
      @stdout = stdout
      @stderr = stderr
    end

    def run(options, args)
      backend_name = select_backend_name(options)
      backend = resolve_backend(backend_name, options[:proxy])
      BackendInterface.validate!(backend)

      validate_backend_requirements(backend)

      case args.first
      when nil, '', 'start', 'enter'
        cmd_start_or_enter(backend, options)
      when 'idea'
        cmd_idea(backend)
      when 'code'
        cmd_code(backend)
      when 'tmux'
        cmd_tmux(backend)
      when 'proxy'
        cmd_proxy(args[1..], backend)
      when 'sync'
        cmd_sync(args[1..], backend)
      when 'list', 'ls'
        cmd_list
      when 'stop'
        cmd_stop(args[1..], backend)
      when 'info'
        cmd_info(backend)
      when 'help', '--help', '-h'
        cmd_help(backend_name)
      else
        raise Error, "Unknown command: #{args.first}"
      end
    end

    private

    def select_backend_name(options)
      return options.fetch(:backend) if options[:backend]

      name = Name.from_dir
      running = @backends.values.select { |backend| backend.backend_is_running(name) }

      raise Error, 'Multiple backends running' if running.size > 1

      running.first&.name || 'container'
    end

    def resolve_backend(backend_name, proxy)
      backend = @backends.fetch(backend_name)
      return backend unless proxy

      return backend.with_proxy if backend.respond_to?(:with_proxy)

      backend
    end

    def validate_backend_requirements(backend)
      return unless backend.respond_to?(:validate_requirements)

      backend.validate_requirements
    end

    def sandbox_name
      Name.from_dir
    end

    def ensure_sandbox_running(backend)
      name = sandbox_name
      return name if backend.backend_is_running(name)

      raise Error, 'No sandbox running for current directory'
    end

    def get_ssh_port_or_fail(backend, name)
      port = backend.backend_get_ssh_port(name)
      raise Error, 'Could not determine SSH port' if port.nil? || port.empty?

      port
    end

    def cmd_start_or_enter(backend, options)
      name = sandbox_name
      raise Error, 'Already inside sandbox container' if ENV['SANDBOX_CONTAINER']

      if backend.backend_is_running(name)
        @stdout.puts("Entering existing sandbox: #{name} (#{backend.name} backend)")
      else
        validate_no_backend_conflict(backend)
        @stdout.puts("Starting sandbox: #{name} (#{backend.name} backend)")
        @spinner.run('Starting sandbox') do
          backend.backend_start(name, pty: true)
        end
      end

      bootstrap_agents(name, options, backend)

      if options[:sync]
        cmd_sync(['up'], backend)
      end

      backend.backend_enter(name)
    end

    def validate_no_backend_conflict(selected_backend)
      name = sandbox_name
      running = @backends.values.select { |backend| backend.backend_is_running(name) }
      return if running.empty?
      return if running.size == 1 && running.first.name == selected_backend.name

      raise Error, "Already a running #{running.first.name} sandbox"
    end

    def bootstrap_agents(name, options, backend)
      return unless options[:agents]&.any?

      bootstrapper = AiBootstrapper.new(
        runner: @runner,
        backend_name: backend.name,
        proxy: options.fetch(:proxy, false)
      )

      options[:agents].each do |agent|
        bootstrapper.validate_agent!(agent)
      end

      options[:agents].each do |agent|
        bootstrapper.bootstrap!(name, agent)
      end
    end

    def cmd_list
      @stdout.puts('Running sandboxes (container backend):')
      @backends.fetch('container').list
      @stdout.puts("\nRunning sandboxes (kvm backend):")
      @backends.fetch('kvm').list
      @stdout.puts("\nRunning sandboxes (hcloud backend):")
      @backends.fetch('hcloud').list
    end

    def cmd_stop(args, backend)
      stop_all = %w[-a --all].include?(args.first)

      if stop_all
        @stdout.puts('Stopping all sandboxes (all backends)...')
        @backends.values.each(&:stop_all)
        @ssh_alias.remove_all
        @stdout.puts('Done')
        return
      end

      name = sandbox_name
      @stdout.puts("Stopping sandbox: #{name}")
      if backend.backend_is_running(name)
        backend.backend_stop(name)
        @ssh_alias.remove(name)
      end
      @stdout.puts('Done')
    end

    def cmd_info(backend)
      name = ensure_sandbox_running(backend)
      port = get_ssh_port_or_fail(backend, name)
      ip = backend.backend_get_ip(name)
      raise Error, 'Could not determine IP address' if ip.nil? || ip.empty?

      @stdout.puts("Sandbox: #{name}")
      @stdout.puts("Backend: #{backend.name}")
      @stdout.puts("Workspace: #{Dir.pwd}")

      if @ssh_alias.configured?(name)
        @stdout.puts("\nYou can connect using the SSH alias:")
        @stdout.puts("  ssh #{name}")
      else
        @stdout.puts("\nSSH connection:")
        @stdout.puts("  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p #{port} dev@#{ip}")
        @stdout.puts("\nJetBrains Gateway:")
        @stdout.puts("  Host: #{ip}")
        @stdout.puts("  Port: #{port}")
        @stdout.puts('  User: dev')
      end

      return unless backend.name == 'kvm'

      console_socket = File.join(Paths.backend_state_dir('kvm', name), 'console.sock')
      @stdout.puts("\nConnect to vm console (to exit: ctrl+] or ctrl+altgr + 9 on qwertz keyboard):")
      @stdout.puts("  socat STDIO,raw,echo=0,escape=0x1d UNIX-CONNECT:#{console_socket}")
    end

    def cmd_idea(backend)
      name = ensure_sandbox_running(backend)
      port = get_ssh_port_or_fail(backend, name)
      url = if @ssh_alias.configured?(name)
              "jetbrains://gateway/ssh/environment?h=#{name}&launchIde=true&ideHint=IU&projectHint=/home/dev/workspace"
            else
              "jetbrains://gateway/ssh/environment?h=localhost&u=dev&p=#{port}&launchIde=true&ideHint=IU&projectHint=/home/dev/workspace"
            end
      @stdout.puts("Opening IntelliJ IDEA on #{name}...")
      open_url(url)
    end

    def cmd_code(backend)
      name = ensure_sandbox_running(backend)
      port = get_ssh_port_or_fail(backend, name)
      remote = if @ssh_alias.configured?(name)
                 "ssh-remote+#{name}/home/dev/workspace"
               else
                 "ssh-remote+dev@localhost:#{port}/home/dev/workspace"
               end
      url = "vscode://vscode-remote/#{remote}"
      @stdout.puts("Opening Visual Studio Code on #{name}...")

      if command_available?('code')
        @runner.run(['code', '--folder-uri', "vscode-remote://#{remote}"])
      else
        open_url(url)
      end
    end

    def cmd_tmux(backend)
      name = ensure_sandbox_running(backend)
      raise Error, 'Alacritty terminal emulator not found' unless command_available?('alacritty')

      @stdout.puts("Opening Alacritty terminal with tmux session on #{name}...")
      title = "dev@#{name} (ssh)"

      if @ssh_alias.configured?(name)
        spawn_detached(['alacritty', '--title', title, '-e', 'ssh', '-t', name,
                        'cd /home/dev/workspace && exec tmux new-session -A'])
      else
        port = get_ssh_port_or_fail(backend, name)
        ip = backend.backend_get_ip(name)
        spawn_detached(['alacritty', '--title', title, '-e', 'ssh', '-t',
                        '-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=no',
                        '-p', port.to_s, "dev@#{ip}",
                        'cd /home/dev/workspace && exec tmux new-session -A'])
      end
    end

    def cmd_sync(args, backend)
      direction = args.first
      raise Error, "sync requires 'up' or 'down' argument" unless %w[up down].include?(direction)

      if %w[container kvm].include?(backend.name)
        raise Error, 'sync command is only available for cloud backends (hcloud)'
      end

      name = ensure_sandbox_running(backend)
      ssh_target = if @ssh_alias.configured?(name)
                     name
                   else
                     ip = backend.backend_get_ip(name)
                     raise Error, 'Could not determine IP address' if ip.nil? || ip.empty?
                     "dev@#{ip}"
                   end

      if direction == 'up'
        @stdout.puts('Uploading current directory to sandbox workspace...')
        @runner.run([
          'rsync', '-hzav', '--no-o', '--no-g', '--delete',
          '-e', 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no',
          './', "#{ssh_target}:/home/dev/workspace/"
        ])
      else
        @stdout.puts('Downloading sandbox workspace to current directory...')
        @runner.run([
          'rsync', '-hzav', '--no-o', '--no-g', '--delete',
          '-e', 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no',
          "#{ssh_target}:/home/dev/workspace/", './'
        ])
      end

      @stdout.puts('Sync complete')
    end

    def cmd_proxy(args, backend)
      raise Error, 'Proxy backend not available' unless @proxy_cli

      @proxy_cli.run(args, sandbox_name)
    end

    def cmd_help(backend_name)
      @stdout.puts(<<~HELP)
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
            --proxy         Force all communication to go throug a restrictive proxy
            --agents <list> Bootstrap AI agents in the sandbox with credentials from the host
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

        Current backend: #{backend_name}
      HELP
    end

    def open_url(url)
      if command_available?('open')
        @runner.run(['open', url], allow_failure: false)
      else
        raise Error, 'open command found'
      end
    end

    def spawn_detached(cmd)
      pid = Process.spawn(*cmd)
      Process.detach(pid)
    end

    def command_available?(name)
      system("command -v #{name} >/dev/null 2>&1")
    end
  end
end
