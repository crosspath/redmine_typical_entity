module PluginNameHelper
  def render_hidden_crm_attributes_for_edit(entity, acc, form, options={})
    s = '<div class="splitcontentleft">'
    s << (render_hidden_issue_attribute_for_edit_author_id(acc, form, options) || '')
    s << '</div>'
    s.html_safe
  end
  
  def render_visible_crm_attributes_for_edit(entity, acc, form, options={})
    cols = {left: [], right: []}
    yield cols if block_given?
    
    s = '<div class="splitcontentleft">'
    s << (render_visible_crm_attribute_for_edit_assigned_to_id(entity, acc, form, options) || '')
    cols[:left].each { |col| s << col.to_s }
    s << '</div>'
    s << '<div class="splitcontentright">'
    cols[:right].each { |col| s << col.to_s }
    s << '</div>'
    
    s << '<div id="visible-custom-fields" style="clear:both">'
    s << render(:partial => "#{entity.pluralize}/edit_form_updatable_attributes" , :locals => {:show_on_more_form => false})
    s << '</div>'
    s.html_safe
  end
  
  # на основе easyproject\easy_plugins\easy_extensions\lib\easy_patch\redmine\helpers\issues_helper_patch.rb
  #   render_visible_issue_attribute_for_edit_assigned_to_id
  def render_visible_crm_attribute_for_edit_assigned_to_id(entity, issue, form, options={})
    return if issue.disabled_core_fields.include?('assigned_to_id') || !issue.safe_attribute?('assigned_to_id')
    content_tag(:p,
      form.select(:assigned_to_id, crm_assigned_to_collection_for_select_options(issue), :include_blank => true),
      {:class => 'assigned-to-id'}.merge(options))
  end

  def crm_assigned_to_collection_for_select_options(issue)
    options = []
    if issue
      assignable_users = issue.assignable_users.sort_by(&:name)
      options << ["<< #{l(:label_me)} >>".html_safe, User.current.id] if assignable_users.include?(User.current)
      options << [l(:label_author_assigned_to), issue.author_id] if issue.author && issue.assigned_to_id != issue.author_id
      assignable_users.each{|au| options << [au.name, au.id]}
    end
    options
  end
  
  # на основе easyproject\easy_plugins\easy_extensions\lib\easy_patch\redmine\helpers\issues_helper_patch.rb
  #   render_descendants_tree_with_easy_extensions
  def render_crm_issues(entity, acc)
    s = '<form action=""><table class="list issues">'
    issue_list(acc.issues.sort_by(&:lft)) do |child, level|
      css = "issue issue-#{child.id} hascontextmenu"
      css << " idnt idnt-#{level}" if level > 0
      s << content_tag('tr',
          content_tag('td', link_to_issue(child, :truncate => 60, :project => true), :class => 'subject') +
          content_tag('td', h(child.status), :class => 'status') +
          content_tag('td', link_to_user(child.assigned_to), :class => 'assigned_to') +
          content_tag('td', progress_bar(child.done_ratio, :width => '80px'), :class => 'done_ratio') +
          content_tag('td', easy_issue_query_additional_ending_buttons(child)),
        :id => "issue-descendants-tree-child-#{child.id}",
        :class => "#{child.css_classes} issue-#{child.id} hascontextmenu #{level > 0 ? "idnt idnt-#{level}" : nil}",
        :onclick => "javascript:GoToURL('#{url_for({:controller => 'issues', :action => 'show', :id => child})}', event)")
    end
    s << '</table></form>'
    s.html_safe
  end
  
  def crm_query_additional_ending_buttons(entity, issue, options = {})
    s = ''
    s << crm_last_journal_link(entity, issue, options) unless in_mobile_view?
    s << link_to('',{:controller => entity.pluralize, :action => 'edit', :id => issue}, :class => 'icon icon-edit xl-icon', :title => l(:button_update))

    return s.html_safe
  end
  
  def crm_last_journal_link(entity, issue, options)
    e = entity.pluralize
    link_to('', {:controller => e, :action => 'render_last_journal', :id => issue, :block_name => options[:block_name], :uniq_id => options[:uniq_id] }, :id => "#{options[:block_name]}#{options[:uniq_id]}link-to-#{e}-render-last-journal-#{issue.id}", :remote => true, :title => l(:title_last_journal_link), :class => 'icon icon-issue-update xl-icon')
  end
  
  def render_crm_attributes(entity, rows, issue)
    # nothing
  end
end
