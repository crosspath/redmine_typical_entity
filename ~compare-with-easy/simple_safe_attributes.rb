module SimpleSafeAttributes
  extend ActiveSupport::Concern
  def self.included(base)
    base.class_eval do
      include Redmine::SafeAttributes
      safe_attributes(*SimpleSafeAttributes.reject_fk(self), if: ->(issue, user) {issue.new_record? || user.allowed_to?(:manage_crm, nil, global: true)})
      instance_variable_set :@safe_attribute_names, nil
    end
  end
  module_function
  def reject_fk(klass)
    return ['custom_field_values'] unless klass.table_exists?
    klass.columns.map(&:name).push('custom_field_values', 'notes') - [klass.primary_key]
    #reflections = klass.reflections
    #refl = reflections.select { |_,x| x.macro == :belongs_to }.map { |_,x| x.foreign_key }
  end
end