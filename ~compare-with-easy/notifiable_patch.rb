require Rails.root.join('lib', 'redmine', 'notifiable.rb').to_s

module NotifiablePatch
  def self.included(base)
    base.extend(ClassMethods)
    base.class_eval do
      class << self
        alias_method_chain :all, :ca
      end
    end
  end


  module ClassMethods
    def all_with_ca
      notifications = all_without_ca
      notifications << Redmine::Notifiable.new('lead_add')
      notifications << Redmine::Notifiable.new('lead_edit')
      notifications << Redmine::Notifiable.new('update_domain_fail')
      notifications          
    end
  end
end

EasyExtensions::PatchManager.register_model_patch 'Redmine::Notifiable', 'NotifiablePatch'
