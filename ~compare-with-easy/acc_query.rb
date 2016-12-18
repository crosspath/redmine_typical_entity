# coding: UTF-8

class AccQuery < EasyQuery
  self.reflections = {}
  belongs_to :users, foreign_key: :author_id
  belongs_to :users, foreign_key: :assigned_to_id
  belongs_to :project # попытка обмануть EasyQuery
  
  typical_query 'acc'
  
  def default_find_include
    [:author, :assigned_to]
  end

  def default_list_columns
    @default_list_columns ||= %w[id name assigned_to]
  end
end
