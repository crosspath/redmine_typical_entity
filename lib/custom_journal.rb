class CustomJournal < Journal
  scope :visible, lambda {|*args|
    user = args.shift || User.current
    klass = args.shift
    klass = klass.constantize if klass.is_a? String

    s = includes(:issue => :project).
        where("(#{Journal.table_name}.private_notes = ? OR (#{Project.allowed_to_condition(user, :view_private_notes, *args)}))", false)
    s = s.where(klass.visible_condition(user, *args)) if klass && klass.respond_to?(:visible_condition)
    s
  }

  # Returns journal details that are visible to user
  def visible_details(user=User.current)
    details.select do |detail|
      if detail.property == 'cf'
        detail.custom_field && detail.custom_field.visible_by?(project, user)
      elsif detail.property == 'relation'
        klass = journalized_type.constantize
        klass.find_by_id(detail.value || detail.old_value).try(:visible?, user)
      else
        true
      end
    end
  end

  # Returns the new status if the journal contains a status change, otherwise nil
  def new_status
    klass = "#{journalized_type}Status"
    if defined?(klass)
      klass = klass.constantize
    else
      return nil
    end
    c = details.detect {|detail| detail.prop_key == 'status_id'}
    (c && c.value) ? klass.find_by_id(c.value.to_i) : nil
  end

  def editable_by?(usr)
    usr && usr.logged? && (journalized.respond_to?(:editable_by?) ? journalized.editable_by?(usr) : true)
  end

  def notified_users
    return unless journalized.respond_to?(:notified_users)
    super
  end

  def notified_watchers
    return unless journalized.respond_to?(:notified_watchers)
    super
  end

  def send_notification
    journalized.send_notification(:edit, self) if notify? && journalized.respond_to?(:send_notification)
  end
end
