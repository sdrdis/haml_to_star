module HamlToStar

  # This class is used only internally. It allows the compiler to construct the tree
  # associated to the haml code. A code element is equivalent to a line in haml.
  class CodeNode
    
    # Current line in haml
    #
    # @return [String]
    attr_accessor :line
    
    # Children of current line in haml
    #
    # @return [Array<CodeNode>]
    attr_accessor :children
    
    # The line number of the code element
    #
    # @return [Integer]
    attr_accessor :line_number
    
    def initialize
      @line = ''
      @line_number = 0
      @children = []
    end
  end

end
