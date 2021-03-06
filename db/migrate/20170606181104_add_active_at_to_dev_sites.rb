class AddActiveAtToDevSites < ActiveRecord::Migration
  def change
    add_column :dev_sites, :active_at, :datetime
    add_column :dev_sites, :applicant, :string
    add_column :dev_sites, :on_behalf_of, :string
    add_column :dev_sites, :urban_planner_name, :string
    add_column :dev_sites, :url_full_notice, :string
  end
end
