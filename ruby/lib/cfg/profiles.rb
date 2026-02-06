# frozen_string_literal: true

module Cfg
  Profile = Data.define(:name, :description, :op_account, :outputs)
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

    def list_profiles
      Git.auto_sync!

      profile_names = Storage.list_profile_names
      profile_names.map do |name|
        data = Storage.load_profile(name)
        outputs = (data[:outputs] || []).map do |o|
          Output.new(template: o[:template], type: o[:type], target: o[:target])
        end
        Profile.new(
          name: name,
          description: data[:description],
          op_account: data[:op_account],
          outputs: outputs
        )
      end
    end

    def get_profile(name)
      Git.auto_sync!

      profile = list_profiles.find { |p| p.name == name }
      raise ProfileNotFoundError, "Profile not found: #{name}" unless profile

      profile
    end

    def create_profile(name, description, op_account)
      validate_profile_name!(name)
      Git.ensure_repo!

      existing = Storage.list_profile_names
      raise ProfileExistsError, "Profile already exists: #{name}" if existing.include?(name)

      profile_data = {
        description: description,
        op_account: op_account,
        outputs: []
      }
      Storage.save_profile(name, profile_data)
      Git.commit!("cfg: Add profile #{name}")
      Git.push!

      get_profile(name)
    end

    def update_profile(profile, description: nil, op_account: nil)
      data = Storage.load_profile(profile.name)

      data[:description] = description if description
      data[:op_account] = op_account if op_account

      Storage.save_profile(profile.name, data)
      Git.commit!("cfg: Update profile #{profile.name}")
      Git.push!

      get_profile(profile.name)
    end

    def delete_profile(name)
      profile = get_profile(name)

      profile.outputs.each do |output|
        Storage.delete_template(output.template)
      end

      Storage.delete_profile(name)
      Git.commit!("cfg: Delete profile #{name}")
      Git.push!
    end

    def add_file_template(profile, target, content)
      validate_target_path!(target)
      data = Storage.load_profile(profile.name)

      existing = data[:outputs]&.find { |o| o[:type] == 'file' && o[:target] == target }
      if existing
        Storage.delete_template(existing[:template])
        data[:outputs].delete(existing)
      end

      extension = File.extname(target)[1..] || 'txt'
      template_name = Storage.generate_template_name(content, extension)
      Storage.save_template(template_name, content)

      data[:outputs] ||= []
      data[:outputs] << { template: template_name, type: 'file', target: target }
      Storage.save_profile(profile.name, data)
      Git.commit!("cfg: Add file template to #{profile.name}: #{target}")
      Git.push!

      get_profile(profile.name)
    end

    def add_env_template(profile, content)
      data = Storage.load_profile(profile.name)

      existing = data[:outputs]&.find { |o| o[:type] == 'env' }
      if existing
        Storage.delete_template(existing[:template])
        data[:outputs].delete(existing)
      end

      template_name = Storage.generate_template_name(content, 'env')
      Storage.save_template(template_name, content)

      data[:outputs] ||= []
      data[:outputs] << { template: template_name, type: 'env' }
      Storage.save_profile(profile.name, data)
      Git.commit!("cfg: Add env template to #{profile.name}")
      Git.push!

      get_profile(profile.name)
    end

    def get_output_content(profile, output)
      Storage.load_template(output.template)
    end

    def update_output_content(profile, output, content)
      data = Storage.load_profile(profile.name)

      out_data = data[:outputs].find { |o| o[:template] == output.template }
      return unless out_data

      Storage.delete_template(output.template)

      extension = case output.type
                  when 'env'
                    'env'
                  when 'file'
                    File.extname(output.target)[1..] || 'txt'
                  else
                    'txt'
                  end

      new_template = Storage.generate_template_name(content, extension)
      Storage.save_template(new_template, content)

      out_data[:template] = new_template
      Storage.save_profile(profile.name, data)
      Git.commit!("cfg: Update template in #{profile.name}")
      Git.push!

      get_profile(profile.name)
    end

    def delete_file_output(profile, target)
      data = Storage.load_profile(profile.name)

      output = data[:outputs]&.find { |o| o[:type] == 'file' && o[:target] == target }
      return unless output

      Storage.delete_template(output[:template])
      data[:outputs].delete(output)
      Storage.save_profile(profile.name, data)
      Git.commit!("cfg: Delete file output from #{profile.name}: #{target}")
      Git.push!

      get_profile(profile.name)
    end

    def delete_env_output(profile)
      data = Storage.load_profile(profile.name)

      output = data[:outputs]&.find { |o| o[:type] == 'env' }
      return unless output

      Storage.delete_template(output[:template])
      data[:outputs].delete(output)
      Storage.save_profile(profile.name, data)
      Git.commit!("cfg: Delete env output from #{profile.name}")
      Git.push!

      get_profile(profile.name)
    end

    def import_file(profile, file_path, target)
      content = File.read(file_path)
      add_file_template(profile, target, content)
    end
  end
end
