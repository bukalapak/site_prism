module SitePrism::ElementContainer

  def element element_name, element_selector = nil
    if element_selector.nil?
      create_no_selector element_name
    else
      add_to_mapped_items element_name
      define_method element_name.to_s do
        find_one element_selector
      end
    end
    add_checkers_and_waiters element_name, element_selector
  end

  def elements collection_name, collection_selector = nil
    if collection_selector.nil?
      create_no_selector collection_name
    else
      add_to_mapped_items collection_name
      define_method collection_name.to_s do
        find_all collection_selector
      end
    end
    add_checkers_and_waiters collection_name, collection_selector
  end
  alias :collection :elements

  def section section_name, section_class, section_selector
    add_to_mapped_items section_name
    add_checkers_and_waiters  section_name, section_selector
    define_method section_name do
      section_class.new find_one section_selector
    end
  end

  def sections section_collection_name, section_class, section_collection_selector
    add_to_mapped_items section_collection_name
    add_checkers_and_waiters section_collection_name, section_collection_selector
    define_method section_collection_name do
      find_all(section_collection_selector).collect do |element|
        section_class.new element
      end
    end
  end

  def iframe iframe_name, iframe_page_class, iframe_id
    add_to_mapped_items iframe_name
    create_existence_checker iframe_name, iframe_id
    create_waiter iframe_name, iframe_id
    define_method iframe_name do |&block|
      within_frame iframe_id.split("#").last do
        block.call iframe_page_class.new
      end
    end
  end

  def add_to_mapped_items item
    @mapped_items ||= []
    @mapped_items << item.to_s
  end

  def mapped_items
    @mapped_items
  end

  private
  
  def add_checkers_and_waiters name, selector
    create_existence_checker name, selector
    create_waiter name, selector
    create_visibility_waiter name, selector
    create_invisibility_waiter name, selector
  end

  def create_existence_checker element_name, element_selector
    method_name = "has_#{element_name.to_s}?"
    if element_selector.nil?
      create_no_selector element_name, method_name
    else
      define_method method_name do
        Capybara.using_wait_time 0 do
          element_exists? element_selector
        end
      end
    end
  end

  def create_waiter element_name, element_selector
    method_name = "wait_for_#{element_name.to_s}"
    if element_selector.nil?
      create_no_selector element_name, method_name
    else
      define_method method_name do |*args| #used to use block args, but they don't work under ruby 1.8 :(
        timeout = args.shift || Capybara.default_wait_time
        Capybara.using_wait_time timeout do
          element_waiter element_selector
        end
      end
    end
  end

  def create_visibility_waiter element_name, element_selector
    method_name = "wait_until_#{element_name.to_s}_visible"
    if element_selector.nil?
      create_no_selector element_name, method_name
    else
      define_method method_name do |*args|
        timeout = args.shift || Capybara.default_wait_time
        Capybara.using_wait_time timeout do
          element_waiter element_selector
        end
        begin
          Timeout.timeout(timeout) do
            sleep 0.1 until find_one(element_selector).visible?
          end
        rescue Timeout::Error
          raise SitePrism::TimeOutWaitingForElementVisibility.new("#{element_name} did not become visible")
        end
      end
    end
  end

  def create_invisibility_waiter element_name, element_selector
    method_name = "wait_until_#{element_name.to_s}_invisible"
    if element_selector.nil?
      create_no_selector element_name, method_name
    else
      define_method method_name do |*args|
        timeout = args.shift || Capybara.default_wait_time
        begin
          Timeout.timeout(timeout) do
            sleep 0.1 while element_exists?(element_selector) && find_one(element_selector).visible?
          end
        rescue Timeout::Error
          raise SitePrism::TimeOutWaitingForElementInvisibility.new("#{element_name} did not become invisible")
        end
      end
    end
  end


  def create_no_selector element_name, method_name = nil
    no_selector_method_name = method_name.nil? ? element_name : method_name
    define_method no_selector_method_name do
      raise SitePrism::NoSelectorForElement.new("#{self.class.name} => :#{element_name} needs a selector")
    end
  end
end

