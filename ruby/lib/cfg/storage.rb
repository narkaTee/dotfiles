# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'digest'

module Cfg
  module Storage
    INDEX_FILE = 'index.yaml'

    module_function

    # Base directory for cfg data (hardcoded to match dotfiles layout)
    def cfg_dir
      File.join(Dir.home, 'dotfiles', 'cfg')
    end

    # Directory for encrypted config templates for a given suffix
    def config_dir(suffix)
      File.join(cfg_dir, 'configs', suffix)
    end

    # Load the index file (unencrypted YAML)
    def load_index
      path = File.join(cfg_dir, INDEX_FILE)
      return default_index unless File.exist?(path)

      YAML.safe_load_file(path, symbolize_names: true) || default_index
    end

    # Save the index file
    def save_index(data)
      FileUtils.mkdir_p(cfg_dir)
      path = File.join(cfg_dir, INDEX_FILE)
      File.write(path, YAML.dump(stringify_keys(data)))
    end

    # Load encrypted profiles file for a given suffix
    def load_profiles(suffix, key)
      path = profiles_path(suffix)
      return {} unless File.exist?(path)

      encrypted = File.read(path)
      yaml = Crypto.decrypt(encrypted, key)
      YAML.safe_load(yaml, symbolize_names: true) || {}
    end

    # Save encrypted profiles file for a given suffix
    def save_profiles(suffix, data, key)
      FileUtils.mkdir_p(cfg_dir)
      yaml = YAML.dump(stringify_keys(data))
      encrypted = Crypto.encrypt(yaml, key)
      File.write(profiles_path(suffix), encrypted)
    end

    # Load an encrypted template file
    def load_template(suffix, template_name, key)
      path = File.join(config_dir(suffix), template_name)
      raise TemplateNotFoundError, "Template not found: #{template_name}" unless File.exist?(path)

      encrypted = File.read(path)
      Crypto.decrypt(encrypted, key)
    end

    # Save an encrypted template file
    def save_template(suffix, template_name, content, key)
      dir = config_dir(suffix)
      FileUtils.mkdir_p(dir)
      encrypted = Crypto.encrypt(content, key)
      File.write(File.join(dir, template_name), encrypted)
    end

    # Delete a template file
    def delete_template(suffix, template_name)
      path = File.join(config_dir(suffix), template_name)
      File.delete(path) if File.exist?(path)
    end

    # Generate a unique template filename from content
    def generate_template_name(content)
      hash = Digest::SHA256.hexdigest(content)[0, 7]
      "#{hash}.enc"
    end

    # Path to profiles file for a suffix
    def profiles_path(suffix)
      File.join(cfg_dir, "profiles-#{suffix}.enc")
    end

    # Delete all data for a suffix (profiles file + config dir)
    def delete_suffix_data(suffix)
      File.delete(profiles_path(suffix)) if File.exist?(profiles_path(suffix))
      FileUtils.rm_rf(config_dir(suffix))
    end

    def default_index
      {
        encryption: { namespace: Crypto::NAMESPACE },
        index: {}
      }
    end

    # Convert symbol keys to strings for YAML output
    def stringify_keys(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_s).transform_values { |v| stringify_keys(v) }
      when Array
        obj.map { |v| stringify_keys(v) }
      else
        obj
      end
    end
  end
end
