module TypicalQuery
  extend ActiveSupport::Concern
  module ClassMethods
    # REQUIRES: 'entity'
    def typical_query(entity)
      cattr_accessor :crm_entity
      self.crm_entity = entity.to_s
      include TypicalQuery::InstanceMethods
    end
  end
  
  module InstanceMethods
    def additional_statement
      @additional_statement_added ||= true
    end

    def available_filters
      return @available_filters unless @available_filters.blank?

      users = User.select('id, firstname, lastname').sort_by(&:name).collect{|s| [s.name, s.id.to_s] }
      group = l("label_filter_group_#{self.class.name.underscore}")
      @available_filters = {}
      @available_filters['name'] = { :type => :string, :order => 12 , :group => group}
      @available_filters['created_on'] = { :type => :date_period, :time_column => true, :order => 17 , :group => group}
      @available_filters['updated_on'] = { :type => :date_period, :time_column => true, :order => 18 , :group => group}
      @available_filters['not_updated_on'] = { :type => :date_period, :time_column => true, :order => 19, :label => :label_not_updated_on, :group => group}
      
      @available_filters['contacts'] = { :type => :list, :order => 21, :values => Proc.new{self.contacts.collect{|s| [s.name, s.id.to_s]}}, :group => group}

      @available_filters['assigned_to_id'] = { :type => :list_optional, :order => 6, :values => Proc.new do
          assigned_to_values = []
          assigned_to_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
          assigned_to_values += users
          assigned_to_values
        end,
        :group => group
      }

      @available_filters['author_id'] = { :type => :list, :order => 7, :values => Proc.new do
          author_values = []
          author_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
          author_values += users
          author_values
        end,
       :group => group
      }

      @available_filters['member_of_group'] = { :type => :list_optional, :order => 8, :values => Proc.new do
          Group.all.collect {|g| [g.name, g.id.to_s] }
        end,
        :group => group
      }

      @available_filters['assigned_to_role'] = { :type => :list_optional, :order => 9, :values => Proc.new do
          Role.givable.collect {|r| [r.name, r.id.to_s] }
        end,
        :group => group
      }

      add_custom_fields_filters("#{self.class.crm_entity.classify}CustomField".constantize.all)
      add_associations_custom_fields_filters :author, :assigned_to

      @available_filters.each do |field, options|
        options[:name] ||= l(options[:label] || "field_#{field}".gsub(/_id$/, ''))
        options[:group] ||= l(:label_filter_group_unknown)
      end

      @available_filters
    end

    def available_columns
      unless @available_columns_added
        @available_columns = [
          EasyQueryColumn.new(:assigned_to, :sortable => lambda{User.fields_for_order_statement}, :groupable => true),
          EasyQueryColumn.new(:author, :sortable => lambda{User.fields_for_order_statement('authors')}),
          EasyQueryColumn.new(:name, :sortable => "#{entity_table_name}.name"),
          EasyQueryColumn.new(:created_on, :sortable => "#{entity_table_name}.created_on", :default_order => 'desc'),
          EasyQueryColumn.new(:updated_on, :sortable => "#{entity_table_name}.updated_on", :default_order => 'desc'),
          EasyQueryColumn.new(:description, :inline => false),
          EasyQueryColumn.new(:id, :sortable => "#{entity_table_name}.id")
        ]

        @available_columns += "#{self.class.crm_entity.classify}CustomField".constantize.all.collect {|cf| EasyQueryCustomFieldColumn.new(cf)}
        
        @available_columns_added = true
      end
      @available_columns
    end

    def searchable_columns
      ["#{entity_table_name}.name"]
    end

    def entity; self.class.crm_entity.classify.constantize; end
    def entity_scope; entity; end
    def entity_table_name; entity.table_name; end
    
    def contacts
      @contacts ||= Contact.all
    end
    
    def issue_count_by_group(options={})
      entity_count_by_group(options)
    end

    def issue_sum_by_group(column, options={})
      entity_sum_by_group(column, options)
    end

    # Returns the journals
    # Valid options are :order, :offset, :limit
    def journals(options={})
      scope = Journal.visible.includes([:details, :user, {self.class.crm_entity.to_sym => [:project, :author]}])
      scope = scope.where(self.statement)
      scope = scope.order(options[:order]).limit(options[:limit]).offset(options[:offset])
      scope
    rescue ::ActiveRecord::StatementInvalid => e
      raise StatementInvalid.new(e.message)
    end

    protected

    def statement_skip_fields
      []
    end

    def joins_for_order_statement(order_options)
      joins = []

      if order_options
        if order_options.include?('authors')
          joins << "LEFT OUTER JOIN #{User.table_name} authors ON authors.id = #{entity_table_name}.author_id"
        end
        order_options.scan(/cf_\d+/).uniq.each do |name|
          column = available_columns.detect {|c| c.name.to_s == name}
          join = column && column.custom_field.join_for_order_statement
          joins << join if join
        end
      end

      joins.any? ? joins.join(' ') : nil
    end

    def sql_for_contacts_field(field, operator, value)
      db_table = 'contacts_issues'
      db_field = 'contact_id'
      sql = "#{entity_table_name}.id #{ operator == '=' ? 'IN' : 'NOT IN' } (SELECT issue_id FROM #{db_table} WHERE #{sql_for_field(field, '=', value, db_table, db_field)})"
      return sql
    end

    def sql_for_member_of_group_field(field, operator, value)
      if operator == '*' # Any group
        groups = Group.all
        operator = '=' # Override the operator since we want to find by assigned_to
      elsif operator == "!*"
        groups = Group.all
        operator = '!' # Override the operator since we want to find by assigned_to
      else
        groups = Group.find_all_by_id(value)
      end
      groups ||= []

      members_of_groups = groups.inject([]) {|user_ids, group|
        if group && group.user_ids.present?
          user_ids << group.user_ids
        end
        user_ids.flatten.uniq.compact
      }.sort.collect(&:to_s)

      sql = '(' + sql_for_field('assigned_to_id', operator, members_of_groups, entity_table_name, 'assigned_to_id', false) + ')'
      return sql
    end

    def sql_for_assigned_to_role_field(field, operator, value)
      if operator == "*" # Any Role
        roles = Role.givable
        operator = '=' # Override the operator since we want to find by assigned_to
      elsif operator == "!*" # No role
        roles = Role.givable
        operator = '!' # Override the operator since we want to find by assigned_to
      else
        roles = Role.givable.find_all_by_id(value)
      end
      roles ||= []
      roles = roles.collect{|r| r.id.to_s}

      sql =  "EXISTS(SELECT #{Member.table_name}.id "
      sql << "FROM #{Member.table_name} INNER JOIN member_roles ON member_roles.member_id = members.id "
      sql << "WHERE #{sql_for_field('role_id', operator, roles, 'member_roles', 'role_id', false)} "
      sql << "AND #{Member.table_name}.user_id = #{entity_table_name}.assigned_to_id "
      sql << "AND #{Member.table_name}.project_id = #{entity_table_name}.project_id) "
      return sql
    end
  end
end

EasyQuery.send(:extend, TypicalQuery::ClassMethods)
