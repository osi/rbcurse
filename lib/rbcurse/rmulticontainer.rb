=begin
  * Name: MultiContainer 
  * Description   View (cycle) multiple components in one container using a key or menu
  * Author: rkumar (arunachalesha)
  * file created 2010-03-15 10:40 
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
#require 'rubygems'
#require 'ncurses'
#require 'logger'
require 'rbcurse'

include Ncurses
include RubyCurses
module RubyCurses
  extend self

  ##
  # Extends TextView with ability to load more than one file or content
  # and switch between files (buffers).
  # NOTE: ideally, i should be able to dynamically add this functionality to either Textview
  # or TextArea or even ListBox or Table someday. Should then be a Module rather than a class.
  class MultiContainer < Widget
    dsl_accessor :title
    #include ListScrollable

    def initialize form = nil, config={}, &block
      @focusable = true
      @row_offset = @col_offset = 1
      super
      @bmanager = BufferManager.new self
      init_vars

    end
    def init_vars
      super
      bind_key(?\M-:, :buffer_menu)
      # bind_key([?\C-x, ?f], :file_edit)
      bind_key([?\C-x, ?k], :delete_component)
      bind_key([?\C-x, ?\C-b], :list_components)
      # easily cycle using p. n is used for next search.
      #bind_key(?p, :buffer_previous)
      @suppress_borders = false 
      @repaint_all = true 
      @name ||= "multicontainer"
    end
    ## returns current buffer
    # @return  [RBuffer] current buffer
    def current_component
      @bmanager.current
    end
    ## 
    # multi-container
    def handle_key ch  #:nodoc:
      $log.debug " MULTI handlekey #{ch}, #{@current_component}  "
      ret = :UNHANDLED
      return :UNHANDLED unless @current_component
      ret = @current_component.handle_key(ch)
      $log.debug " MULTI = comp returned #{ret} "
      if ret == :UNHANDLED
        # check for bindings, these cannot override above keys since placed at end
        begin
          ret = process_key ch, self
          $log.debug " MULTI = process_key returned #{ret} "
        rescue => err
