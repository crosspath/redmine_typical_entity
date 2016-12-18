class GeneralController < ApplicationController
  unloadable

  before_filter :require_login
  before_filter :build_model_object, :only => [:new, :create]
  before_filter :find_model_object, :only => [:show, :edit, :update]
  before_filter :update_model_object_from_params, :only => [:edit, :update]
  before_filter :find_model_objects, :only => [:destroy]

  # !!!
  # model_object <SomeEntity>

  helper :sort
  include SortHelper
  helper :queries
  include QueriesHelper
  helper :attachments
  include AttachmentsHelper
  helper IssuesHelper
  include Redmine::Export::PDF
  helper CustomFieldsHelper
  # helper JournalizedHelper

  def index
    retrieve_query
    sort_init(@query.sort_criteria.empty? ? [['id']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      case params[:format]
        when 'csv', 'pdf'
          @limit = Setting.issues_export_limit.to_i
          if params[:columns] == 'all'
            @query.column_names = @query.available_inline_columns.map(&:name)
          end
        # when 'atom'
        #   @limit = Setting.feeds_limit.to_i
        # when 'xml', 'json'
        #   @offset, @limit = api_offset_and_limit
        #   @query.column_names = %w(name)
        else
          @limit = per_page_option
      end

      @object_count = @query.object_count
      @object_pages = Paginator.new @object_count, @limit, params['page']
      @offset ||= @object_pages.offset
      @objects = @query.objects({:order => sort_clause,
                                        :offset => @offset,
                                        :limit => @limit}.merge(params_for_query_objects))
      @object_count_by_group = @query.object_count_by_group

      respond_to do |format|
        format.html { render :action => 'index', :layout => !request.xhr? }
        # format.api
      end
    else
      respond_to do |format|
        format.html { render :action => 'index', :layout => !request.xhr? }
        format.any(:atom, :csv, :pdf) { render :nothing => true } # todo: export
        # format.api { render_validation_errors(@query) }
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def new
    respond_to do |format|
      format.html { render :layout => !request.xhr? }
      format.js
    end
  end

  def create
    if request.post?
      if @object.save
        respond_to do |format|
          format.html do
            flash[:notice] = l(:notice_successful_create)
            redirect_back_or_default default_object_path
          end
          format.js
          # format.api { render :action => 'show', :status => :created, :location => default_object_url }
        end
      else
        respond_to do |format|
          format.html { render :action => 'new' }
          format.js { render :action => 'new' }
          # format.api { render_validation_errors(@object) }
        end
      end
    end
  end

  def show
    @journals = @object.journals.includes(:user, :details).reorder("#{Journal.table_name}.id ASC").all
    @journals.each_with_index { |j, i| j.indice = i+1 }
    Journal.preload_journals_details_custom_fields(@journals)
    # TODO: use #select! when ruby1.8 support is dropped
    @journals.reject! { |journal| !journal.notes? && journal.visible_details.empty? }
    @journals.reverse! if User.current.wants_comments_in_reverse_order?

    # respond_to { |format| format.html }
  end

  def edit
    # respond_to { |format| format.html }
  end

  # def init_journal
  #   @object.init_journal(User.current)
  # end

  def update
    if @object.save
      flash[:notice] = l(:notice_successful_update) unless @object.current_journal.new_record?

      respond_to do |format|
        format.html { redirect_back_or_default default_object_path }
        # format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        # format.api  { render_validation_errors(@object) }
      end
    end
  end

  def destroy
    raise ActiveRecord::RecordNotFound if @objects.empty?

    @objects.each do |o|
      begin
        o.reload.destroy
      rescue ::ActiveRecord::RecordNotFound # raised by #reload if request no longer exists
        # nothing to do, object was already deleted
      end
    end
    respond_to do |format|
      format.html { redirect_back_or_default default_objects_path }
      # format.api  { render_api_ok }
    end
  end

  protected

  def params_for_query_objects
    {} # {:include => [:project]}
  end

  def default_objects_path
    raise NotImplementedError, "Not implemented method 'default_objects_path' in #{self.class.name}"
  end

  def default_object_path
    raise NotImplementedError, "Not implemented method 'default_object_path' in #{self.class.name}"
  end

  def default_object_url
    raise NotImplementedError, "Not implemented method 'default_object_url' in #{self.class.name}"
  end

  def default_sort_columns
    ['id']
  end

  def update_model_object_with_reflections(p)
    # nothing
  end

  def find_model_objects
    model = self.class.model_object
    if model
      @objects = model.where(:id => (params[:id] || params[:ids]))
      self.instance_variable_set('@' + controller_name, @objects) if @objects
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def build_model_object
    @object = self.class.model_object.new
    self.instance_variable_set('@' + controller_name.singularize, @object)
    update_model_object_from_params
  end

  def update_model_object_from_params
    o = controller_name.singularize.to_sym
    return if params[o].blank?
    p = params[o]
    p.dup.each do |k, v|
      @object.send("#{k}=", v) if @object.has_attribute?(k)
    end
    @object.custom_field_values = p[:custom_field_values] || {}
    @object.notes = p[:notes] || ''
    update_model_object_with_reflections(p)
    # init_journal
    @object.save_attachments(params[:attachments] || p[:uploads])
    render_attachment_warning_if_needed(@object)
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_back_or_default(default_object_path, :referer => true)
  end

  def self.query_class
    @@query_class ||= "#{self.model_object}Query".constantize
  end

  # Retrieve query from session or build a new query
  def retrieve_query
    query_class = self.class.query_class
    if !params[:query_id].blank?
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = query_class.where(cond).find(params[:query_id])
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:query] = {:id => @query.id, :project_id => @query.project_id}
      sort_clear
    elsif api_request? || params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = query_class.new(:name => "_")
      @query.project = @project
      @query.build_from_params(params)
      session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names}
    else
      # retrieve from session
      @query = nil
      @query = query_class.find_by_id(session[:query][:id]) if session[:query][:id]
      @query ||= query_class.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names])
      @query.project = @project
    end
  end

  def retrieve_query_from_session
    if session[:query]
      query_class = self.class.query_class
      if session[:query][:id]
        @query = query_class.find_by_id(session[:query][:id])
        return unless @query
      else
        @query = query_class.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names])
      end
      if session[:query].has_key?(:project_id)
        @query.project_id = session[:query][:project_id]
      else
        @query.project = @project
      end
      @query
    end
  end
end
