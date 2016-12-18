# redmine_typical_entity
Extracted source code from some redmine instances for describing typical entities in Redmine. Examples are bills, accounts, scenes.

## Features

1. Storing objects of your entity.
2. Manipulate with these objects using issues-like interface.
3. Control permissions of view and edit actions for your entity.
4. Track changes of these objects (history, journal).

## ToDo

1. Add code to allow attach files to objects.
2. Write code generator.

## How to use

Perform all operation in your plugin directory, `{redmine path}/plugins/{your plugin name}`.

Please tell me (@crosspath) if below explanation is not working or insufficient.

Define class of your entity:

    class ChangeRequest < ActiveRecord::Base
      unloadable
      include Redmine::I18n
      include Journalized
      
      # belongs_to, has_many, validations, scopes, methods, etc.
      
      # Used for styling table with objects of your entity.
      def css_classes(user=User.current)
        s = "change_request status-#{status}}"
        s << ' assigned-to-me' if notified_users.include?(user.id)
        s
      end
      
      # Inform `notified_users` when these attributes are changing.
      def watchable_columns
        ChangeRequest.column_names - %w(id created_on updated_on)
      end
      
      # Allowed statuses. If you want to implement some workflow with your entity, do it there!
      def new_statuses_allowed_to(user)
        ChangeRequest::STATUSES
      end
      
      # Notify these users on attributes change.
      def notified_users
        change_request_users.map(&:user_id).uniq
      end
    end # end of class

Define controller:

    class ChangeRequestsController < GeneralController
      before_filter :set_edit_allowed, :only => [:show, :edit, :update]
      before_filter :set_allowed_statuses, :only => [:new, :show, :edit, :update]
      
      model_object ChangeRequest # Mention your entity there.
      
      helper :change_requests
      include ChangeRequestsHelper
      helper UsersHelper
      
      # Your methods and other code
      
      protected
      
      # Define it if you need it.
      def params_for_query_objects
        {:include => [:project]}
      end
      
      # Define it if you need it.
      def default_sort_columns
        ['col1', 'col2']
      end
      
      # Replace with your path.
      def default_objects_path
        change_requests_path
      end
      
      # Replace with your path.
      def default_object_path
        change_request_path(@object)
      end
      
      # Replace with your path.
      def default_object_url
        change_request_url(@object)
      end
      
      # Replace with your code.
      def update_model_object_with_reflections(p)
        @change_request.project = Project.find(p[:project]) if p[:project]
      end
      
      # Replace with your code.
      def set_edit_allowed(user = User.current)
        @edit_allowed = user.allowed_to_globally?(:edit_change_requests, {})
      end

      # Replace with your code.
      def set_allowed_statuses(user = User.current)
        @allowed_statuses = @change_request.new_statuses_allowed_to(user)
      end
      
      # Replace with your code.
      def column_value(column, object, value)
        case column.name
          when :id
            link_to value, change_request_path(object)
          when :name
            link_to value, change_request_path(object)
          else
            format_object(value)
        end
      end
    end

Define helper:

    module ChangeRequestsHelper
      include JournalizedHelper
    
      # Replace with your code.
      def column_content_av(column, object)
        value = column.value(object)
        if value.is_a?(Array)
          value.map { |v| column_value(column, object, v) }.compact.join(', ').html_safe
        else
          column_value_av(column, object, value)
        end
      end
    
      # Replace with your code.
      def column_value_av(column, object, value)
        case column.name
          when :id
            link_to value, change_request_path(object)
          when :name
            link_to ChangeRequest::NAMES[value.to_sym], change_request_path(object)
          # etc
          else
            format_object(value)
        end
      end
    
      # Replace with your code.
      def format_detail_attribute(detail, field)
        case detail.prop_key # == field
          when 'name'
            [ChangeRequest::NAMES[detail.value.to_sym], ChangeRequest::NAMES[detail.old_value.to_sym]]
          when 'status'
            [ChangeRequest::STATUSES[detail.value.to_sym], ChangeRequest::STATUSES[detail.old_value.to_sym]]
          # etc
        end
      end
    end

Create views in directory `app/views/{entity in plural form}`:

- `_entity.html.erb` and `_entity.text.erb` (used in emails; replace *entity* with the name of your entity in singular form)
- `_form.html.erb`, `_list.html.erb`, `edit.html.erb`, `index.html.erb`, `new.html.erb`, `show.html.erb`

Create view for mailer with the line like this:

    <%= render :partial => 'change_request', :formats => [:text], :locals => { :request => @object } %>

