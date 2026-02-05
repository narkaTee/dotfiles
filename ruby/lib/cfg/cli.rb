# frozen_string_literal: true

require 'optparse'

module Cfg
  # IMPORTANT: All CLI commands require RSpec tests in lib/cfg/spec/cli_spec.rb
  # Run tests before committing: rake test_cfg
  # See specs/cfg.md "Testing Requirements" section for details
  module CLI
    module_function

    def run(argv)
      return cmd_help if argv.empty?

      case argv.first
      when 'list', 'ls'
        cmd_list
      when 'add'
        cmd_add(argv[1..])
      when 'import'
        cmd_import(argv[1..])
      when 'show'
        cmd_show(argv[1..])
      when 'edit'
        cmd_edit(argv[1..])
      when 'delete'
        cmd_delete(argv[1..])
      when 'rotate-key'
        cmd_rotate_key(argv[1..])
      when '--select'
        cmd_select(argv[1..])
      when '--has-profiles'
        cmd_has_profiles(argv[1..])
      when '--help', '-h', 'help'
        cmd_help
      else
        # Execution mode or unknown
        cmd_execute(argv)
      end
    rescue Error => e
      $stderr.puts "cfg: #{e.message}"
      exit 1
    end

    def cmd_help
      puts <<~HELP
        Usage: cfg <command> [options]

        Commands:
          list, ls              List available profiles
          add <profile>         Create new profile
          import <profile> <file> [-t target]  Import file as template
          show <profile> [file|env]  Show profile or template content
          edit <profile> [file|env]  Edit profile or template
          delete <profile> [file|env]  Delete profile or template
          rotate-key <old> <new>  Rotate encryption key

        Execution:
          <profile> <cmd...>    Run command with profile applied
          <profile> --export-env  Output env exports to stdout
          <profile> --export-file <target>  Output file to stdout
          <profile> --export-file --base-dir <dir>  Export files to dir

        Options:
          --select [prefix]     Select profile and output name
          --has-profiles <prefix>  Check if profiles exist for prefix (exit 0 if yes, 1 if none)
          --help, -h            Show this help
      HELP
    end

    def cmd_list
      profiles = Profiles.list_profiles

      if profiles.empty?
        puts 'No profiles configured'
        return
      end

      rows = profiles.map do |p|
        [p.name, p.description || '', p.suffix]
      end

      UI.puts_table(rows, headers: %w[Name Description Key])
    end

    def cmd_add(args)
      opts = {}
      parser = OptionParser.new do |o|
        o.on('-d', '--description DESC', 'Profile description') { |v| opts[:description] = v }
        o.on('-a', '--account ACCOUNT', '1Password account') { |v| opts[:op_account] = v }
      end
      parser.parse!(args)

      name = args.shift
      abort 'Usage: cfg add <profile> [-d description] [-a account]' unless name

      keys = Crypto.list_agent_keys
      raise KeyNotFoundError, 'No Ed25519 keys found in SSH agent' if keys.empty?

      suffix = Selector.select_ssh_key(keys)
      raise Error, 'No key selected' unless suffix

      pubkey_line, = keys.find { |_, s| s == suffix }

      profile = Profiles.create_profile(
        name,
        opts[:description],
        opts[:op_account],
        suffix,
        pubkey_line
      )

      puts "Created profile: #{profile.name}"
    end

    def cmd_import(args)
      opts = {}
      parser = OptionParser.new do |o|
        o.on('-t', '--target TARGET', 'Target path (default: source path)') { |v| opts[:target] = v }
      end
      parser.parse!(args)

      name = args.shift
      file_path = args.shift
      abort 'Usage: cfg import <profile> <file> [-t target]' unless name && file_path

      profile = Profiles.get_profile(name)
      target = opts[:target] || file_path.sub(Dir.home, '~')

      Profiles.import_file(profile, file_path, target)
      puts "Imported #{file_path} -> #{target}"
    end

    def cmd_show(args)
      name = args.shift
      type = args.shift

      abort 'Usage: cfg show <profile> [file|env]' unless name

      profile = Profiles.get_profile(name)

      case type
      when nil
        show_profile_yaml(profile)
      when 'file'
        show_file_template(profile)
      when 'env'
        show_env_template(profile)
      else
        abort "Unknown type: #{type}. Use 'file' or 'env'"
      end
    end

    def cmd_edit(args)
      name = args.shift
      type = args.shift

      abort 'Usage: cfg edit <profile> [file|env]' unless name

      profile = Profiles.get_profile(name)

      case type
      when nil
        edit_profile_metadata(profile)
      when 'file'
        edit_file_template(profile)
      when 'env'
        edit_env_template(profile)
      else
        abort "Unknown type: #{type}. Use 'file' or 'env'"
      end
    end

    def cmd_delete(args)
      name = args.shift
      type = args.shift

      abort 'Usage: cfg delete <profile> [file|env]' unless name

      case type
      when nil
        Profiles.delete_profile(name)
        puts "Deleted profile: #{name}"
      when 'file'
        profile = Profiles.get_profile(name)
        targets = profile.outputs.select { |o| o.type == 'file' }.map(&:target)
        target = Selector.select_file_target(targets)
        abort 'No file selected' unless target

        Profiles.delete_file_output(profile, target)
        puts "Deleted file template: #{target}"
      when 'env'
        profile = Profiles.get_profile(name)
        Profiles.delete_env_output(profile)
        puts 'Deleted env template'
      else
        abort "Unknown type: #{type}. Use 'file' or 'env'"
      end
    end

    def cmd_rotate_key(args)
      old_suffix = args.shift
      new_suffix = args.shift
      abort 'Usage: cfg rotate-key <old-suffix> <new-suffix>' unless old_suffix && new_suffix

      keys = Crypto.list_agent_keys
      old_key_data = keys.find { |_, s| s == old_suffix }
      new_key_data = keys.find { |_, s| s == new_suffix }

      raise KeyNotFoundError, "Old key not found: #{old_suffix}" unless old_key_data
      raise KeyNotFoundError, "New key not found: #{new_suffix}" unless new_key_data

      old_key = Crypto.derive_key(old_key_data[0])
      new_key = Crypto.derive_key(new_key_data[0])

      # Re-encrypt profiles
      profiles = Storage.load_profiles(old_suffix, old_key)
      Storage.save_profiles(new_suffix, profiles, new_key)

      # Re-encrypt templates
      config_dir = Storage.config_dir(old_suffix)
      if Dir.exist?(config_dir)
        Dir.glob(File.join(config_dir, '*.enc')).each do |file|
          content = Storage.load_template(old_suffix, File.basename(file), old_key)
          Storage.save_template(new_suffix, File.basename(file), content, new_key)
        end
      end

      # Update index
      index = Storage.load_index
      index[:index].delete(old_suffix.to_sym)
      # Store public key without comment (first two parts only: type + key)
      pubkey_without_comment = new_key_data[0].split[0..1].join(' ')
      index[:index][new_suffix.to_sym] = {
        ssh_public_key: pubkey_without_comment,
        profiles_file: "profiles-#{new_suffix}.enc"
      }
      Storage.save_index(index)

      # Clean up old files
      Storage.delete_suffix_data(old_suffix)

      puts "Rotated key from #{old_suffix} to #{new_suffix}"
    end

    def cmd_select(args)
      prefix = args.shift
      name = Selector.select_profile(prefix)
      abort 'No profile selected' unless name

      puts name
    end

    def cmd_has_profiles(args)
      prefix = args.shift
      abort 'Usage: cfg --has-profiles <prefix>' unless prefix

      profiles = Profiles.list_profiles
      matching = profiles.select { |p| p.name.start_with?(prefix) }

      exit(matching.empty? ? 1 : 0)
    end

    def cmd_execute(args)
      # Parse execution options
      opts = {}
      remaining = []
      skip_next = false

      args.each_with_index do |arg, i|
        if skip_next
          skip_next = false
          next
        end

        case arg
        when '--export-env'
          opts[:export_env] = true
        when '--export-file'
          opts[:export_file] = true
        when '--base-dir'
          abort '--base-dir requires a directory argument' unless args[i + 1]
          opts[:base_dir] = args[i + 1]
          skip_next = true
        else
          remaining << arg
        end
      end

      profile_name = remaining.shift
      abort 'Usage: cfg <profile> [--export-env|--export-file [--base-dir <dir>]|<cmd...>]' unless profile_name

      # Resolve profile name (supports prefix matching)
      resolved_name = Selector.select_profile(profile_name)
      abort "Profile not found: #{profile_name}" unless resolved_name

      profile = Profiles.get_profile(resolved_name)

      if opts[:export_env]
        puts Runner.export_env(profile)
      elsif opts[:export_file]
        if opts[:base_dir]
          paths = Runner.export_all_files(profile, opts[:base_dir])
          paths.each { |p| puts p }
        else
          target = remaining.shift
          abort 'Usage: cfg <profile> --export-file <target>' unless target

          puts Runner.export_file(profile, target)
        end
      else
        cmd = remaining
        abort 'Usage: cfg <profile> <cmd...>' if cmd.empty?

        exit_code = Runner.run_command(profile, cmd)
        exit(exit_code)
      end
    end

    # Helper methods

    def show_profile_yaml(profile)
      yaml = {
        'name' => profile.name,
        'description' => profile.description,
        'op_account' => profile.op_account,
        'outputs' => profile.outputs.map do |o|
          out = { 'template' => o.template, 'type' => o.type }
          out['target'] = o.target if o.target
          out
        end
      }.compact
      puts YAML.dump(yaml)
    end

    def show_file_template(profile)
      outputs = profile.outputs.select { |o| o.type == 'file' }
      abort 'No file templates' if outputs.empty?

      targets = outputs.map(&:target)
      target = Selector.select_file_target(targets)
      abort 'No file selected' unless target

      output = outputs.find { |o| o.target == target }
      content = Profiles.get_output_content(profile, output)
      puts content
    end

    def show_env_template(profile)
      output = profile.outputs.find { |o| o.type == 'env' }
      abort 'No env template' unless output

      content = Profiles.get_output_content(profile, output)
      puts content
    end

    def edit_profile_metadata(profile)
      yaml = YAML.dump({
                         'description' => profile.description,
                         'op_account' => profile.op_account
                       })

      new_yaml = UI.run_editor(yaml, extension: '.yaml')
      return puts 'No changes' unless new_yaml

      data = YAML.safe_load(new_yaml)
      Profiles.update_profile(
        profile,
        description: data['description'],
        op_account: data['op_account']
      )
      puts 'Profile updated'
    end

    def edit_file_template(profile)
      outputs = profile.outputs.select { |o| o.type == 'file' }

      if outputs.empty?
        # Create new file template
        target = UI.prompt_input('Target path:')
        abort 'No target specified' unless target && !target.empty?

        ext = File.extname(target)
        ext = '.txt' if ext.empty?
        new_content = UI.run_editor('', extension: ext)
        abort 'No content' unless new_content

        Profiles.add_file_template(profile, target, new_content)
        puts "Created file template: #{target}"
      else
        targets = outputs.map(&:target)
        target = Selector.select_file_target(targets)
        abort 'No file selected' unless target

        output = outputs.find { |o| o.target == target }
        content = Profiles.get_output_content(profile, output)
        ext = File.extname(target)
        ext = '.txt' if ext.empty?
        new_content = UI.run_editor(content, extension: ext)

        if new_content
          Profiles.update_output_content(profile, output, new_content)
          puts 'File template updated'
        else
          puts 'No changes'
        end
      end
    end

    def edit_env_template(profile)
      output = profile.outputs.find { |o| o.type == 'env' }

      if output
        content = Profiles.get_output_content(profile, output)
        new_content = UI.run_editor(content, extension: '.env')

        if new_content
          Profiles.update_output_content(profile, output, new_content)
          puts 'Env template updated'
        else
          puts 'No changes'
        end
      else
        new_content = UI.run_editor("# Environment variables (dotenv format)\n# KEY=op://vault/item/field\n", extension: '.env')
        abort 'No content' unless new_content

        Profiles.add_env_template(profile, new_content)
        puts 'Created env template'
      end
    end
  end
end
