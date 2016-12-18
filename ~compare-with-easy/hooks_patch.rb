module HooksPatch
  def view_journal_show_description_bottom_crm(entity_class, context={})
    return nil unless EasySetting.value('show_journal_id')
    journal = context[:journal]
    issue = context[:issue]
    issue ||= journal.issue

    path = {controller: entity_class.pluralize, action: 'show', id: issue.id, project_id: context[:project].id, anchor: "change-#{journal.id}"}
    title = "#{truncate(h(issue.name), :length => 100)} (#{issue.name})"
    
    link_journal_id = link_to(journal.id, path, class: 'journal', title: title)
    content_tag(:span , link_journal_id.html_safe, :class => 'journal-id')
  end
  
  def view_journal_show_description_bottom_acc(context={})
    view_journal_show_description_bottom_crm('acc', context)
  end
  
  def view_journal_show_description_bottom_lead(context={})
    view_journal_show_description_bottom_crm('lead', context)
  end
end

EasyExtensions::PatchManager.register_other_patch 'EasyExtensions::Hooks', 'HooksPatch'
