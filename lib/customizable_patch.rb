MGTS_Patches::Patcher.patch_inline('Redmine::Acts::Customizable') do
  def save_cv(cf, value)
    _save_cv(cf, value, false)
  end

  def save_cv!(cf, value)
    _save_cv(cf, value, true)
  end

  def cfv_for(cf)
    cf = find_custom_field(cf)
    raise ArgumentError, 'cf' unless cf
    custom_field_values.find { |x| x.custom_field == cf }
  end

  def changed_cfv
    custom_field_values.select { |x| x.value != x.value_was }
  end

  def cfv_changed?
    !!custom_field_values.find { |x| x.value != x.value_was }
  end

  def find_custom_field(cf)
    cf = CustomField.where(:type => "#{self.class.name}CustomField", :name => cf).first if cf.is_a?(String)
    cf = CustomField.find(cf) if cf.is_a?(Fixnum)
    cf
  end

  protected

  def _save_cv(cf, value, bang)
    cf = find_custom_field(cf)
    cv = self.custom_value_for(cf)
    v = {:value => value}
    if cv
      bang ? cv.update_attributes!(v) : cv.update_attributes(v)
    else
      cv = CustomValue.new v
      cv.customized = self
      cv.custom_field = cf
      bang ? cv.save! : cv.save
    end
  end
end
