module AccsHelper
  include PluginNameHelper
  def render_hidden_acc_attributes_for_edit(acc, form, options={})
    render_hidden_crm_attributes_for_edit('acc', acc, form, options)
  end
  def render_visible_acc_attributes_for_edit(acc, form, options={})
    render_visible_crm_attributes_for_edit('acc', acc, form, options)
  end
  def render_acc_issues(acc)
    render_crm_issues('acc', acc)
  end
  def acc_query_additional_ending_buttons(issue, options = {})
    crm_query_additional_ending_buttons('acc', issue, options)
  end
  def render_acc_attributes(rows, issue)
    render_crm_attributes('acc', rows, issue)
  end
end
