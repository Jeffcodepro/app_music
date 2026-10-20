module IsolatedTestCommand
  MIGRATION_TASKS = %w[db:migrate db:migrate:status db:version].freeze
  FLAGS = %w[-v --verbose -b --backtrace --fail-fast].freeze
  VALUES = %w[-n --name --seed].freeze

  def self.allowed?(arguments, root: File.expand_path("..", __dir__))
    return true if arguments.empty?
    return arguments.size == 1 if MIGRATION_TASKS.include?(arguments.first)
    return false unless arguments.first == "test"
    args = arguments.drop(1)
    until args.empty?
      arg = args.shift
      next if FLAGS.include?(arg)
      if VALUES.include?(arg)
        value = args.shift
        return false if value.nil? || value.start_with?("-") || (arg == "--seed" && !value.match?(/\A\d+\z/))
        next
      end
      return false unless arg.match?(/\Atest(?:\/[a-zA-Z0-9_\/-]+(?:\.rb)?(?::\d+)?)?\z/)
      path = File.realpath(File.join(root, arg.sub(/:\d+\z/, "")))
      return false unless path == File.join(root, "test") || path.start_with?(File.join(root, "test") + "/")
    end
    true
  rescue Errno::ENOENT, Errno::EACCES
    false
  end
end
