require 'streamlined/view'
module Streamlined; end
module Streamlined::Reflection
  def reflect_on_scalars
    scalars = model.columns.inject({}) do |h,v|
      h[v.name.to_sym] = Streamlined::Column::ActiveRecord.new(v)
      h
    end
  end

  def reflect_on_additions
    additions = {}
    if Object.const_defined?(model.name + "Additions")
      Class.class_eval(model.name + "Additions").instance_methods(false).each do |meth|
        additions[meth.to_sym] = Streamlined::Column::Addition.new(meth)
      end
    end
    additions
  end

  def reflect_on_relationships
    relationships = {}
      model.reflect_on_all_associations.each do |assoc|
        rel = assoc.name.to_sym
        relationships[rel] = create_relationship(rel) unless relationships[rel]
      end
    relationships
  end
  
  private
  # Enforce parity of options on any relationship declaration.
  # * use of the :list summary requires a :fields declaration
  # TODO: move into association
  def ensure_options_parity(options, association)
    # RAILS_DEFAULT_LOGGER.debug("ensure_options_parity: #{options.inspect}, #{association.inspect}")
    return if options == nil || options = {}
    raise ArgumentError, "STREAMLINED ERROR: Error in #{self.name} : Cannot specify *:summary => :list* without also specifying the :fields option (#{options.inspect})" if options[:summary] && options[:summary][:name] == :list && !options[:summary][:fields]
    raise ArgumentError, "STREAMLINED ERROR: Error in #{self.name} : Cannot use *:summary => :name* for a #{association.macro} relationship" if options[:summmary] && options[:summary][:name] == :name && [:has_many, :has_and_belongs_to_many].include?(association.macro)  
    raise ArgumentError, "STREAMLINED ERROR: Error in #{self.name} : Cannot use *:view => :filter_select* for a #{association.macro} relationship" if options[:view] && options[:view][:name] == :filter_select && [:has_one, :belongs_to].include?(association.macro)  
  end
     
  def create_relationship(rel)
    association = model.reflect_on_association(rel)
    raise Exception, "STREAMLINED ERROR: No association '#{rel}' on class #{model}." unless association
    options = define_association(association)
    Streamlined::Column::Association.new(association, *options)
  end

  # TODO: move defaults down into association class
  # Used to define the default relationship declarations for each relationship in the model.
  def define_association(assoc, options = {:view => {}, :summary => {}})
    return {:summary => :none} if options[:summary] == :none
    case assoc.macro
    when :has_one, :belongs_to
      if assoc.options[:polymorphic]
        [:polymorphic_select, :name]
      else
        [:select, :name]
      end
    when :has_many, :has_and_belongs_to_many
      if assoc.options[:polymorphic]
        [:polymorphic_membership, :count]
      else
        [:membership, :count]
      end           
    end
  end  
    

end
