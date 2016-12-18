module EntityAttributeHelperPatch
  def format_html_crm_attribute(entity_class, attribute, unformatted_value, options = {})
    value = format_entity_attribute(entity_class, attribute, unformatted_value, options)
    if attribute.name == :name
      if options.has_key?(:wrap)
        value = value.scan(/(.{1,#{options[:wrap]}})/).flatten.join('<br/>').html_safe
      end
      link_to(h(value), controller: entity_class.name.tableize, action: 'show', id: options[:entity], project_id: PluginName.find_project.id) # PluginName
    else
      h(value)
    end
  end
  def format_html_acc_attribute(entity_class, attribute, unformatted_value, options = {})
    format_html_crm_attribute(entity_class, attribute, unformatted_value, options)
  end
  def format_html_lead_attribute(entity_class, attribute, unformatted_value, options = {})
    format_html_crm_attribute(entity_class, attribute, unformatted_value, options)
  end
end

EasyExtensions::PatchManager.register_helper_patch 'EntityAttributeHelper', 'EntityAttributeHelperPatch'
