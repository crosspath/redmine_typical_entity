module ContactPatch
  def self.included(base)
    base.class_eval do

      has_many :accs_contacts
      has_many :leads_contacts
      has_many :accs, order: "#{Acc.table_name}.name", through: :accs_contacts
      has_many :leads, order: "#{Lead.table_name}.name", through: :leads_contacts

    end
  end
end

EasyExtensions::PatchManager.register_model_patch 'Contact', 'ContactPatch'
