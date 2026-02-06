# frozen_string_literal: true

require 'open3'

module Cfg
  module Selector
    class << self
      # Injectable picker function for testing
      attr_writer :picker

      def picker
        @picker ||= method(:fzf_pick)
      end
    end

    module_function

    # Pick an item from a list using fzf (or injected picker)
    # items: array of display strings
    # prompt: prompt text
    # Returns selected item or nil if cancelled
    def pick(items, prompt)
      return nil if items.empty?
      return items.first if items.length == 1

      Selector.picker.call(items, prompt)
    end

    # Select a profile by prefix
    # Returns profile name or nil
    def select_profile(prefix = nil)
      profiles = Profiles.list_profiles

      if prefix
        matching = profiles.select { |p| p.name.start_with?(prefix) }

        # Exact match
        exact = matching.find { |p| p.name == prefix }
        return exact.name if exact

        # Single match
        return matching.first.name if matching.length == 1

        # Multiple matches - pick
        profiles = matching
      end

      return nil if profiles.empty?

      items = profiles.map { |p| "#{p.name} - #{p.description}" }
      selected = pick(items, 'Select profile:')
      return nil unless selected

      # Handle case where description is empty (fzf may trim trailing space)
      selected.sub(/ -.*\z/, '')
    end

    # Select a file target from a profile
    # targets: array of target paths
    # Returns selected target or nil
    def select_file_target(targets)
      return nil if targets.empty?
      return targets.first if targets.length == 1

      pick(targets, 'Select file:')
    end

    # Internal: fzf picker implementation
    def fzf_pick(items, prompt)
      input = items.join("\n")
      output, status = Open3.capture2('fzf', '--prompt', prompt, stdin_data: input)
      return nil unless status.success?

      output.strip
    end
  end
end
