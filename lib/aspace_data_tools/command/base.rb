# frozen_string_literal: true

module AspaceDataTools
  module Command
    module Base
      module_function

      def exit_on_failure? = true

      def shared_options_config
        {
          input_file: {
            desc: "Path to input file",
            type: :string,
            aliases: "-i",
            required: true
          },
          command_mode: {
            required: false,
            default: "stdout",
            type: :string,
            enum: %w[stdout pry],
            aliases: "-m"
          },
          output_mode: {
            desc: "Output mode in which to run command",
            enum: %w[csv stdout],
            default: "stdout",
            type: :string,
            aliases: "-m"
          },
          output_dir: {
            desc: "Path to output directory",
            type: :string,
            default: nil,
            aliases: "-o"
          },
          output_path: {
            desc: "Path to output file",
            type: :string,
            default: nil,
            aliases: "-o"
          }
        }
      end

      def shared_options(*option_names)
        option_names.each do |option_name|
          opt = shared_options_config[option_name]
          if opt.nil?
            raise "Tried to access shared option '#{option_name}' but it "\
              "was not previously defined"
          end

          option option_name, opt
        end
      end

      def shared_option(option_name, **overrides)
        opt = shared_options_config[option_name]
        if opt.nil?
          raise "Tried to access shared option '#{option_name}' but it "\
            "was not previously defined"
        end

        option option_name, opt.merge(overrides)
      end

      def self.banner(command, namespace = nil, subcommand = false)
        "#{basename} #{subcommand_prefix} #{command.usage}"
      end

      def self.subcommand_prefix
        name.gsub(%r{.*::}, "").gsub(%r{^[A-Z]}) do |match|
          match[0].downcase
        end.gsub(%r{[A-Z]}) { |match| "-#{match[0].downcase}" }
      end
    end
  end
end
