require 'rubygems'
require 'json'
require 'cgi'
require 'haml_to_star/code_element'

module HamlToStar

  class Compiler
    attr_accessor :variable_name
    attr_accessor :variable_line_name
    attr_accessor :self_closing
    attr_accessor :doc_types
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


    def convert_from_string(str)
      nb_char_spacing = get_indentation_spacing_from_string(str)
      
      @line_number = 0
      code_tree = CodeElement.new
      code_tree.children = get_code_children_from_string(str, nb_char_spacing, 0)
      return convert_from_tree(code_tree) 
    end
    
    def get_code_children_from_string(str, nb_char_spacing, nb_indentation_objective)
      temp_str = ''
      children = []
      str.each_line do |line|
        nb_indentations = get_nb_indentation_from_line(line, nb_char_spacing)
        if (nb_indentations == nb_indentation_objective)
          code_element = CodeElement.new
          code_element.line = line[nb_indentation_objective * nb_char_spacing..line.size]
          if code_element.line[code_element.line.size - 1] == "\n"
            code_element.line = code_element.line[0..code_element.line.size - 2]
          end
          if (temp_str != '')
            children.last.children = get_code_children_from_string(temp_str, nb_char_spacing, nb_indentation_objective + 1)
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
        children.last.children = get_code_children_from_string(temp_str, nb_char_spacing, nb_indentation_objective + 1)
        temp_str = ''
      end
      return children
    end
    
    def get_nb_indentation_from_line(line, nb_char_spacing)
      nb_char = 0
      line.each_char do |char|
        if is_spacing_character(char)
          nb_char += 1
        else
          break;
        end
      end
      if (nb_char % nb_char_spacing != 0)
        raise "Bad indentation"
      end
      return nb_char / nb_char_spacing
    end
    
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
    
    def is_spacing_character(char)
      return char == ' ' || char == "\t";
    end
    
    def convert_from_tree(code_tree, indentation = -1)
      str = []
    
      inside = []
      code_tree.children.each do |child|
        inside << convert_from_tree(child, indentation + 1)
      end
      if (indentation > -1)
        line = code_tree.line
        if (line[0] != '-')
          process_code_number(str, code_tree.line_number)
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
            params[:additionnals] = process_additionnals(rest_of_line[start_brackets..char_num])
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
    
    def construct_dom(params)
      dom = {}
      dom[:self_closing] = @self_closing.index(params[:tag])
      dom[:begin] = '\'<' + params[:tag] + ' '
      if (params[:additionnals])
        extend = {}
        if (params[:id])
          extend[:id] = params[:id]
        end
        if (params[:class])
          extend[:class] = params[:class]
        end
        dom[:begin] += '\' + attrs(' + params[:additionnals] + ', ' + extend.to_json + ') + \''
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
    
    def process_additionnals(additionnals)
      raise 'To be defined'
    end

    def process_code_line(line)
      raise 'To be defined'
    end
    
    def initialize_content(str, content)
      raise 'To be defined'
    end
    
    def add_content(str, content)
      raise 'To be defined'
    end
    
    def add_code(str, line, inside)
      raise 'To be defined'
    end
    
    def evaluate(line)
      raise 'To be defined'
    end
    
    def process_code_number(str, code_number)
      raise 'To be defined'
    end
    
    def process_inline_code(str, content)
      raise 'To be defined'
    end   
  end

end
