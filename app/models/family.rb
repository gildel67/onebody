# == Schema Information
#
# Table name: families
#
#  id                   :integer       not null, primary key
#  name                 :string(255)   
#  last_name            :string(255)   
#  address1             :string(255)   
#  address2             :string(255)   
#  city                 :string(255)   
#  state                :string(10)    
#  zip                  :string(10)    
#  home_phone           :string(25)    
#  email                :string(255)   
#  latitude             :float         
#  longitude            :float         
#  share_address        :boolean       default(TRUE)
#  share_mobile_phone   :boolean       
#  share_work_phone     :boolean       
#  share_fax            :boolean       
#  share_email          :boolean       
#  share_birthday       :boolean       default(TRUE)
#  share_anniversary    :boolean       default(TRUE)
#  legacy_id            :integer       
#  updated_at           :datetime      
#  wall_enabled         :boolean       default(TRUE)
#  visible              :boolean       default(TRUE)
#  share_activity       :boolean       default(TRUE)
#  site_id              :integer       
#  share_home_phone     :boolean       default(TRUE)
#  deleted              :boolean       
#  barcode_id           :string(50)    
#  barcode_assigned_at  :datetime      
#  barcode_id_changed   :boolean       
#  alternate_barcode_id :string(50)    
#

class Family < ActiveRecord::Base
  has_many :people, :order => 'sequence', :dependent => :destroy
  accepts_nested_attributes_for :people
  belongs_to :site
  
  scope_by_site_id
  
  has_one_photo :path => "#{DB_PHOTO_PATH}/families", :sizes => PHOTO_SIZES
  acts_as_logger LogItem
  
  alias_method 'photo_without_logging=', 'photo='
  def photo=(p)
    LogItem.create :loggable_type => 'Recipe', :loggable_id => id, :object_changes => {'photo' => (p ? 'changed' : 'removed')}, :person => Person.logged_in
    self.photo_without_logging = p
  end
  
  sharable_attributes :mobile_phone, :address, :anniversary
  
  validates_uniqueness_of :barcode_id, :allow_nil => true
  validates_uniqueness_of :alternate_barcode_id, :allow_nil => true
  validates_length_of :barcode_id, :alternate_barcode_id, :in => 10..50, :allow_nil => true
  validates_format_of :barcode_id, :alternate_barcode_id, :with => /^\d+$/, :allow_nil => true
  
  validates_each [:barcode_id, :alternate_barcode_id] do |record, attribute, value|
    if attribute.to_s == 'barcode_id' and record.barcode_id
      if record.barcode_id == record.alternate_barcode_id
        record.errors.add(attribute, 'cannot be same as alternate barcode id')
      elsif Family.count('*', :conditions => ['alternate_barcode_id = ?', record.barcode_id]) > 0
        record.errors.add(attribute, 'is already taken')
      end
    elsif attribute.to_s == 'alternate_barcode_id' and record.alternate_barcode_id
      if Family.count('*', :conditions => ['barcode_id = ?', record.alternate_barcode_id]) > 0
        record.errors.add(attribute, 'is already taken')
      end
    end
  end
  
  def barcode_id=(b)
    write_attribute(:barcode_id, b.to_s.strip.any? ? b : nil)
    write_attribute(:barcode_assigned_at, Time.now.utc)
  end
  
  def alternate_barcode_id=(b)
    write_attribute(:alternate_barcode_id, b.to_s.strip.any? ? b : nil)
    write_attribute(:barcode_assigned_at, Time.now.utc)
  end
  
  def address
    address1.to_s + (address2.to_s.any? ? "\n#{address2}" : '')
  end
  
  def mapable?
    address1.to_s.any? and city.to_s.any? and state.to_s.any? and zip.to_s.any?
  end
  
  def mapable_address
    if mapable? 
      "#{address1}, #{address2.to_s.any? ? address2+', ' : ''}#{city}, #{state} #{zip}".gsub(/'/, "\\'")
    end
  end
  
  # not HTML-escaped!
  def pretty_address
    a = ''
    a << address1.to_s   if address1.to_s.any?
    a << ", #{address2}" if address2.to_s.any?
    if city.to_s.any? and state.to_s.any?
      a << "\n#{city}, #{state}"
      a << "  #{zip}" if zip.to_s.any?
    end
  end
  
  def short_zip
    zip.to_s.split('-').first
  end
  
  def latitude
    return nil unless mapable?
    update_lat_lon unless read_attribute(:latitude) and read_attribute(:longitude)
    read_attribute :latitude
  end
  
  def longitude
    return nil unless mapable?
    update_lat_lon unless read_attribute(:latitude) and read_attribute(:longitude)
    read_attribute :longitude
  end
  
  def update_lat_lon
    return nil unless mapable? and Setting.get(:services, :yahoo).to_s.any?
    url = "http://api.local.yahoo.com/MapsService/V1/geocode?appid=#{Setting.get(:services, :yahoo)}&location=#{URI.escape(mapable_address)}"
    begin
      xml = URI(url).read
      result = REXML::Document.new(xml).elements['/ResultSet/Result']
      lat, lon = result.elements['Latitude'].text.to_f, result.elements['Longitude'].text.to_f
    rescue
      logger.error("Could not get latitude and longitude for address #{mapable_address} for family #{name}.")
    else
      update_attributes :latitude => lat, :longitude => lon
    end
  end
  
  self.digits_only_for_attributes = [:home_phone]

  def children_without_consent
    people.select { |p| !p.consent_or_13? }
  end
  
  def visible_people
    people.find(:all).select do |person|
      !person.deleted? and (
        Person.logged_in.admin?(:view_hidden_profiles) or
        person.visible?(self)
      )
    end
  end
  
  before_update :mark_barcode_id_changed
  def mark_barcode_id_changed
    if changed.include?('barcode_id')
      self.write_attribute(:barcode_id_changed, true)
    end
  end
  
  alias_method :destroy_for_real, :destroy
  def destroy
    people.all.each { |p| p.destroy }
    update_attributes!(:deleted => true)
  end
  
  def self.new_with_default_sharing(attrs)
    attrs.symbolize_keys!
    attrs.merge!(
      :share_address      => Setting.get(:privacy, :share_address_by_default),
      :share_home_phone   => Setting.get(:privacy, :share_home_phone_by_default),
      :share_mobile_phone => Setting.get(:privacy, :share_mobile_phone_by_default),
      :share_work_phone   => Setting.get(:privacy, :share_work_phone_by_default),
      :share_fax          => Setting.get(:privacy, :share_fax_by_default),
      :share_email        => Setting.get(:privacy, :share_email_by_default),
      :share_birthday     => Setting.get(:privacy, :share_birthday_by_default),
      :share_anniversary  => Setting.get(:privacy, :share_anniversary_by_default)
    )
    new(attrs)
  end
end