To be able to filter and search objects, define **query**:

    class ChangeRequestQuery < Query
      include GeneralQuery
      include ChangeRequestsHelper
      
      self.queried_class = ChangeRequest # Link to class of your entity.
      self.queried_table_name = self.queried_class.table_name
      
      self.available_columns = [
        QueryColumn.new(:id, :sortable => "#{queried_table_name}.id", :default_order => 'desc', :caption => '#', :frozen => true),
        QueryColumn.new(:name, :sortable => "#{queried_table_name}.name", :default_order => 'asc'),
        ... # et cetera
      ]
      
      class << self
        def default_filters;
          {}; # Set default filters as {id: value, name: value}.
        end
        
        # If you wish to constrain access to reading objects of your entity.
        # In this example we use project-independent (globally) permission.
        def allowed_to?(user = User.current)
          user.allowed_to_globally?(:view_change_requests)
        end
        
        def select_custom_fields
          # If your entity allows to include custom fields:
          # ChangeRequestCustomField.where(is_for_all: true, is_filter: true, visible: true)
          # Otherwise, pass empty set of ActiveRecord[] type.
          IssueCustomField.where('0=1')
        end
      end
      
      # Available types and values of the filters.
      self.set_filters = {
        'name' => {:type => :list, :values => self.queried_class::NAMES.map { |k, v| [v, k] }},
        ... # et cetera
      }
      
      # Some magic.
      scope :visible, lambda { |*args|
        if self.class.allowed_to?
          prepare_visible_scope
        else
          where('0=1')
        end
      }
      
      # What columns should be visible by default.
      def default_columns_names
        @default_columns_names ||= [:name, :status, :project]
      end
      
      def conditions_for_object_count(klass)
        klass # Or klass.joins(:projects) if objects of your entity belong to project.
      end
    end

If you want to use some objects of your created entity in attributes, define **custom field** for it:

    class ChangeRequestCustomField < CustomField
      def type_name
        :label_change_request_plural
      end
    end

`init.rb` should contain permissions like these:

    permission :view_change_requests, {:change_requests => [:index, :show, :with_project]}, :global => true
    permission :edit_change_requests, {:change_requests => [:edit, :new, :create, :update, :destroy]}, :global => true

Don't forget to give human names for permissions and labels in `config/locales/{locale}.yml`:

    # Example for Russian.
    ru:
      permission_view_change_requests: Просматривать запросы на изменения
      label_change_request: Запрос на изменения
      label_change_request_new: Новый запрос на изменения
      label_change_request_plural: Запросы на изменения
      
      # And for each field in your entity (keep "field_" part):
      field_name: Название

In `config/routes.rb`:

    resources :change_requests # Replace with the name of your entity.

Write migration for creating database table for storing your entity. Yeah, in `db/migrate`.

And now, let's do the sweetest part: patches. *Writing plugins for Redmine is full of patches.*

custom_fields_helper_patch:

    ActionDispatch::Callbacks.to_prepare do
      CustomFieldsHelper.class_eval do
        # We use it below. There would be a problem, if we define
        # this method in this way in multiple places.
        def custom_fields_tabs
          @@custom_fields_tabs ||= self.class::CUSTOM_FIELDS_TABS + [
            {:name => 'ChangeRequestCustomField', :partial => 'custom_fields/index',
             :label => :label_change_request_plural}
          ]
        end
        
        def render_custom_fields_tabs_with_cache(types)
          tabs = custom_fields_tabs.select {|h| types.include?(h[:name]) }
          render_tabs tabs
        end
        alias_method_chain :render_custom_fields_tabs, :cache
        
        def custom_field_type_options_with_cache
          custom_fields_tabs.map {|h| [l(h[:label]), h[:name]]}
        end
        alias_method_chain :custom_field_type_options, :cache
      end
    end

Define mailer actions:

    ActionDispatch::Callbacks.to_prepare do
      Mailer.class_eval do
          def deliver_change_request_add(o) # o = change_request
            deliver_object_add(o)
          end
          
          def deliver_change_request_edit(j) # j = journal
            deliver_object_edit(j)
          end
          
          protected
          
          def change_request_add(o, to)
            object_add(o, to, "Добавлен запрос на изменения #{o}")
          end
          
          def change_request_edit(j, to)
            object_edit(j, to, "Запрос на изменения #{j.journalized}")
          end
          
          def deliver_object_add(o)
            Mailer.send("#{o.class.name.underscore}_add", o, o.notified_users).deliver
          end
      
          def deliver_object_edit(j) # j = journal
            o = j.journalized.reload
            to = j.notified_users
            j.each_notification(to) do |users|
              Mailer.send("#{o.class.name.underscore}_edit", j, users).deliver
            end
          end
          
          def object_add(o, to, subject)
            @object = o
            @object_url = url_for(:controller => o.class.name.tableize, :action => 'show', :id => o)
            mail :to => to.map(&:mail), :subject => subject
          end
      
          def object_edit(j, to, subject)
            @author = j.user
            @journal = j
            @object = o = j.journalized
            @object_url = url_for(:controller => o.class.name.tableize, :action => 'show', :id => o, :anchor => "change-#{j.id}")
            mail :to => to.map(&:mail), :subject => subject
          end
        end
      end
    end
