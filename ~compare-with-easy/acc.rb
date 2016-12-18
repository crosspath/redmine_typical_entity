# coding: UTF-8

class Acc < ActiveRecord::Base
  unloadable
  
  has_many :accs_contacts
  has_many :contacts, order: "#{Contact.table_name}.last_name, #{Contact.table_name}.first_name", through: :accs_contacts
  
  typical_model
  validates :name, presence: true
  
  def [](other)
    return {} if other == 'easy_repeat_settings'
    return false if other == 'easy_is_repeating'
    super
  end
  def required_attribute?(name, user=nil); name.to_s == 'name'; end
  
  def attached_contacts
    contacts.visible.map { |x| [x, accs_contacts.find_by_contact_id(x.id)] }
  end
end
