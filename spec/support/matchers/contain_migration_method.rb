# frozen_string_literal: true

RSpec::Matchers.define :contain_migration do |method, *args, **kwargs|
  match do |migration_file|
    dirname = File.dirname(migration_file)
    filename = File.basename(migration_file)
    timestamped_migration_file = Dir.glob("#{dirname}/[0-9]*_*.rb").grep(/\d+_#{filename}$/).first
    content = File.read(timestamped_migration_file)

    args_sep = ',\s+'
    serialized_args = args.join(args_sep)
    serialized_kwargs = kwargs.map { |key, value| "#{key}: #{value}" }.join(args_sep)

    content.match?(/#{method}\s+#{[serialized_args, serialized_kwargs].join(args_sep)}/)
  end
end
