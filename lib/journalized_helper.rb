module JournalizedHelper
  def format_detail_as_date(detail)
    format_date(detail.value.to_date)
  end

  def format_detail_by_reflection(field, value, object)
    return nil if value.blank?
    name = nil
    association = object.class.reflect_on_association(field.to_sym)
    if association
      record = association.class_name.constantize.where(:id => value).first
      if record
        record.name.force_encoding('UTF-8') if record.name.respond_to?(:force_encoding)
        name = record.name
      end
    end
    name ? link_to(name, record) : "{id: #{value}}"
  end

  def format_detail_as_float(detail)
    "%0.02f" % detail.value.to_f
  end

  def format_detail_as_boolean(detail)
    l(detail.value == "0" ? :general_text_No : :general_text_Yes)
  end

  def format_detail_as_custom_field(detail)
    format_value(detail.value, detail.custom_field)
  end

  def format_detail_attribute(detail, field)
    raise NotImplementedError, 'show_detail_attributes'
  end

  # Returns the textual representation of a single journal detail
  def show_detail(detail, no_html=false, options={})
    multiple = false
    case detail.property
      when 'attr'
        field = detail.prop_key.to_s.gsub(/\_id$/, "")
        label = l(("field_" + field).to_sym)
        value, old_value = (format_detail_attribute(detail, field) || [nil, nil])
      when 'cf'
        custom_field = detail.custom_field
        if custom_field
          multiple = custom_field.multiple?
          label = custom_field.name
          value = format_detail_as_custom_field(detail) if detail.value
          old_value = format_detail_as_custom_field(detail) if detail.old_value
        end
      when 'attachment'
        label = l(:label_attachment)
      else
        value = detail.value
        old_value = detail.old_value
        func = "format_detail_#{detail.property}"
        if respond_to?(func)
          value = send(func, value) if value
          old_value = send(func, old_value) if old_value
        end
    end

    label ||= detail.prop_key
    value ||= detail.value
    old_value ||= detail.old_value

    unless no_html
      label = content_tag('strong', label)
      old_value = content_tag("i", h(old_value)) if detail.old_value
      if detail.old_value && detail.value.blank?
        old_value = content_tag("del", old_value)
      end
      if detail.property == 'attachment' && !value.blank? && atta = Attachment.find_by_id(detail.prop_key)
        # Link to the attachment if it has not been removed
        value = link_to_attachment(atta, :download => true, :only_path => options[:only_path])
        if options[:only_path] != false && atta.is_text?
          value += link_to(
              image_tag('magnifier.png'), :controller => 'attachments', :action => 'show',
              :id => atta, :filename => atta.filename
          )
        end
      else
        value = content_tag("i", h(value)) if value
      end
    end

    if detail.property == 'attr' && detail.prop_key == 'description'
      s = l(:text_journal_changed_no_detail, :label => label)
      unless no_html
        diff_link = link_to 'diff',
                            {:controller => 'journals', :action => 'diff', :id => detail.journal_id,
                             :detail_id => detail.id, :only_path => options[:only_path]},
                            :title => l(:label_view_diff)
        s << " (#{ diff_link })"
      end
      s.html_safe
    elsif detail.value.present?
      case detail.property
        when 'attr', 'cf'
          if detail.old_value.present?
            l(:text_journal_changed, :label => label, :old => old_value, :new => value).html_safe
          elsif multiple
            l(:text_journal_added, :label => label, :value => value).html_safe
          else
            l(:text_journal_set_to, :label => label, :value => value).html_safe
          end
        when 'attachment'
          l(:text_journal_added, :label => label, :value => value).html_safe
        else
          action = detail.old_value.present? ? 'changed' : 'added'
          l("text_journal_#{detail.property}_#{action}", :label => label, :value => value).html_safe
      end
    else
      if detail.property.in?('attr', 'cf', 'attachment', 'relation')
        l(:text_journal_deleted, :label => label, :old => old_value).html_safe
      else
        l("text_journal_#{detail.property}_deleted", :label => label, :value => old_value).html_safe
      end
    end
  end
end