#          $error_message = err # changed 2010 dts  
          $error_message.value = err
          #@form.window.print_error_message PLEASE CREATE LABEL
          $log.error " Multicomponent process_key #{err} "
          $log.debug(err.backtrace.join("\n"))
        end
        return :UNHANDLED if ret == :UNHANDLED
      end
      # check for any keys not handled and check our own ones
      return ret # 
    end
    def repaint
      print_border if (@suppress_borders == false && @repaint_all) # do this once only, unless everything changes
      return unless @current_component
      $log.debug " MULTI REPAINT "
      ret = @current_component.repaint
    end
    def print_border  #:nodoc:
      $log.debug " #{@name} print_borders,  #{@graphic.name} "
      color = $datacolor
      @graphic.print_border_only @row, @col, @height-1, @width, color #, Ncurses::A_REVERSE
      print_title
    end
    def print_title  #:nodoc:
      $log.debug " print_title #{@row}, #{@col}, #{@width}  "
      @graphic.printstring( @row, @col+(@width-@title.length)/2, @title, $datacolor, @title_attrib) unless @title.nil?
    end
    # this is just a test of the simple "most" menu
    # can use this for next, prev, first, last, new, delete, overwrite etc
    def buffer_menu
      menu = PromptMenu.new self 
      menu.add(menu.create_mitem( 'l', "list buffers", "list buffers ", :list_components ))
      item = menu.create_mitem( 'b', "Buffer Options", "Buffer Options" )
      menu1 = PromptMenu.new( self, "Buffer Options")
      menu1.add(menu1.create_mitem( 'n', "Next", "Switched to next buffer", :goto_next_component ))
      menu1.add(menu1.create_mitem( 'p', "Prev", "Switched to previous buffer", :goto_prev_component ))
      menu1.add(menu1.create_mitem( 'f', "First", "Switched to first buffer", :goto_first_component ))
      menu1.add(menu1.create_mitem( 'l', "Last", "Switched to last buffer", :goto_last_component ))
      menu1.add(menu1.create_mitem( 'd', "Delete", "Deleted buffer", :delete_component ))
      item.action = menu1
      menu.add(item)
      # how do i know what's available. the application or window should know where to place
      menu.display @form.window, $error_message_row, $error_message_col, $datacolor #, menu
    end

    #%w[next previous first last].each do |pos|
      #eval(
           #"def _buffer_#{pos}
              #@current_component = @bmanager.#{pos}
              #set_current_buffer
           #end"
          #)
    #end

    def goto_next_component
      perror "No other buffer" and return if @bmanager.size < 2

      @current_component = @bmanager.next
      set_current_component
    end

    def goto_prev_component
      perror "No other buffer" and return if @bmanager.size < 2

      @current_component = @bmanager.previous
      $log.debug " buffer_prev got #{@current_component} "
      set_current_component
    end
    def goto_first_component
      @current_component = @bmanager.first
      $log.debug " buffer_first got #{@current_component} "
      set_current_component
    end
    def goto_last_component
      @current_component = @bmanager.last
      $log.debug " buffer_last got #{@current_component} "
      set_current_component
    end
    def delete_component
      if @bmanager.size > 1
        @bmanager.delete_at
        @current_component = @bmanager.previous
        set_current_component
      else
        perror "Only one buffer. Cannot delete."
      end
    end

    def component_at index
      @current_component = @bmanager.element_at index
      $log.debug " buffer_last got #{@current_component} "
      set_current_component
    end
    ##
    # Add a component with a title
    # @param [Widget] component
    # @param [String] title
    def add component, title
      component.row = @row+@row_offset+1
      component.col = @col+@col_offset+1
      component.width = @width-2
      component.height = @height-2
      component.form = @form
      component.override_graphic(@graphic)
      @current_component = @bmanager.add component, title
      set_current_component
      $log.debug " ADD got cb : #{@current_component} "
    end
    def set_current_component
      @current_component = @current_component.component
      @current_title = @current_component.title
      @current_component.repaint_all true
    end
    def perror errmess=$error_message
      @form.window.print_error_message errmess
    end
    def list_components
      $log.debug " TODO buffers_list: #{@bmanager.size}  "
      menu = PromptMenu.new self 
      @bmanager.each_with_index{ |b, ix|
        aproc = Proc.new { component_at(ix) }
        name = b.title
        num = ix + 1
        menu.add(menu.create_mitem( num.to_s, name, "Switched to buffer #{ix}", aproc ))
      }
      menu.display @form.window, $error_message_row, $error_message_col, $datacolor
    end
    # required otherwise some components may not get correct cursor position on entry
    # e.g. table
    def on_enter
      set_form_row
    end
    def set_form_row  #:nodoc:
      if !@current_component.nil?
        #$log.debug " #{@name} set_form_row calling sfr for #{@current_component.name} "
        @current_component.set_form_row 
        @current_component.set_form_col 
      end
    end
  end # class multicontainer
  ##
  # Handles multiple buffers, navigation, maintenance etc
  # Instantiated at startup of 
  #
  class BufferManager
    include Enumerable
    def initialize source
      @source = source
      @buffers = [] # contains RBuffer
      @counter = 0
      # for each buffer i need to store data, current_index (row), curpos (col offset) and title (filename).
    end
    def element_at index
      @buffers[index]
    end
    def each
      @buffers.each {|k| yield(k)}
    end

    ##
    # @return [RBuffer] current buffer/file
    ##
    def current
      @buffers[@counter]
    end
    ##
    # Would have liked to just return next buffer and not get lost in details of caller
    #
    # @return [RBuffer] next buffer/file
    ##
    def next
      @counter += 1
      @counter = 0 if @counter >= @buffers.size
      @buffers[@counter]
    end
    ##
    # @return [RBuffer] previous buffer/file
    ##
    def previous
      $log.debug " previous bs: #{@buffers.size}, #{@counter}  "
      @counter -= 1
      return last() if @counter < 0
      $log.debug " previous ctr  #{@counter} "
      @buffers[@counter]
    end
    def first
      @counter = 0
      @buffers[@counter]
    end
    def last
      @counter = @buffers.size - 1
      @buffers[@counter]
    end
    ##
    def delete_at index=@counter
      @buffers.delete_at index
    end
    def delete_by_name name
      @buffers.delete_if {|b| b.filename == name }
    end
    def insert component, position, title=nil
      anew = RComponents.new(component, title)
      @buffers.insert position, anew
      @counter = position
      return anew
    end
    def add component, title=nil
      $log.debug " ADD H: #{component.height} C: #{component.width} "
      insert component, @buffers.size, title
    end
    def size
      @buffers.size
    end
    alias :count :size
  end
  RComponents = Struct.new(:component, :title)

end # modul
