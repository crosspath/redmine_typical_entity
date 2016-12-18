module TypicalEntityController
  extend ActiveSupport::Concern
  module ClassMethods
    # REQUIRES: {query_type, model, param} OR 'entity'
    def typical_entity(options={})
      cattr_accessor :te
      self.te = options.respond_to?(:dup) ? options.dup : options
      if self.te.is_a? String
        camelcased = self.te.camelcase
        self.te = {query_type: "#{camelcased}Query", model: camelcased, param: self.te}
      end
      include TypicalEntityController::InstanceMethods
      before_filter :authorize_global
    end
  end
  
  module InstanceMethods
    def index
      retrieve_query(self.class.te[:query_type].constantize)
      sort_init(@query.sort_criteria_init)
      sort_update(@query.sortable_columns)
      
      if @query.valid?
        @issue_count = @query.entity_count
        @issue_pages = Redmine::Pagination::Paginator.new @issue_count, per_page_option, params['page']
        
        @offset ||= @issue_pages.offset
        @issues = @query.entities(:order => sort_clause, :offset => @offset, :limit => @limit)
        @issue_count_by_group = @query.entity_count_by_group
      end
      
      respond_to do |format|
        format.html
        format.csv  { send_data(export_to_csv(@issues, @query), :type => 'text/csv; header=present', :filename => get_export_filename(:csv, @query)) }
        format.pdf { send_data(issues_to_pdf(@issues, @project, @query), :type => 'application/pdf', :filename => get_export_filename(:pdf, @query)) }
      end
    end
    
    def show
      (render_404; return) unless @issue
      @journals = @issue.journals.includes(:user, :details).reorder("#{Journal.table_name}.id ASC").all
      @journals.each_with_index {|j,i| j.indice = i+1}
      @journals.reverse! if User.current.wants_comments_in_reverse_order?

      @edit_allowed = User.current.allowed_to?(:manage_crm, nil, global: true)
      respond_to do |format|
        format.html
      end
    end

    def new
      @issue = self.class.te[:model].constantize.new
      respond_to do |format|
        format.html { render action: 'new' }
      end
    end
    
    def create
      te = self.class.te[:param]
      @issue.description ||= ''
      @issue.save_attachments(params[:attachments] || (params[te.to_sym] && params[te.to_sym][:uploads]))
      if @issue.save
        respond_to do |format|
          format.html {
            link = send("project_#{te}_path", project_id: @project, id: @issue)
            render_attachment_warning_if_needed(@issue)
            flash[:notice] = l(:notice_issue_successful_create, :id => view_context.link_to("##{@issue.id}", link, :title => @issue.name)).html_safe
            if params[:continue]
              redirect_to send("new_project_#{te}_path", project_id: @project, id: {})
            else
              redirect_to link
            end
          }
        end
        return
      else
        respond_to do |format|
          format.html { render :action => 'new' }
        end
      end
    end
    
    def edit
      (render_404; return) unless @issue

      respond_to do |format|
        format.html
        format.xml
        format.js  { render :layout => !request.xhr? }
      end
    end

    def update
      return unless update_from_params(params)
      key = self.class.te[:param].to_sym
      @issue.attributes.keys.each { |k| @issue[k] = params[key][k.to_sym] || @issue[k] }
      @issue.custom_field_values = params[key][:custom_field_values] || {}
      @issue.save_attachments(params[:attachments] || (params[key] && params[key][:uploads]))
      saved = false
      begin
        saved = @issue.save(params)
      rescue ActiveRecord::StaleObjectError
        @conflict = true
        @conflict_journals = @issue.journals_after(params[:last_journal_id]).all if params[:last_journal_id]
      end

      if saved
        render_attachment_warning_if_needed(@issue)
        flash[:notice] = l(:notice_successful_update) unless @issue.current_journal.new_record?

        respond_to do |format|
          format.html { redirect_back_or_default send("project_#{self.class.te[:param]}_path", @project, @issue) }
          format.api  { render_api_ok }
        end
      else
        respond_to do |format|
          format.html { render :action => 'edit' }
          format.api  { render_validation_errors(@issue) }
        end
      end
    end

    def destroy
      @issues.each do |issue|
        begin
          issue.reload.delete
        rescue ::ActiveRecord::RecordNotFound # raised by #reload if issue no longer exists
          # nothing to do, issue was already deleted (eg. by a parent)
        end
      end
      respond_to do |format|
        format.html { redirect_to send("project_#{self.class.te[:param].pluralize}_path", @project), status: :see_other }
        format.api  { render_api_ok }
      end
    end
    
    def bulk_edit
      @issues.sort!
      @copy = params[:copy].present?
      @notes = params[:notes]

      @custom_fields = @issues.first.available_custom_fields
      @assignables = User.active
      @attachments_present = @issues.detect {|i| i.attachments.any?}.present? if @copy

      @safe_attributes = @issues.map(&:safe_attribute_names).reduce(:&)
      render :layout => false if request.xhr?
    end

    def bulk_update
      @issues.sort!
      @copy = params[:copy].present?
      attributes = parse_params_for_bulk_attributes(params)

      @project = CityAdsCRM.find_project
      unsaved_issue_ids = []
      moved_issues = []

      @issues.each do |issue|
        issue.reload
        issue = issue.copy({}, :attachments => params[:copy_attachments].present?) if @copy
        
        issue.init_journal(User.current, params[:notes])
        issue.safe_attributes = attributes
        if issue.save
          moved_issues << issue
        else
          # Keep unsaved issue ids to display them in flash error
          unsaved_issue_ids << issue.id
        end
      end
      set_flash_from_bulk_issue_save(@issues, unsaved_issue_ids)

      if params[:follow]
        if @issues.size == 1 && moved_issues.size == 1
          redirect_to send("project_#{self.class.te[:param]}_path", @project, moved_issues.first)
        end
      else
        redirect_back_or_default send("project_#{self.class.te[:param].pluralize}_path", @project)
      end
    end
    
    def toggle_description; respond_to { |format| format.js }; end
    def render_last_journal; respond_to { |format| format.js }; end
    
    protected
    
    def find_project; @project = Project.try_find(params[:project_id]) || CityAdsCRM.find_project; end
    def find_object
      model = self.class.te[:model].constantize
      @issue = model.try_find params[:id]
    end
  
    def find_objects
      model = self.class.te[:model].constantize
      @issues = model.find_all_by_id(params[:id] || params[:ids])
      raise ActiveRecord::RecordNotFound if @issues.empty?
      @project = CityAdsCRM.find_project
    rescue ActiveRecord::RecordNotFound
      render_404
    end
    
    def build_object
      model = self.class.te[:model].constantize
      param = self.class.te[:param].to_sym
      attrs = params[param]
      
      @issue = params[:id].nil? ? model.new : model.try_find(params[:id])
      if @issue
        @issue.init_journal(User.current, attrs ? attrs[:notes] : '')
        
        @issue.safe_attributes = attrs
        @issue.author = User.current
        @issue.assigned_to = Principal.try_find(attrs[:assigned_to_id]) if attrs
        
        initialize_additional_fields if respond_to? :initialize_additional_fields
      end
    end
    
    def update_from_params(params = {})
      (render_404; return) unless @issue
      param = self.class.te[:param]
      issue_attributes = params[param.to_sym]
      
      if issue_attributes && params[:conflict_resolution]
        case params[:conflict_resolution]
        when 'overwrite'
          issue_attributes = issue_attributes.dup
          issue_attributes.delete(:lock_version)
        when 'add_notes'
          issue_attributes = issue_attributes.slice(:notes)
        when 'cancel'
          redirect_to send("project_#{param}_path", @issue)
          return false
        end
      end
      true
    end
    
    def parse_params_for_bulk_attributes(params)
      attributes = (params[self.class.te[:param].to_sym] || {}).reject {|k,v| v.blank?}
      attributes.keys.each {|k| attributes[k] = '' if attributes[k] == 'none'}
      attributes.stringify_keys!
      if custom = attributes['custom_field_values']
        custom.reject! {|k,v| v.blank?}
        custom.keys.each do |k|
          if custom[k].is_a?(Array)
            custom[k] << '' if custom[k].delete('__none__')
          else
            custom[k] = '' if custom[k] == '__none__'
          end
        end
      end
      attributes
    end
  end
end

ApplicationController.send(:extend, TypicalEntityController::ClassMethods)
