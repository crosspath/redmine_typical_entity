# coding: UTF-8

module GeneralQuery
  def self.included(base)
    base.class_eval do

      class_attribute :queried_table_name, :set_filters

      def prepare_visible_scope
        user = args.shift || User.current
        scope = includes(:project)
        if user.admin?
          scope.where("#{table_name}.visibility <> ? OR #{table_name}.user_id = ?", VISIBILITY_PRIVATE, user.id)
        elsif user.memberships.any?
          scope.where("#{table_name}.visibility = ?" +
                          " OR (#{table_name}.visibility = ? AND #{table_name}.id IN (" +
                          "SELECT DISTINCT q.id FROM #{table_name} q" +
                          " INNER JOIN #{table_name_prefix}queries_roles#{table_name_suffix} qr on qr.query_id = q.id" +
                          " INNER JOIN #{MemberRole.table_name} mr ON mr.role_id = qr.role_id" +
                          " INNER JOIN #{Member.table_name} m ON m.id = mr.member_id AND m.user_id = ?" +
                          " WHERE q.project_id IS NULL OR q.project_id = m.project_id))" +
                          " OR #{table_name}.user_id = ?",
                      VISIBILITY_PUBLIC, VISIBILITY_ROLES, user.id, user.id)
        elsif user.logged?
          scope.where("#{table_name}.visibility = ? OR #{table_name}.user_id = ?", VISIBILITY_PUBLIC, user.id)
        else
          scope.where("#{table_name}.visibility = ?", VISIBILITY_PUBLIC)
        end
      end

      def initialize(attributes=nil, *args)
        super attributes
        # self.filters ||= { 'status' => {:operator => "=", :values => [self.queried_class::STATUSES.keys.first]} }
        self.filters ||= self.class.default_filters
      end

      # Returns true if the query is visible to +user+ or the current user.
      def visible?(user=User.current)
        return true if user.admin? || self.class.allowed_to?(user)
        case visibility
          when VISIBILITY_PUBLIC
            true
          when VISIBILITY_ROLES
            if project
              (user.roles_for_project(project) & roles).any?
            else
              Member.where(:user_id => user.id).joins(:roles).where(:member_roles => {:role_id => roles.map(&:id)}).any?
            end
          else
            user == self.user
        end
      end

      def is_private?
        visibility == VISIBILITY_PRIVATE
      end

      def is_public?
        !is_private?
      end

      def draw_progress_line
        r = options[:draw_progress_line]
        r == '1'
      end

      def draw_progress_line=(arg)
        options[:draw_progress_line] = (arg == '1' ? '1' : nil)
      end

      def build_from_params(params)
        super
        self.draw_progress_line = params[:draw_progress_line] || (params[:query] && params[:query][:draw_progress_line])
        self
      end

      def initialize_available_filters
        self.class.set_filters.each { |name, options| add_available_filter name, options }
        add_custom_fields_filters(self.class.select_custom_fields)
      end

      def available_columns
        return @available_columns if @available_columns
        @available_columns = self.class.available_columns.dup
        @available_columns += self.class.select_custom_fields.collect {|cf| QueryCustomFieldColumn.new(cf) }

        @available_columns
      end

      def object_count
        conditions_for_object_count(self.class.queried_class).where(statement).count
      rescue ::ActiveRecord::StatementInvalid => e
        raise StatementInvalid.new(e.message)
      end

      # пример: klass.visible
      def conditions_for_object_count(klass)
        klass # do nothing
      end

      # Returns the object count by group or nil if query is not grouped
      def object_count_by_group
        r = nil
        if grouped?
          begin
            # Rails3 will raise an (unexpected) RecordNotFound if there's only a nil group value
            r = conditions_for_object_count(self.class.queried_class).
                where(statement).
                joins(joins_for_order_statement(group_by_statement)).
                group(group_by_statement).
                count
          rescue ActiveRecord::RecordNotFound
            r = {nil => object_count}
          end
          c = group_by_column
          if c.is_a?(QueryCustomFieldColumn)
            r = r.keys.inject({}) {|h, k| h[c.custom_field.cast_value(k)] = r[k]; h}
          end
        end
        r
      rescue ::ActiveRecord::StatementInvalid => e
        raise StatementInvalid.new(e.message)
      end

      # Returns the objects
      # Valid options are :order, :offset, :limit, :include, :conditions
      def objects(options={})
        order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

        scope = conditions_for_object_count(self.class.queried_class).
            where(statement).
            includes(((@joins_values || []) + (options[:include] || [])).uniq).
            where(options[:conditions]).
            order(order_option).
            joins(joins_for_order_statement(order_option.join(','))).
            limit(options[:limit]).
            offset(options[:offset])

        scope = scope.preload(:custom_values)
        versions = scope.all
        versions
      rescue ::ActiveRecord::StatementInvalid => e
        raise StatementInvalid.new(e.message)
      end
    end
  end
end
