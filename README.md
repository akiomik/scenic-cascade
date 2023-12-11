# Scenic::Dependencies

`scenic-dependencies` generates migration files with cascading view updates using [scenic](https://github.com/scenic-views/scenic).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'scenic-dependencies'
```

And then execute:

```shell-session
$ bundle install
```

Or install it yourself as:

```shell-session
$ gem install scenic-dependencies
```

## Usage

To generate migration files, use `scenic:view:cascade` generator instead of `scenic:view`.
The following example generates migration files for `search_results` view.

```shell-session
$ bin/rails generate scenic:view:cascade search_results
      create db/views/search_results_v01.sql
      create db/migrate/20220714233704_create_search_results.rb
```

## How it works

Consider a situation where the following three views exist:

* `first_results` is a parent view (version 1)
* `second_results` is a materialized view that depends on `first_results` (version 3)
* `third_results` is a view that depends on `first_results` and `second_results` (version 2)

```sql
-- first_results
SELECT 'foo' AS bar;

-- second_results
SELECT * FROM first_results;

-- third_results
SELECT * FROM first_results UNION SELECT * FROM second_results;
```

Executing the `scenic:view:cascade` generator for `first_results` in this state will generate the following migration file:

```shell-session
$ bin/rails generate scenic:view:cascade first_results
      create db/views/first_results_v02.sql
      create db/migrate/20220714233704_update_first_results_to_version_2.rb
```

Since all dependencies are described, you can execute `bin/rails db:migrate` without changing the migration file.

> [!WARNING]
> Currently, index re-creation is not supported.
> Please change a migration file to recreate indexes if it contains `drop_view` for materialized views.

```ruby
class UpdateSearchResultsToVersion2 < ActiveRecord::Migration
  def change
    drop_view :third_results, revert_to_version: 2, materialized: false
    drop_view :second_results, revert_to_version: 3, materialized: true
    replace_view :first_results, version: 2, revert_to_version: 1
    create_view :second_results, version: 3, materialized: true
    create_view :third_results, version: 2, materialized: false
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/akiomik/scenic-dependencies. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/akiomik/scenic-dependencies/blob/main/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the Scenic::Dependencies project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/akiomik/scenic-dependencies/blob/main/CODE_OF_CONDUCT.md).
