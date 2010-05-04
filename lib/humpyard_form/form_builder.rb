module HumpyardForm
  ####
  # HumpyardForm::FormHelper is a helper for forms 
  class FormBuilder 
    attr_reader :object, :options, :html_options, :url, :form_type
    
    @@file_methods = [ :file?, :public_filename ]
    
    cattr_accessor :file_methods
    
    def initialize(renderer, object, options={})
      @renderer = renderer
      @object = @renderer.convert_to_model(object)
      @html_options = options.delete(:html) || {}
      @url = options.delete(:url) || @renderer.polymorphic_path(@object)
      @options = options
      
      if object.respond_to?(:persisted?) && object.persisted?
        @form_type = 'Edit'
        @html_options[:'data-action'] = @renderer.dom_class(object, :edit),
        @html_options[:method] = :put
      else
        @form_type = 'New'
        @html_options[:'data-action'] = @renderer.dom_class(object, :new),
        @html_options[:method] = :post 
      end
    end
    
    def namespace
      if @options[:as]
        @options[:as]
      else
        @object.class.name.underscore.gsub('/', '_')
      end
    end
    
    def uuid
      @uuid ||= rand(1000)
    end
    
    def inputs
    end
    
    def input(method, options={}) #:nodoc:
      options[:as] ||= default_input_type(method)
      options[:translation_info] = translation_info(method)
      @renderer.render :partial => "/humpyard_form/form_element", :locals => {:form => self, :name => method, :options => options, :as => options[:as]}
    end
    
    def submit(options={})
      @renderer.render :partial => '/humpyard_form/submit', :locals => {:form => self, :options => options}
    end

    def translation_info(method) #:nodoc:
      if @object.respond_to?(:translated_attribute_names) and @object.translated_attribute_names.include?(method)
        tmp = @object.translation_class.new
        if tmp
          column = tmp.column_for_attribute(method) if tmp.respond_to?(:column_for_attribute)
          if column
            {:locales => HumpyardForm::config.locales, :column => column}
          end
        end
      else
        false
      end
    end
    
    # For methods that have a database column, take a best guess as to what the input method
    # should be.  In most cases, it will just return the column type (eg :string), but for special
    # cases it will simplify (like the case of :integer, :float & :decimal to :numeric), or do
    # something different (like :password and :select).
    #
    # If there is no column for the method (eg "virtual columns" with an attr_accessor), the
    # default is a :string, a similar behaviour to Rails' scaffolding.
    #
    def default_input_type(method) #:nodoc:
      column = @object.column_for_attribute(method) if @object.respond_to?(:column_for_attribute)
      
      # translated attributes dont have a column info at this point
      # check the associated translation class
      if not column
        tx_info = translation_info(method)
        if tx_info
          column = tx_info[:column]
        end
      end

      if column
        # handle the special cases where the column type doesn't map to an input method
        return :time_zone if column.type == :string && method.to_s =~ /time_zone/
        return :select    if column.type == :integer && method.to_s =~ /_id$/
        return :datetime  if column.type == :timestamp
        return :numeric   if [:integer, :float, :decimal].include?(column.type)
        return :password  if column.type == :string && method.to_s =~ /password/
        #return :country   if column.type == :string && method.to_s =~ /country/

        # otherwise assume the input name will be the same as the column type (eg string_input)
        return column.type
      else
        if @object
          #return :select if find_reflection(method)
         
          file = @object.send(method) if @object.respond_to?(method)
          if file && @@file_methods.any? { |m| file.respond_to?(m) }
            if file.styles.keys.empty?
              return :file
            else
              return :image_file
            end
          end
        end

        return :password if method.to_s =~ /password/
        return :string
      end
    end
    
    
  end
end