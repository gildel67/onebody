class GroupsController < ApplicationController
  def index
    # people/1/groups
    if params[:person_id]
      @person = Person.find(params[:person_id])
      respond_to do |format|
        format.js   { render :partial => 'person_groups' }
        format.html { render :partial => 'person_groups', :layout => true }
        if can_export?
          format.xml { render :xml =>  @person.groups.to_xml(:except => %w(site_id)) }
          format.csv { render :text => @person.groups.to_csv(:except => %w(site_id)) }
        end
      end
    # /groups?category=Small+Groups
    # /groups?name=college
    elsif params[:category] or params[:name]
      conditions = []
      conditions.add_condition ['hidden = ? and approved = ?', false, true] unless @logged_in.admin?(:manage_groups)
      conditions.add_condition ['category = ?', params[:category]] if params[:category]
      conditions.add_condition ['name like ?', '%' + params[:name] + '%'] if params[:name]
      @groups = Group.find(:all, :conditions => conditions, :order => 'name')
      conditions[1] = true # only hidden groups
      @hidden_groups = Group.find(:all, :conditions => conditions, :order => 'name')
      respond_to do |format|
        format.html { render :action => 'search' }
        format.js
        if can_export?
          format.xml { render :xml =>  @groups.to_xml(:except => %w(site_id)) }
          format.csv { render :text => @groups.to_csv(:except => %w(site_id)) }
        end
      end
    # /groups
    else
      @categories = Group.categories
      if @logged_in.admin?(:manage_groups)
        @unapproved_groups = Group.find_all_by_approved(false)
      else
        @unapproved_groups = Group.find_all_by_creator_id_and_approved(@logged_in.id, false)
      end
      @person = @logged_in
      respond_to do |format|
        format.html
        if can_export?
          format.xml do
            @groups = Group.paginate(:order => 'name', :page => params[:page], :per_page => params[:per_page] || MAX_EXPORT_AT_A_TIME)
            render :xml =>  @groups.to_xml(:except => %w(site_id))
          end
          format.csv do
            @groups = Group.paginate(:order => 'name', :page => params[:page], :per_page => params[:per_page] || MAX_EXPORT_AT_A_TIME)
            render :text => @groups.to_csv(:except => %w(site_id))
          end
        end
      end
    end
  end
    
  def show
    @group = Group.find(params[:id])
    @stream_items = @group.shared_stream_items(20)
    @show_map = Setting.get(:services, :yahoo) && @group.mapable?
    @can_post = @group.can_post?(@logged_in)
    @can_share = @group.can_share?(@logged_in)
    @member_of = @logged_in.member_of?(@group)
    unless @group.approved? or @group.admin?(@logged_in)
      render :text => 'This group is pending approval', :layout => true
      return
    end
    unless @logged_in.can_see?(@group)
      render :text => 'Group not found.', :layout => true, :status => 404
      return
    end
  end
  
  def new
    if Site.current.max_groups.nil? or Group.count < Site.current.max_groups
      @group = Group.new(:creator_id => @logged_in.id)
      @categories = Group.categories.keys
    else
      render :text => 'No groups can be created at this time. Sorry.', :layout => true, :status => 500
    end
  end
  
  def create
    raise 'no more groups can be created' unless Site.current.max_groups.nil? or Group.count < Site.current.max_groups
    photo = params[:group].delete(:photo)
    params[:group].cleanse 'address'
    @group = Group.create(params[:group])
    unless @group.errors.any?
      if @logged_in.admin?(:manage_groups)
        @group.update_attribute(:approved, true)
        flash[:notice] = 'The group has been created.'
      else
        @group.memberships.create(:person => @logged_in, :admin => true)
        flash[:notice] = 'Your group has been created and is pending approval.'
      end
      @group.photo = photo
      redirect_to @group
    else
      @categories = Group.categories.keys
      render :action => 'new'
    end
  end
  
  def edit
    @group ||= Group.find(params[:id])
    if @logged_in.can_edit?(@group)
      @categories = Group.categories.keys
    else
      render :text => 'You are not authorized to edit this group.', :layout => true, :status => 401
    end
  end
  
  def update
    @group = Group.find(params[:id])
    if @logged_in.can_edit?(@group)
      params[:group].delete(:approved) unless @logged_in.admin?(:manage_groups)
      photo = params[:group].delete(:photo)
      params[:group].cleanse 'address'
      if @group.update_attributes(params[:group])
        flash[:notice] = 'Group settings have been saved.'
        @group.photo = photo if photo and (photo.respond_to?(:read) or photo == 'remove' or photo.class.name == 'ActionController::TestUploadedFile')
        redirect_to @group
      else
        edit; render :action => 'edit'
      end
    else
      render :text => 'You are not authorized to edit this group.', :layout => true, :status => 401
    end
  end
  
  def destroy
    @group = Group.find(params[:id])
    if @logged_in.can_edit?(@group)
      @group.destroy
      flash[:notice] = 'Group deleted.'
      redirect_to groups_path
    else
      render :text => 'You are not authorized to delete this group.', :layout => true, :status => 401
    end
  end
  
  def batch
    if @logged_in.admin?(:manage_groups)
      if request.post?
        @errors = []
        params[:groups].each do |id, details|
          group = Group.find(id)
          unless group.update_attributes(details)
            @errors << [id, group.errors.full_messages]
          end
        end
      else
        @groups = Group.all(:order => 'category, name')
      end
    else
      render :text => 'You are not authorized.', :layout => true, :status => 401
    end
  end
  
  private
  
    def feature_enabled?
      unless Setting.get(:features, :groups) and (Site.current.max_groups.nil? or Site.current.max_groups > 0)
        redirect_to people_path
        false
      end
    end
end
