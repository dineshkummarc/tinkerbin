Sequel::Model.plugin :validation_helpers

Sequel.extension :inflector
Sequel.extension :pagination

class Main
  register Sinatra::SequelExtension

  def self.models
    Object.constants.
      map    { |c| Object.const_get(c) }.
      select { |c| c.is_a?(Class) && c.ancestors.include?(Sequel::Model) }
  end

  def self.db_flush!(&blk)
    database.tables.each { |t|
      yield t  if block_given?
      database.drop_table t
    }
  end

  def self.run_migrations!(&blk)
    Dir[Main.root('app/migrations/*.rb')].sort.each { |f| load f }
  end
end

Main.run_migrations!
