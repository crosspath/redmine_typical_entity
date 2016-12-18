class AccsContact < ActiveRecord::Base
  unloadable
  
  belongs_to :acc
  belongs_to :contact
end
