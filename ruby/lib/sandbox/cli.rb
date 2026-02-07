# frozen_string_literal: true

require 'optparse'

module Sandbox
  module CLI
    module_function

    def run(argv)
      options = {
        backend: nil,
        proxy: false,
        sync: false,
        agents: nil
      }

      parser = OptionParser.new do |o|
        o.on('--kvm') { options[:backend] = 'kvm' }
        o.on('--container') { options[:backend] = 'container' }
        o.on('--hcloud') { options[:backend] = 'hcloud' }
        o.on('--proxy') { options[:proxy] = true }
        o.on('--sync') { options[:sync] = true }
        o.on('--agents LIST') { |list| options[:agents] = list }
        o.on('--help', '-h') { options[:help] = true }
      end

      args = parser.parse(argv)

      if options[:help]
        app(options).run(options, ['help'])
        return
      end

      if options[:agents]
        options[:agents] = options[:agents].split(',').map(&:strip).reject(&:empty?)
      end

      app(options).run(options, args)
    rescue Error => e
      $stderr.puts("sandbox: #{e.message}")
      exit 1
    end

    def app(options)
      runner = CommandRunner.new
      ssh_alias = SshAlias.new
      backends = {
        'container' => Backends::Container.new(runner: runner, proxy: options[:proxy]),
        'kvm' => Backends::Kvm.new(runner: runner, proxy: options[:proxy]),
        'hcloud' => Backends::Hcloud.new(runner: runner, ssh_alias: ssh_alias)
      }

      App.new(
        backends: backends,
        runner: runner,
        spinner: Spinner.new,
        ssh_alias: ssh_alias,
        proxy_cli: ProxyCli.new(runner: runner)
      )
    end
  end
end
