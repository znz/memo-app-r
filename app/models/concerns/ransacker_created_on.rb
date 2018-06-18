module RansackerCreatedOn
  extend ActiveSupport::Concern

  included do
    case connection.adapter_name
    when "PostgreSQL"
      ransacker :created_on, type: :date do |parent|
        Arel::Nodes::SqlLiteral.new("date(#{parent.table_name}.created_at + interval '#{Time.zone.utc_offset}')")
      end
    when "SQLite"
      ransacker :created_on, type: :date do |parent|
        Arel::Nodes::SqlLiteral.new("date(#{parent.table_name}.created_at, '#{Time.zone.utc_offset} seconds')")
      end
    else
      ransacker :created_on, type: :date do |parent|
        Arel::Nodes::SqlLiteral.new("date(#{parent.table_name}.created_at)")
      end
    end
  end
end
