class DevSite < ActiveRecord::Base
  attr_accessor :images, :files

  default_scope { order(ward_num: :asc ) }

  VALID_APPLICATION_TYPES = [ "Site Plan Control", "Official Plan Amendment", "Zoning By-law Amendment",
    "Demolition Control", "Cash-in-lieu of Parking", "Plan of Subdivision",
    "Plan of Condominium", "Derelict", "Vacant" ,"Master Plan"]

  VALID_BUILDING_TYPES = [ "Not Applicable", "Derelict", "Demolition", "Residential Apartment",
    "Low-rise Residential", "Mid-rise Residential", "Hi-rise Residential", "Mixed-use Residential/Community",
    "Commercial", "Commercial/Hotel","Mixed-use", "Additions"]

  # ASSOCIATIONS
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :addresses, dependent: :destroy
  has_many :statuses, dependent: :destroy
  has_many :city_files, dependent: :destroy
  has_many :likes, dependent: :destroy

  # delegate :lat, :lon to: :addresses, allow_nil: true

  accepts_nested_attributes_for :addresses, allow_destroy: true
  accepts_nested_attributes_for :statuses, allow_destroy: true
  accepts_nested_attributes_for :likes, allow_destroy: true

  validates :devID, uniqueness: { message: "Dev Id must be unique" }
  validates :application_type, presence: { message: "Application type is required" }
  validates :description, presence: { message: "Description is required" }
  validates :ward_name, presence: { message: "Ward name is required" }
  validates :ward_num, presence: { message: "Ward number is required" }, numericality: true


  def self.filter(filter_by)
    @dev_sites = DevSite.all
    if filter_by == "consultation" then
      @dev_sites = @dev_sites.where( 'statuses.status_date = (SELECT MAX(statuses.status_date) FROM statuses WHERE statuses.dev_site_id = dev_sites.id)' ).where( statuses: { status: ["Comment Period in Progress", "Community Information and Comment Session Open"] } )
    elsif filter_by == "new-development" then
      @dev_sites = @dev_sites.where( application_type: VALID_APPLICATION_TYPES.reject { |at| ["Derelict", "Vacant", "Unknown"].include?(at) } )
      @dev_sites = @dev_sites.where( 'statuses.status_date = (SELECT MAX(statuses.status_date) FROM statuses WHERE statuses.dev_site_id = dev_sites.id)' ).where( statuses: { status: Status::VALID_STATUS_TYPES.reject { |st| ["Unknown", "Comment Period in Progress", "Community Information and Comment Session Open"].include?(st) } } )
    elsif filter_by == "vacant-derelict" then
      @dev_sites = @dev_sites.where( application_type: ["Derelict", "Vacant", "Unknown"] )
      @dev_sites = @dev_sites.where( 'statuses.status_date = (SELECT MAX(statuses.status_date) FROM statuses WHERE statuses.dev_site_id = dev_sites.id)' ).where( statuses: { status: ["Unknown"] })
    elsif filter_by == "events" then
      @dev_sites = @dev_sites.where( 'statuses.status_date = (SELECT MAX(statuses.status_date) FROM statuses WHERE statuses.dev_site_id = dev_sites.id)' ).where( statuses: { status: ["Event"] })
    elsif filter_by == "nothing"
      # DO NOTHING
    else
      @dev_sites = @dev_sites.where(ward_num: (User::VALID_NEIGHBOURHOOD_TYPES.index(filter_by) + 1))
    end

    @dev_sites.limit(150)
  end

  def self.search(search_params)
    dev_site_ids = []
    dev_sites = DevSite.all

    if search_params[:closest].present?
      dev_site_ids
        .push(Address.closest(origin: search_params[:closest])
        .limit(500)
        .pluck(:dev_site_id))
      dev_sites = DevSite.find_ordered(dev_site_ids.flatten.uniq)
    end


    if search_params[:year].present?
      dev_sites = dev_sites
        .where('extract(year from updated) = ?', search_params[:year])
    end

    if search_params[:ward].present?
      dev_sites = dev_sites
        .where(ward_name: search_params[:ward])
    end

    if search_params[:status].present?
      dev_sites = dev_sites
        .where( 'statuses.status_date = (SELECT MAX(statuses.status_date) FROM statuses WHERE statuses.dev_site_id = dev_sites.id)' )
        .where( statuses: { status: search_params[:status] })
    end

    dev_sites
  end

  def marker
    if ["Comment Period in Progress", "Community Information and Comment Session Open"].include?(self.statuses.last.try(:status))
      marker = "consultation"
    elsif ["Event"].include?(self.statuses.last.try(:status))
      marker = "event"
    elsif ["Unknown"].include?(self.statuses.last.try(:status))
      marker = "vacant"
    else
      marker = "comment"
    end
    marker
  end

  def status
    return if self.statuses.empty?
    self.statuses.last.status
  end

  def status_date
    return if self.statuses.empty?
    self.statuses.last.status_date ? self.statuses.last.status_date.strftime("%B %e, %Y") : nil
  end

  def address
    return if self.addresses.empty?
    self.addresses.first.street
  end

  def latitude
    return if self.addresses.empty?
    self.addresses.first.geocode_lat
  end

  def longitude
    return if self.addresses.empty?
    self.addresses.first.geocode_lon
  end

  def image_hash
    return if self.images.empty?
    self.images.map do |img|
      dimensions = FastImage.size(img.url)
      { src: img.url, w: dimensions.first, h: dimensions.last }
    end
  end

  def image_url
    if self.images.present?
      self.images.first.web.url
    else
      return "https://maps.googleapis.com/maps/api/streetview?size=600x600&location=" + self.addresses.first.street + "&key=AIzaSyAwocEz4rtf47zDkpOvmYTM0gmFT9USPAw" unless self.addresses.empty?
      ActionController::Base.helpers.image_path("mainbg.jpg");
    end
  end

  mount_uploaders :images, ImagesUploader
  mount_uploaders :files, FilesUploader

end
