require 'rubygems'
require 'json'
require 'cgi'
require 'haml_to_star/code_element'

module HamlToStar

  # The compiler class transform an haml code to executable code.
  class Compiler
    # Variable name in which we save resulting html.
    #
    # @return [String]
    attr_accessor :variable_name
    
    # Variable name in which we save current haml line code (debugging)
    #
    # @return [String]
    attr_accessor :variable_line_name
    
    # Self closing html tags (like meta or img)
    #
    # @return [Array<String>]
    attr_accessor :self_closing
    
    # Shortcuts for doc types (ex: 'xml' => '<?xml version="1.0" encoding="utf-8" ?>')
    #
    # @return [{String => String}]
    attr_accessor :doc_types
    
    # Current line number
    #
    # @return [Integer]
    attr_accessor :line_number
    
    def initialize
      @variable_name = '_$output'
      @variable_line_name = '_$line'
      @self_closing = [
      'meta',
      'img',
      'link',
      'br',
      'hr',
      'input',
      'area',
      'base']
      
      @doc_types = {
        '5' => '<!DOCTYPE html>',
        'xml' => '<?xml version="1.0" encoding="utf-8" ?>',
        'default' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">',
        'strict' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
        'frameset' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">',
        '1.1' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">',
        'basic' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">',
        'mobile' => '<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" "http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd">'
      }
    end

    # Converts haml code to executable code.
    # Internally, the function first convert it to a {CodeNode} and the calls convert_from_node
    #
    # @param str [String] The haml code 
    #
    # @return [String]
    def convert_from_string(str)
      nb_char_per_indentation = get_indentation_spacing_from_string(str)
      
      @line_number = 0
      code_node = CodeNode.new
      code_node.children = get_code_children_from_string(str, nb_char_per_indentation, 0)
      return convert_from_node(code_node) 
    end
    
    # Converts haml code into an array of {CodeNode}.
    # 
    # @param str [String] The haml code
    # @param nb_char_per_indentation [Integer] Number of spaces defining one unit indentation
    # @param nb_indentation_depth [Integer] Depth of indentation we want to analyse (used by the recursivity)
    #
    # @return [Array<CodeNode>]
    def get_code_children_from_string(str, nb_char_per_indentation, nb_indentation_depth)
      temp_str = ''
      children = []
      str.each_line do |line|
        nb_indentations = get_nb_indentation_from_line(line, nb_char_per_indentation)
        if (nb_indentations == nb_indentation_depth)
          code_element = CodeNode.new
          code_element.line = line[nb_indentation_depth * nb_char_per_indentation..line.size]
          if code_element.line[code_element.line.size - 1] == "\n"
            code_element.line = code_element.line[0..code_element.line.size - 2]
          end
          if (temp_str != '')
            children.last.children = get_code_children_from_string(temp_str, nb_char_per_indentation, nb_indentation_depth + 1)
            temp_str = ''
          end
          @line_number += 1
          code_element.line_number = @line_number
          children << code_element
        else
          temp_str += line
        end
      end
      if (temp_str != '')
        children.last.children = get_code_children_from_string(temp_str, nb_char_per_indentation, nb_indentation_depth + 1)
        temp_str = ''
      end
      return children
    end
    
    # From a line in the haml code, determines the number of indentation unit
    #
    # @param line [String] The haml code line
    # @param nb_char_per_indentation [Integer] Number of spaces defining one unit indentation
    #
    # @return [Integer]
    def get_nb_indentation_from_line(line, nb_char_per_indentation)
      nb_char = 0
      line.each_char do |char|
        if is_spacing_character(char)
          nb_char += 1
        else
          break;
        end
      end
      if (nb_char % nb_char_per_indentation != 0)
        raise "Bad indentation"
      end
      return nb_char / nb_char_per_indentation
    end
    
    # From a haml code, determines number of spaces / tabs composes one indentation unit
    #
    # @param str [String] The haml code 
    #
    # @return [Integer]
    def get_indentation_spacing_from_string(str)
      str.each_line do |line|
        nb_char = 0
        line.each_char do |char|
          if is_spacing_character(char)
            nb_char += 1
          else
            break
          end
        end
        if (nb_char != 0)
          return nb_char
        end
      end
      
      return 1
    end
    
    # Returns true if the character is a space or tab, false otherwise
    #
    # @param char [String] Character to be analysed
    #
    # @return [Boolean]
    def is_spacing_character(char)
      return char == ' ' || char == "\t";
    end
    
    # Converts a {CodeNode} to executable code.
    #
    # @param code_node [CodeNode] The code tree
    #
    # @return [String]
    def convert_from_node(code_node, indentation = -1)
      str = []
    
      inside = []
      code_node.children.each do |child|
        inside << convert_from_node(child, indentation + 1)
      end
      if (indentation > -1)
        line = code_node.line
        if (line[0] != '-')
          process_code_line_number(str, code_node.line_number)
        end
        if (line[0] == '%' || line[0] == '.' || line[0] == '#')
          dom = convert_dom_element(line)
          if (dom[:self_closing])
            add_content(str, dom[:begin])
          else
            add_content(str, dom[:begin])
            if (inside.size > 0)
              str << inside.join("\n")
            else
              if (dom[:inside])
                add_content(str, dom[:inside])
              end
            end
            add_content(str, dom[:end])
          end
        elsif (line[0] == '=' || line[0] == '!')
          process_inline_code(str, line)
        elsif (line[0] == '-')
          add_code(str, line, inside)
        else
          add_content(str, line.to_json)
        end
      else
        initialize_content(str, inside)
      end
      
      return str.join("\n")
    end
    
    # Converts a line in the haml code into a valid dom element.
    #
    # @param line [String] The haml code line
    #
    # @return [String]
    def convert_dom_element(line)
      div_base_informations = line.gsub(%r{[^\{ =]*}).first
      infos = div_base_informations.gsub(%r{[%.#][\w-]*})
      params = {:tag => 'div'}
      infos.each do |info|
        if (info[0] == '%')
          params[:tag] = info[1..info.size - 1]
        elsif (info[0] == '#')
          params[:id] = info[1..info.size - 1]
        elsif (info[0] == '.')
          unless params[:class]
            params[:class] = ''
          end
          params[:class] += ' ' + info[1..info.size - 1]
        end
      end
      
      rest_of_line = line[div_base_informations.size..line.size - 1]
      
      num_brackets = 0
      char_num = 0
      start_brackets = 0
      rest_of_line.each_char do |char|
        if (char == '{')
          if (num_brackets == 0)
            start_brackets = char_num
          end
          num_brackets += 1
        elsif (char == '}')
          num_brackets -= 1
          if (num_brackets == 0)
            params[:dom_params] = process_dom_params(rest_of_line[start_brackets..char_num])
          end
        elsif (num_brackets == 0)
          remaining = rest_of_line[char_num..rest_of_line.size - 1].strip
          if (remaining.size > 0)
            if (char == ' ')
              params[:inside] = remaining
              break
            elsif (char == '=' || char == '!')
              params[:inside_code] = evaluate(remaining)
              break
            end
          end
        end
        char_num += 1
      end
      
      return construct_dom(params)
    end
    
    # Converts object sent by convert_dom_element into a valid dom element.
    #
    # @param params [Object] Params sent by convert_dom_element
    #
    # @return [String]
    def construct_dom(params)
      dom = {}
      dom[:self_closing] = @self_closing.index(params[:tag])
      dom[:begin] = '\'<' + params[:tag] + ' '
      if (params[:dom_params])
        extend = {}
        if (params[:id])
          extend[:id] = params[:id]
        end
        if (params[:class])
          extend[:class] = params[:class]
        end
        dom[:begin] += '\' + attrs(' + params[:dom_params] + ', ' + extend.to_json + ') + \''
      else
        if (params[:id])
          dom[:begin] += 'id="' + params[:id] + '" '
        end
        if (params[:class])
          dom[:begin] += 'class="' + params[:class] + '" '
        end
      end
      dom[:begin] += (dom[:self_closing] ? '/' : '') + '>\''
      if (params[:inside])
        dom[:inside] = CGI::escapeHTML(params[:inside])
      elsif (params[:inside_code])
        dom[:inside] = params[:inside_code]
      end
      
      dom[:end] = '\'</' + params[:tag] + '>\''
      return dom
    end
    
    # Process dom parameters 
    #
    # @param dom_params [String] Dom parameters
    #
    # @return [String]
    def process_dom_params(dom_params)
      raise 'To be defined'
    end
    
    # What should be on the header of generated code
    #
    # @param str [String] Result string
    # @param content [String] Generated code
    def initialize_content(str, content)
      raise 'To be defined'
    end
    
    # How do we add html content to the result
    #
    # @param str [String] Result string
    # @param content [String] Generated code
    def add_content(str, content)
      raise 'To be defined'
    end
    
    # How do we add code content to the result
    #
    # @param str [String] Result string
    # @param line [String] Current line
    # @param inside [String] Children lines
    def add_code(str, line, inside)
      raise 'To be defined'
    end
    
    # How do we what is after = or !=
    #
    # @param line [String] Line to be processed
    #
    # @return [String]
    def evaluate(line)
      raise 'To be defined'
    end
    
    # How do we add the current line number into the resulted string
    #
    # @param str [String] Result string
    # @param code_line_number [String] Current line number
    def process_code_line_number(str, code_line_number)
      raise 'To be defined'
    end
    
    # How do we process lines begining with = or !=
    #
    # @param line [String] Line to be processed
    def process_inline_code(str, content)
      raise 'To be defined'
    end   
  end

end
