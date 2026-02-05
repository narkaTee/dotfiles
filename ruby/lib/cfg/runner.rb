# frozen_string_literal: true

require 'open3'
require 'fileutils'

module Cfg
  module Runner
    module_function

    # Run a command with profile configuration applied
    # Returns exit code
    def run_command(profile, cmd)
      written_files = []

      # Write file templates to their targets
      profile.outputs.select { |o| o.type == 'file' }.each do |output|
        target = expand_path(output.target)
        raise FileExistsError, "Target file already exists: #{target}" if File.exist?(target)

        content = resolve_template(profile, output)
        FileUtils.mkdir_p(File.dirname(target))
        File.write(target, content)
        written_files << target
      end

      # Register cleanup
      cleanup = proc { written_files.each { |f| File.delete(f) if File.exist?(f) } }
      at_exit(&cleanup)
      Signal.trap('INT') { cleanup.call; exit(130) }
      Signal.trap('TERM') { cleanup.call; exit(143) }

      # Build command with op run if env template exists
      env_output = profile.outputs.find { |o| o.type == 'env' }
      if env_output
        env_content = Profiles.get_output_content(profile, env_output)
        exit_code = run_with_op(profile, env_content, cmd)
      else
        pid = Process.spawn(*cmd, in: :in, out: :out, err: :err)
        Process.wait(pid)
        exit_code = $?.exitstatus
      end

      cleanup.call
      exit_code
    end

    # Export environment variables as shell export statements
    def export_env(profile)
      env_output = profile.outputs.find { |o| o.type == 'env' }
      return '' unless env_output

      env_content = Profiles.get_output_content(profile, env_output)

      # Convert dotenv format to export statements, resolving op:// references
      env_content.lines.filter_map do |line|
        line = line.strip
        next if line.empty? || line.start_with?('#')
        next unless line.include?('=')

        key, value = line.split('=', 2)
        next unless key && value

        # Resolve op:// references using op read
        resolved_value = resolve_env_value(profile, value.strip)
        "export #{key}=#{shell_quote(resolved_value)}"
      end.join("\n")
    end

    # Resolve a single env value - handles op:// references
    def resolve_env_value(profile, value)
      # Check if value is an op:// reference (with or without quotes)
      unquoted = value.gsub(/\A["']|["']\z/, '')
      return value unless unquoted.start_with?('op://')

      read_op_reference(profile, unquoted)
    end

    # Read a single op:// reference using op read
    def read_op_reference(profile, reference)
      op_cmd = ['op', 'read', reference]
      op_cmd += ['--account', profile.op_account] if profile.op_account

      stdout, stderr, status = Open3.capture3(*op_cmd)
      raise Error, "op read failed: #{stderr}" unless status.success?

      stdout.chomp
    end

    # Quote a value for shell export
    def shell_quote(value)
      "'#{value.gsub("'", "'\\''")}'"
    end

    # Export a single file's resolved content
    def export_file(profile, target)
      output = profile.outputs.find { |o| o.type == 'file' && o.target == target }
      raise TemplateNotFoundError, "No file template for target: #{target}" unless output

      resolve_template(profile, output)
    end

    # Export all files to a base directory
    def export_all_files(profile, base_dir)
      written = []

      profile.outputs.select { |o| o.type == 'file' }.each do |output|
        # Strip ~ prefix and join with base_dir
        relative = output.target.sub(/\A~\//, '')
        dest = File.join(base_dir, relative)

        content = resolve_template(profile, output)
        FileUtils.mkdir_p(File.dirname(dest))
        File.write(dest, content)
        written << dest
      end

      written
    end

    # Resolve a file template using op inject
    def resolve_template(profile, output)
      content = Profiles.get_output_content(profile, output)
      resolve_with_op_inject(profile, content)
    end

    # Run command with op run
    def run_with_op(profile, env_content, cmd)
      # Write env to temp file
      env_file = Tempfile.new(['cfg-env', '.env'])
      env_file.write(env_content)
      env_file.close

      op_cmd = ['op', 'run', '--no-masking', '--env-file', env_file.path]
      op_cmd += ['--account', profile.op_account] if profile.op_account
      op_cmd << '--'
      op_cmd += cmd

      # Use spawn with explicit fd inheritance to ensure op auth prompts
      # and subprocess stdin work correctly
      pid = Process.spawn(*op_cmd, in: :in, out: :out, err: :err)
      Process.wait(pid)
      $?.exitstatus
    ensure
      env_file&.unlink
    end

    # Resolve op:// references using op inject
    def resolve_with_op_inject(profile, content)
      input_file = Tempfile.new(['cfg-inject-in', '.txt'])
      input_file.write(content)
      input_file.close

      # Warmup: signin to account before op inject to avoid race condition
      # When 1Password is locked and switching accounts, op inject fails with:
      # "multiple accounts signed in; select one by setting $OP_ACCOUNT..."
      # even though --account flag is provided. Running op signin first establishes
      # the session and prevents this error.
      if profile.op_account
        warmup_cmd = ['op', 'signin', '--account', profile.op_account]
        system(*warmup_cmd, out: File::NULL, err: File::NULL)
      end

      op_cmd = ['op', 'inject', '-i', input_file.path]
      op_cmd += ['--account', profile.op_account] if profile.op_account

      stdout, stderr, status = Open3.capture3(*op_cmd)
      raise Error, "op inject failed (#{op_cmd}): #{stderr}" unless status.success?

      stdout
    ensure
      input_file&.unlink
    end

    def expand_path(path)
      path.sub(/\A~/, Dir.home)
    end
  end
end
