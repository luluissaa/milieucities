object @dev_site

attributes :id, :devID, :application_type, :title, :status, :status_date, :address, :images, :files,
  :description, :ward_name, :ward_num, :image_url, :updated_at, :latitude, :longitude,
  :urban_planner_email, :ward_councillor_email, :updated

node(:current_user_id) { |_| current_user.id }

node(:likes_count) { |dev_site| dev_site.likes.count  }

node(:like) { |dev_site| Like.find_by(user_id: current_user.id, dev_site_id: dev_site.id).try(:attributes) }

node(:url) { |dev_site| dev_site_path(dev_site.id) }

child(:addresses) { attributes :id, :street }

child(:city_files) { attributes :id, :link, :name }

child(:statuses) { attributes :id, :status, :status_date }

child(:comments) { attributes :id, :body

  child(:user) { attributes :first_name, :last_name, :email }

}
