# coding: UTF-8

module Journalized
  def self.included(base)
    base.class_eval do
      # -JOURNALS-

      has_many :journals, :as => :journalized, :dependent => :destroy
      has_many :visible_journals, :class_name => 'Journal', :as => :journalized, :readonly => true

      attr_reader :current_journal
      delegate :notes, :notes=, :private_notes, :private_notes=, :to => :current_journal, :allow_nil => true

      acts_as_customizable

      after_save :create_journal

      after_initialize do init_journal(User.current) end

      def init_journal(user, notes = "")
        @current_journal ||= CustomJournal.new(:journalized => self, :user => user, :notes => notes)
        if new_record?
          @current_journal.notify = false
        else
          @attributes_before_change = attributes.dup
          @custom_values_before_change = {}
          self.custom_field_values.each { |c| @custom_values_before_change.store c.custom_field_id, c.value }
        end
        @current_journal
      end

      # Returns the id of the last journal or nil
      def last_journal_id
        new_record? ? nil : journals.maximum(:id)
      end

      # Returns a scope for journals that have an id greater than journal_id
      def journals_after(journal_id)
        scope = journals.reorder("#{Journal.table_name}.id ASC")
        if journal_id.present?
          scope = scope.where("#{Journal.table_name}.id > ?", journal_id.to_i)
        end
        scope
      end

      # Saves the changes in a Journal
      # Called after_save
      def create_journal
        return if !defined?(@current_journal) || !@current_journal
        # attributes changes
        if defined?(@attributes_before_change) && @attributes_before_change
          watchable_columns.each do |c|
            before = @attributes_before_change[c].to_s
            after = send(c).to_s
            next if before == after || (before.blank? && after.blank?)
            @current_journal.details << JournalDetail.new(:property => 'attr',
                                                          :prop_key => c,
                                                          :old_value => before,
                                                          :value => after)
          end
        end
        if defined?(@custom_values_before_change) && @custom_values_before_change
          # custom fields changes
          custom_field_values.each do |c|
            before = @custom_values_before_change[c.custom_field_id]
            after = c.value
            next if before == after || (before.blank? && after.blank?)

            if before.is_a?(Array) || after.is_a?(Array)
              before = Array.wrap(before).map(&:to_s)
              after = Array.wrap(after).map(&:to_s)

              # values removed
              (before - after).reject(&:blank?).each do |value|
                @current_journal.details << JournalDetail.new(:property => 'cf',
                                                              :prop_key => c.custom_field_id,
                                                              :old_value => value,
                                                              :value => nil)
              end
              # values added
              (after - before).reject(&:blank?).each do |value|
                @current_journal.details << JournalDetail.new(:property => 'cf',
                                                              :prop_key => c.custom_field_id,
                                                              :old_value => nil,
                                                              :value => value)
              end
            else
              before = before.to_s
              after = after.to_s
              next if before == after
              @current_journal.details << JournalDetail.new(:property => 'cf',
                                                            :prop_key => c.custom_field_id,
                                                            :old_value => before,
                                                            :value => after)
            end
          end
        end
        @current_journal.save! if @current_journal.details.present? || @current_journal.notes.present?
        # reset current journal
        init_journal @current_journal.user, @current_journal.notes
      end

      # -MAILER-

      # notification
      after_create :send_notification

      def send_notification(action = :add, object = nil)
        u = self.class.name.underscore
        # [
        #     {:action => :add, :event => "#{u}_added", :mailer => "deliver_#{u}_add"},
        #     {:action => :edit, :event => "#{u}_updated", :mailer => "deliver_#{u}_edit"}
        # ].each do |x|
        #   Mailer.send(x[:mailer], object || self) if action == x[:action] && Setting.notified_events.include?(x[:event])
        # end
        if action == :add && Setting.notified_events.include?("#{u}_added")
          Mailer.send("deliver_#{u}_add", object || self)
        end
        if action == :edit && Setting.notified_events.include?("#{u}_updated")
          Mailer.send("deliver_#{u}_edit", object || self)
        end
      end

      def notified_users
        raise NotImplementedError, "Not implemented method 'notified_users' in #{self.class.name}"
      end

      u = base.name.underscore
      j = <<-EOL
        def send_notification_with_#{u}
          send_notification_without_#{u}
          if notify? && Setting.notified_events.include?('#{u}_updated')
            Mailer.deliver_#{u}_edit(self)
          end
        end
        alias_method_chain :send_notification, :#{u}
      EOL
      Journal.class_eval(j, __FILE__, __LINE__)

      # -ATTACHMENTS-

      acts_as_attachable :after_add => :attachment_added, :after_remove => :attachment_removed

      def _manage_attachment(obj, options = {})
        if @current_journal && !obj.new_record?
          @current_journal.details << JournalDetail.new(options.merge({:property => 'attachment', :prop_key => obj.id}))
          yield if block_given?
        end
      end
      protected :_manage_attachment

      def attachment_added(obj)
        _manage_attachment(obj, :value => obj.filename)
      end

      def attachment_removed(obj)
        _manage_attachment(obj, :old_value => obj.filename) { @current_journal.save }
      end
    end
  end
end
