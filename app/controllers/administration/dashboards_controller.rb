class Administration::DashboardsController < ApplicationController
  before_filter :only_admins
  
  def show
    Admin.destroy_all '(select count(*) from people where people.admin_id = admins.id) = 0'
    @admin_count = Admin.count('*')
    @update_count = Update.count '*', :conditions => ['complete = ?', false]
    @group_count = Group.count '*', :conditions => ['approved = ?', false]
    @membership_request_count = MembershipRequest.count
    if @logged_in.super_admin?
      @privileges = nil
    else
      @privileges = Admin.privileges.select { |p| @logged_in.admin.flags[p] }.map { |c| c.name.humanize }
    end
  end

end
