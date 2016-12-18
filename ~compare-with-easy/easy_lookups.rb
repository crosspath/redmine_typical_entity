require Rails.root.join('plugins/easyproject/easy_plugins/easy_extensions/lib/easy_extensions/easy_lookups/easy_lookup.rb').to_s

class EasyLookupAcc < EasyExtensions::EasyLookups::EasyLookup
  def attributes
    [[l(:field_name), 'name'], [l(:label_link_with, :attribute => l(:field_name)), 'link_with_name']]
  end
end

class EasyLookupLead < EasyExtensions::EasyLookups::EasyLookup
  def attributes
    [[l(:field_name), 'name'], [l(:label_link_with, :attribute => l(:field_name)), 'link_with_name']]
  end
end

EasyExtensions::EasyLookups::EasyLookup.register(EasyLookupAcc.new)
EasyExtensions::EasyLookups::EasyLookup.register(EasyLookupLead.new)
CustomField::CUSTOM_FIELDS_TABS << {name: 'AccCustomField', partial: 'custom_fields/index', label: :label_acc_index}
CustomField::CUSTOM_FIELDS_TABS << {name: 'LeadCustomField', partial: 'custom_fields/index', label: :label_lead_index}
