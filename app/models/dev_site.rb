require 'data_analysis'

class DevSite < ActiveRecord::Base
  include Services::DataAnalysis

  scope :latest, -> { joins(:statuses).order('statuses.status_date DESC') }

  mount_uploaders :images, ImagesUploader
  mount_uploaders :files, FilesUploader

  VALID_APPLICATION_TYPES = [
    'Site Plan Approval',
    'Condo Approval',
    'Subdivision Approval',
    'Zoning Amendment',
    'Registered Condominium',
    'Site Plan Control',
    'Official Plan Amendment',
    'Zoning By-law Amendment',
    'Demolition Control',
    'Cash-in-lieu of Parking',
    'Plan of Subdivision',
    'Plan of Condominium',
    'Derelict',
    'Vacant',
    'Master Plan'
  ].freeze

  VALID_BUILDING_TYPES = [
    'Not Applicable',
    'Derelict',
    'Demolition',
    'Residential Apartment',
    'Low-rise Residential',
    'Mid-rise Residential',
    'Hi-rise Residential',
    'Mixed-use Residential/Community',
    'Commercial',
    'Commercial/Hotel',
    'Mixed-use',
    'Additions'
  ].freeze

  belongs_to :municipality
  belongs_to :ward
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :addresses, as: :addressable, dependent: :destroy
  has_one  :sentiment, as: :sentimentable, dependent: :destroy
  has_many :statuses, dependent: :destroy
  has_many :city_files, dependent: :destroy
  has_many :likes, dependent: :destroy

  accepts_nested_attributes_for :addresses, allow_destroy: true
  accepts_nested_attributes_for :statuses, allow_destroy: true
  accepts_nested_attributes_for :likes, allow_destroy: true

  validates :devID,
            uniqueness: { message: 'Development Id must be unique' },
            presence: { message: 'Development Id is required' }
  validates :application_type, presence: { message: 'Application type is required' }
  validates :description, presence: { message: 'Description is required' }
  validates :municipality_id, presence: { message: 'Municipality is required' }
  validates :ward_id, presence: { message: 'Ward is required' }

  after_create do
    Resque.enqueue(NewDevelopmentNotificationJob, id) unless Rails.env.test?
  end

  after_save do
    Resque.enqueue(PruneDeadLinksJob, id) unless Rails.env.test?
  end

  def self.search(search_params)
    result = DevSite.joins(:ward, :municipality).includes(:addresses, :statuses, :comments)

    # TODO: remove when Guelph goes live
    result = result.where.not(municipalities: { name: 'Guelph' })

    result = location_search(result, search_params)
    result = query_search(result, search_params)
    result
  end

  def general_status
    return if statuses.empty?
    statuses.current.general_status
  end

  def status
    return if statuses.empty?
    statuses.current.status
  end

  def status_date
    return if statuses.empty?
    return nil unless statuses.current.status_date
    statuses.current.status_date.strftime('%B %e, %Y')
  end

  def street
    return if addresses.empty?
    addresses.first.street
  end

  def address
    return if addresses.empty?
    addresses.first.full_address(with_country: false)
  end

  def latitude
    return if addresses.empty?
    addresses.first.lat
  end

  def longitude
    return if addresses.empty?
    addresses.first.lon
  end

  def ward_name
    ward.name if ward.present?
  end

  def image_url
    return images.first.web.url if images.present?
    return streetview_image unless addresses.empty?
    ActionController::Base.helpers.image_path('mainbg.jpg')
  end

  def update_sentiment
    return unless comments.present?

    results = overall_sentiments(comments.includes(:sentiment))

    create_sentiment if sentiment.blank?

    update(add_total_suffix(results[:totals]))
    sentiment.update(results[:averages])
  end

  def self.find_ordered(ids)
    return where(id: ids) if ids.empty?
    order_clause = 'CASE dev_sites.id '
    ids.each_with_index do |id, index|
      order_clause << "WHEN #{id} THEN #{index} "
    end
    order_clause << "ELSE #{ids.length} END"
    where(id: ids).order(order_clause)
  end

  private

  def add_total_suffix(totals)
    new_totals = {}
    totals.map do |key, value|
      new_key = "#{key}_total".to_sym
      new_totals[new_key] = value
    end
    new_totals
  end

  def streetview_image
    root_url = 'https://maps.googleapis.com/maps/api/streetview'
    image_size = '600x600'
    api_key = 'AIzaSyAwocEz4rtf47zDkpOvmYTM0gmFT9USPAw'

    "#{root_url}?size=#{image_size}&location=#{address}&key=#{api_key}"
  end

  class << self
    def location_search(collection, search_params)
      lat = search_params[:latitude]
      lon = search_params[:longitude]

      return collection unless lat && lon

      dev_site_ids = []
      dev_site_ids
        .push(Address.within(5, origin: [lat, lon])
        .closest(origin: [lat, lon])
        .limit(150)
        .pluck(:addressable_id))
      collection.find_ordered(dev_site_ids.flatten.uniq)
    end

    def query_search(result, search_params)
      search_params.except(:latitude, :longitude).map do |param, value|
        result = send("search_by_#{param}", result, value)
      end
      result
    end

    def search_by_year(collection, value)
      collection.where('extract(year from updated) = ?', value)
    end

    def search_by_municipality(collection, value)
      collection.where(municipalities: { name: value })
    end

    def search_by_ward(collection, value)
      collection.where(wards: { name: value })
    end

    def search_by_status(collection, value)
      collection
        .where("statuses.status_date = (select max(statuses.status_date) \
                 from statuses where statuses.dev_site_id = dev_sites.id)")
        .where(statuses: { status: value })
    end

    def search_by_featured(collection, value)
      collection.where(featured: value)
    end
  end
end
