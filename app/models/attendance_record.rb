# == Schema Information
#
# Table name: attendance_records
#
#  id                :integer       not null, primary key
#  site_id           :integer       
#  person_id         :integer       
#  group_id          :integer       
#  attended_at       :datetime      
#  created_at        :datetime      
#  updated_at        :datetime      
#  external_group_id :integer       
#  first_name        :string(255)   
#  last_name         :string(255)   
#  family_name       :string(255)   
#  age               :string(255)   
#  can_pick_up       :string(100)   
#  cannot_pick_up    :string(100)   
#  medical_notes     :string(200)   
#

class AttendanceRecord < ActiveRecord::Base
  belongs_to :person
  belongs_to :group
  belongs_to :site
  scope_by_site_id
  
  validates_presence_of :group_id
  validates_presence_of :attended_at
  
  self.skip_time_zone_conversion_for_attributes = [:attended_at]
  
  def self.groups_for_date(attended_at)
    Group.all(
      :conditions => ["id in (select group_id from attendance_records where attended_at >= ? and attended_at <= ?)", attended_at.strftime('%Y-%m-%d 0:00'), attended_at.strftime('%Y-%m-%d 23:59:59')],
      :order      => 'name'
    )
  end
  
  def self.find_for_people_and_date(people_ids, date)
    all(:conditions => [
      "person_id in (?) and attended_at >= ? and attended_at <= ?",
      people_ids,
      date.strftime('%Y-%m-%d 0:00'),
      date.strftime('%Y-%m-%d 23:59:59')
    ])
  end
end
