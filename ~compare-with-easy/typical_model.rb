module TypicalModel
  extend ActiveSupport::Concern
  module ClassMethods
    # REQUIRES: 'entity'
    def typical_model
      cattr_accessor :crm_entity
      self.crm_entity = table_name
      include TypicalModel::InstanceMethods
    end
  end
  
  module InstanceMethods
    def self.included(base)
      base.class_eval do
        belongs_to :author, class_name: 'User', foreign_key: 'author_id'
        belongs_to :assigned_to, class_name: 'Principal', foreign_key: 'assigned_to_id'
        has_many :journals, as: :journalized, dependent: :destroy
        
        attr_reader :current_journal
        delegate :notes, :notes=, to: :current_journal, allow_nil: true
        
        cattr_accessor :journalized_options
        self.journalized_options = {
          non_journalized_columns: %w(id lock_version created_at updated_at),
          format_detail_date_columns: [], format_detail_time_columns: [],
          format_detail_reflection_columns: [], format_detail_boolean_columns: [],
          format_detail_hours_columns: []
        }
        
        after_save :create_journal
        
        acts_as_attachable after_add: :attachment_added, after_remove: :attachment_removed,
          view_permission: :view_crm, delete_permission: :manage_crm
        acts_as_customizable
        acts_as_searchable :columns => ['name', "#{table_name}.description", "#{Journal.table_name}.notes"],
                           :include => [:journals],
                           # sort by id so that limited eager loading doesn't break with postgresql
                           :order_column => "#{table_name}.id"
        
        include SimpleSafeAttributes
        
        def easy_repeat_settings; {}; end
        def easy_is_repeating; false; end
        def easy_is_repeating?; false; end
        
        def assignable_users; User.active; end
        def assignable_groups; Group.active; end
        def easy_level; 0; end
        
        def disabled_core_fields; []; end
        def project; nil; end  
        
        def to_s; "##{id} #{name}"; end
        
        def css_classes(level=0)
          s = "issue"
          if User.current.logged?
            u = User.current.id
            s << ' created-by-me' if author_id == u
            s << ' assigned-to-me' if assigned_to_id == u
          end
          s
        end
        
        # Callback on file attachment (from app/models/issue.rb)
        def attachment_added(obj)
          if @current_journal && !obj.new_record?
            @current_journal.details << JournalDetail.new(:property => 'attachment', :prop_key => obj.id, :value => obj.filename)
          end
        end

        # Callback on attachment deletion (from app/models/issue.rb)
        def attachment_removed(obj)
          if @current_journal && !obj.new_record?
            @current_journal.details << JournalDetail.new(:property => 'attachment', :prop_key => obj.id, :old_value => obj.filename)
            @current_journal.save
          end
        end

        def attachments_visible?(user=User.current)
          user.allowed_to?(self.class.attachable_options[:view_permission], nil, global: true)
        end

        def attachments_deletable?(user=User.current)
          user.allowed_to?(self.class.attachable_options[:delete_permission], nil, global: true)
        end
        
        def init_journal(user = User.current, notes = '')
          @current_journal ||= Journal.new(:journalized => self, :user => user, :notes => notes)
          if new_record?
            @current_journal.notify = false
          else
            @attributes_before_change = attributes.dup
            @custom_values_before_change = {}
            self.custom_field_values.each {|c| @custom_values_before_change.store c.custom_field_id, c.value }
          end
          @current_journal
        end

        def create_journal
          if @current_journal && @current_journal.notify?
            # attributes changes
            (self.class.column_names - self.class.journalized_options[:non_journalized_columns]).each do |c|
              before = @attributes_before_change && @attributes_before_change[c]
              after = send(c)
              next if before == after || (before.blank? && after.blank?)
              o = {property: 'attr', prop_key: c, old_value: before, value: after}
              @current_journal.details << JournalDetail.new(o)
            end
            
            add_cf_details = lambda do |c, before, after|
              o = {property: 'cf', prop_key: c.custom_field_id, old_value: before, value: after}
              @current_journal.details << JournalDetail.new(o)
            end
            
            # custom fields changes
            custom_field_values.each do |c|
              before = @custom_values_before_change && @custom_values_before_change[c.custom_field_id]
              after = c.value
              next if before == after || (before.blank? && after.blank?)
              
              if before.is_a?(Array) || after.is_a?(Array)
                before = Array.wrap(before)
                after = Array.wrap(after)
                
                # values removed
                (before - after).each { |value| add_cf_details.call(c, value, nil) if value.present? }
                # values added
                (after - before).each { |value| add_cf_details.call(c, nil, value) if value.present? }
              else
                add_cf_details.call(c, before, after)
              end
            end
            @current_journal.save!
            # reset current journal
            init_journal @current_journal.user, @current_journal.notes
          end
        end
        
        def issues
          id = self.id.to_s
          cff = CustomField.where(internal_name: nil).select{ |x| x.settings['entity_type'] == self.class.name }
          cff.map { |cf| cf.custom_values.map { |v| v.value == id && v.customized.visible? ? v.customized : nil } }.flatten.compact.uniq
        end
      end
    end
    
  end
end

ActiveRecord::Base.send(:extend, TypicalModel::ClassMethods)
