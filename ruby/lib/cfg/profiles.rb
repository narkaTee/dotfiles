# frozen_string_literal: true

module Cfg
  # Data structures for profiles
  Profile = Data.define(:name, :description, :op_account, :outputs, :suffix)
  Output = Data.define(:template, :type, :target)

  class InvalidProfileNameError < Error; end
  class InvalidTargetPathError < Error; end

  module Profiles
    VALID_NAME_PATTERN = /\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/

    module_function

    def validate_profile_name!(name)
      return if name.match?(VALID_NAME_PATTERN)

      raise InvalidProfileNameError,
            "Invalid profile name '#{name}'. Must start with alphanumeric, contain only alphanumeric, dots, underscores, hyphens."
    end

    def validate_target_path!(path)
      return if path.start_with?('~/', '/')

      raise InvalidTargetPathError,
            "Invalid target path '#{path}'. Must be absolute (start with '/' or '~/')."
    end

    # List all profiles across all available keys
    # Returns array of Profile structs
    def list_profiles
      keys = Crypto.list_agent_keys
      raise KeyNotFoundError, 'No Ed25519 keys found in SSH agent' if keys.empty?

      index = Storage.load_index

      profiles = []
      keys.each do |pubkey_line, suffix|
        next unless index[:index]&.key?(suffix.to_sym)

        key = Crypto.derive_key(pubkey_line)
        profile_data = Storage.load_profiles(suffix, key)

        profile_data.each do |name, data|
          outputs = (data[:outputs] || []).map do |o|
            Output.new(template: o[:template], type: o[:type], target: o[:target])
          end
          profiles << Profile.new(
            name: name.to_s,
            description: data[:description],
            op_account: data[:op_account],
            outputs: outputs,
            suffix: suffix
          )
        end
      end

      profiles
    end

    # Get a specific profile by name
    def get_profile(name)
      profile = list_profiles.find { |p| p.name == name }
      raise ProfileNotFoundError, "Profile not found: #{name}" unless profile

      profile
    end

    # Create a new profile
    def create_profile(name, description, op_account, suffix, pubkey_line)
      validate_profile_name!(name)
      index = Storage.load_index
      key = Crypto.derive_key(pubkey_line)

      # Ensure suffix is in index
      unless index[:index]&.key?(suffix.to_sym)
        index[:index] ||= {}
        # Store public key without comment (first two parts only: type + key)
        pubkey_without_comment = pubkey_line.split[0..1].join(' ')
        index[:index][suffix.to_sym] = {
          ssh_public_key: pubkey_without_comment,
          profiles_file: "profiles-#{suffix}.enc"
        }
        Storage.save_index(index)
      end

      # Check profile doesn't exist
      profiles = Storage.load_profiles(suffix, key)
      raise ProfileExistsError, "Profile already exists: #{name}" if profiles.key?(name.to_sym)

      # Add profile
      profiles[name.to_sym] = {
        description: description,
        op_account: op_account,
        outputs: []
      }
      Storage.save_profiles(suffix, profiles, key)

      get_profile(name)
    end

    # Update a profile's metadata
    def update_profile(profile, description: nil, op_account: nil)
      key = derive_key_for_suffix(profile.suffix)
      profiles = Storage.load_profiles(profile.suffix, key)

      data = profiles[profile.name.to_sym]
      data[:description] = description if description
      data[:op_account] = op_account if op_account

      Storage.save_profiles(profile.suffix, profiles, key)
      get_profile(profile.name)
    end

    # Delete a profile and its templates
    def delete_profile(name)
      profile = get_profile(name)
      key = derive_key_for_suffix(profile.suffix)
      profiles = Storage.load_profiles(profile.suffix, key)

      # Delete associated templates
      profile.outputs.each do |output|
        Storage.delete_template(profile.suffix, output.template)
      end

      profiles.delete(profile.name.to_sym)
      Storage.save_profiles(profile.suffix, profiles, key)
    end

    # Add a file template to a profile
    def add_file_template(profile, target, content)
      validate_target_path!(target)
      key = derive_key_for_suffix(profile.suffix)
      profiles = Storage.load_profiles(profile.suffix, key)
      data = profiles[profile.name.to_sym]

      # Remove existing template with same target
      existing = data[:outputs]&.find { |o| o[:type] == 'file' && o[:target] == target }
      if existing
        Storage.delete_template(profile.suffix, existing[:template])
        data[:outputs].delete(existing)
      end

      template_name = Storage.generate_template_name(content)
      Storage.save_template(profile.suffix, template_name, content, key)

      data[:outputs] ||= []
      data[:outputs] << { template: template_name, type: 'file', target: target }
      Storage.save_profiles(profile.suffix, profiles, key)

      get_profile(profile.name)
    end

    # Add or update env template for a profile
    def add_env_template(profile, content)
      key = derive_key_for_suffix(profile.suffix)
      profiles = Storage.load_profiles(profile.suffix, key)
      data = profiles[profile.name.to_sym]

      # Remove existing env template
      existing = data[:outputs]&.find { |o| o[:type] == 'env' }
      if existing
        Storage.delete_template(profile.suffix, existing[:template])
        data[:outputs].delete(existing)
      end

      template_name = Storage.generate_template_name(content)
      Storage.save_template(profile.suffix, template_name, content, key)

      data[:outputs] ||= []
      data[:outputs] << { template: template_name, type: 'env' }
      Storage.save_profiles(profile.suffix, profiles, key)

      get_profile(profile.name)
    end

    # Get decrypted content for an output
    def get_output_content(profile, output)
      key = derive_key_for_suffix(profile.suffix)
      Storage.load_template(profile.suffix, output.template, key)
    end

    # Update content for an output
    def update_output_content(profile, output, content)
      key = derive_key_for_suffix(profile.suffix)
      profiles = Storage.load_profiles(profile.suffix, key)
      data = profiles[profile.name.to_sym]

      # Find and update the output
      out_data = data[:outputs].find { |o| o[:template] == output.template }
      return unless out_data

      # Delete old template, save new one
      Storage.delete_template(profile.suffix, output.template)
      new_template = Storage.generate_template_name(content)
      Storage.save_template(profile.suffix, new_template, content, key)

      out_data[:template] = new_template
      Storage.save_profiles(profile.suffix, profiles, key)

      get_profile(profile.name)
    end

    # Delete a file output from a profile
    def delete_file_output(profile, target)
      key = derive_key_for_suffix(profile.suffix)
      profiles = Storage.load_profiles(profile.suffix, key)
      data = profiles[profile.name.to_sym]

      output = data[:outputs]&.find { |o| o[:type] == 'file' && o[:target] == target }
      return unless output

      Storage.delete_template(profile.suffix, output[:template])
      data[:outputs].delete(output)
      Storage.save_profiles(profile.suffix, profiles, key)

      get_profile(profile.name)
    end

    # Delete env output from a profile
    def delete_env_output(profile)
      key = derive_key_for_suffix(profile.suffix)
      profiles = Storage.load_profiles(profile.suffix, key)
      data = profiles[profile.name.to_sym]

      output = data[:outputs]&.find { |o| o[:type] == 'env' }
      return unless output

      Storage.delete_template(profile.suffix, output[:template])
      data[:outputs].delete(output)
      Storage.save_profiles(profile.suffix, profiles, key)

      get_profile(profile.name)
    end

    # Import a file as a template
    def import_file(profile, file_path, target)
      content = File.read(file_path)
      add_file_template(profile, target, content)
    end

    # Helper to derive key for a suffix
    def derive_key_for_suffix(suffix)
      keys = Crypto.list_agent_keys
      pubkey_line, = keys.find { |_, s| s == suffix }
      raise KeyNotFoundError, "Key not found for suffix: #{suffix}" unless pubkey_line

      Crypto.derive_key(pubkey_line)
    end
  end
end
