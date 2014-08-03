Sequel.migration do
  change do
    create_table(:sites) do
      primary_key :id
      column :domain, String, null: false, unique: true
      column :created_at, DateTime, null: false
    end

    create_table(:visitors) do
      primary_key :id
      foreign_key :site_id, :sites
      column :secret, String, null: false
      column :resolution, String
      column :created_at, DateTime
      column :platform, String
      column :browser, String
      column :browser_version, String
      column :country, String
      column :bucket, Integer, null: false
    end

    create_table(:visits) do
      primary_key :id
      foreign_key :visitor_id, :visitors
      column :path, String, null: false
      column :title, String, null: false
      column :referrer, String, size: 2048
      column :search_terms, String
      column :created_at, DateTime, null: false
    end

    create_table(:events) do
      primary_key :id
      foreign_key :visitor_id, :visitors
      column :label, String, null: false
      column :created_at, DateTime, null: false
    end

    create_table(:conversions) do
      primary_key :id
      foreign_key :visitor_id, :visitors
      column :label, String, null: false
      column :created_at, DateTime, null: false
      column :ended_at, DateTime
    end

    create_table(:experiments) do
      primary_key :id
      foreign_key :visitor_id, :visitors
      column :label, String, null: false
      column :bucket, String, null: false
      column :created_at, DateTime, null: false
      column :ended_at, DateTime
    end
  end
end
