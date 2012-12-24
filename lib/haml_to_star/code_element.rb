module HamlToStar

  class CodeElement
    attr_accessor :line
    attr_accessor :children
    attr_accessor :line_number
    
    def initialize
      @line = ''
      @line_number = 0
      @children = []
    end
  end

end
